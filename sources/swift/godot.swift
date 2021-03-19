import GDNative

public 
protocol _GodotLibrary 
{
    static 
    var interface:Godot.Interface 
    {
        get
    }
}

public 
protocol _GodotNativeScriptCore 
{
    static 
    func register(with api:Godot.API.NativeScript)
    
    #if BUILD_STAGE_INERT
    static 
    var __signatures__:[String]
    {
        get 
    }
    #endif 
}


protocol _GodotNativeScript:Godot.NativeScriptCore
{
    typealias Interface = Godot.NativeScriptInterface<Self>
    
    associatedtype Delegate:Godot.NativeScriptDelegate
    
    init(delegate:Delegate)
    
    static 
    var interface:Interface
    {
        get
    }
}
extension Godot.NativeScript 
{
    static 
    func register(with _:Godot.API.NativeScript) 
    {
    }
}

protocol _GodotNativeScriptDelegate 
{
    init(_ pointer:UnsafeMutableRawPointer)
    
    static 
    var name:String 
    {
        get
    }
}


public 
enum Godot:_GodotLibrary
{
    public 
    typealias Library               = _GodotLibrary
    public 
    typealias NativeScriptCore      = _GodotNativeScriptCore
    typealias NativeScript          = _GodotNativeScript
    typealias NativeScriptDelegate  = _GodotNativeScriptDelegate
    
    @resultBuilder 
    public struct Interface 
    {
        typealias Binding = (type:NativeScriptCore.Type, symbol:Swift.String)
        
        public 
        let types:[(type:NativeScriptCore.Type, symbols:[Swift.String])]
    }
    
    @resultBuilder
    struct NativeScriptInterface<T> where T:Godot.NativeScript
    {
        #if ENABLE_ARC_SANITIZER
        final 
        class Metatype 
        {
            final 
            class Symbol 
            {
                private 
                let symbol:Swift.String, 
                    metatype:Metatype 
                
                init(_ symbol:Swift.String, metatype:Metatype)
                {
                    self.symbol     = symbol
                    self.metatype   = metatype
                }
                
                func track() 
                {
                    self.metatype.instances[self.symbol]?.wrappingIncrement(ordering: .relaxed)
                }
                func untrack() 
                {
                    self.metatype.instances[self.symbol]?.wrappingDecrement(ordering: .relaxed)
                }
            }
            
            private 
            var instances:[Swift.String: ManagedAtomic<Int>] 
            
            init(symbols:[Swift.String]) 
            {
                self.instances = .init(uniqueKeysWithValues: symbols.map{ ($0, .init(0)) })
            }
            
            deinit 
            {
                func plural(_ count:Int) -> Swift.String 
                {
                    count == 1 ? "\(count) leaked instance" : "\(count) leaked instances"
                }
                
                let leaked:[Swift.String: Int] = self.instances.compactMapValues 
                {
                    let count:Int = $0.load(ordering: .relaxed)
                    return count != 0 ? count : nil
                }
                if !leaked.isEmpty 
                {
                    Godot.print(warning: 
                        """
                        detected \(plural(leaked.values.reduce(0, +))) of \(Swift.String.init(reflecting: T.self)):
                        \(leaked.sorted{ $0.key < $1.key }.map
                        { 
                            "    \(plural($0.value)) of '\($0.key)'" 
                        }.joined(separator: "\n"))
                        """)
                }
            }
        }
        #endif
        
        enum Witness 
        {
            typealias Property  = KeyPath<T, Godot.Variant>
            #if BUILD_STAGE_INERT
            typealias Method    = Any.Type 
            #else 
            typealias Method    = (T, T.Delegate, [Godot.Variant.Unmanaged]) -> Godot.Variant.Unmanaged
            #endif 
        }
        
        typealias Property  = (witness:Witness.Property, symbol:Swift.String)
        typealias Method    = (witness:Witness.Method,   symbol:Swift.String)
        
        private(set)
        var properties:[Property]
        private(set)
        var methods:[Method]
        
        init(properties:[Property], methods:[Method])
        {
            self.properties = properties 
            self.methods    = methods
        }
        
        subscript(property index:Int) -> Property 
        {
            _read 
            {
                yield self.properties[index]
            }
            _modify
            {
                yield &self.properties[index]
            }
        }
        subscript(method index:Int) -> Method 
        {
            _read 
            {
                yield self.methods[index]
            }
            _modify
            {
                yield &self.methods[index]
            }
        }
    }
}

infix operator <- : AssignmentPrecedence

func <- <T>(type:T.Type, symbol:String) -> Godot.Interface.Binding
    where T:Godot.NativeScriptCore
{
    (T.self, symbol)
}

extension Godot.Interface 
{
    static 
    func buildExpression(_ binding:Binding) -> [Binding]
    {
        [binding]
    }
    static 
    func buildBlock(_ bindings:[Binding]...) -> [Binding]
    {
        .init(bindings.joined())
    }
    
    static 
    func buildFinalResult(_ bindings:[Binding]) -> Self 
    {
        let dictionary:[ObjectIdentifier: [Binding]] = 
            .init(grouping: bindings) 
            {
                ObjectIdentifier.init($0.type)
            }
        return .init(types: dictionary.sorted
        {
            $0.key < $1.key
        }.map 
        {
            ($0.value[0].type, $0.value.map(\.symbol))
        })
    }
}

extension Godot.NativeScriptInterface 
{
    enum Member 
    {
        case property(witness:Witness.Property, symbol:String)
        case method(  witness:Witness.Method,   symbol:String)
    }
    
    static 
    func buildExpression(_ member:Member) -> [Member]
    {
        [member]
    }
    static 
    func buildBlock(_ members:[Member]...) -> [Member]
    {
        .init(members.joined())
    }
    
    static 
    func buildFinalResult(_ members:[Member]) -> Self 
    {
        return .init(
            properties: members.compactMap 
            {
                guard case .property(witness: let witness, symbol: let symbol) = $0 
                else 
                {
                    return nil 
                }
                return (witness, symbol)
            }, 
            methods: members.compactMap 
            {
                guard case .method(witness: let witness, symbol: let symbol) = $0 
                else 
                {
                    return nil 
                }
                return (witness, symbol)
            })
    }
}

// api interface
extension Godot 
{
    fileprivate private(set) static 
    var api:API.Core = .init(functions: .init())
    
    public 
    enum API 
    {
    }
    
    static 
    func print(_ items:Any..., separator:Swift.String = " ", terminator:Swift.String = "") 
    {
        Godot.String.init("(swift) \(items.map{"\($0)"}.joined(separator: separator))\(terminator)")
            .withUnsafePointer(Self.api.functions.godot_print)
    }
    static 
    func print(warning:Swift.String, function:Swift.String = #function, file:Swift.String = #file, line:Int32 = #line) 
    {
        Self.api.functions.godot_print_warning("(swift) \(warning)", function, file, line)
    }
    static 
    func print(error:Swift.String, function:Swift.String = #function, file:Swift.String = #file, line:Int32 = #line) 
    {
        Self.api.functions.godot_print_error("(swift) \(error)", function, file, line)
    }
    static 
    func print(error:Godot.Error, function:Swift.String = #function, file:Swift.String = #file, line:Int32 = #line) 
    {
        Self.print(error: error.description, function: function, file: file, line: line)
    }
}
extension Godot.API 
{
    public 
    struct Core 
    {
        fileprivate 
        let functions:godot_gdnative_core_api_struct 
        
        init(functions:godot_gdnative_core_api_struct) 
        {
            self.functions = functions 
        }
        
        var extensions:[UnsafePointer<godot_gdnative_api_struct>] 
        {
            (0 ..< .init(self.functions.num_extensions)).compactMap
            {
                self.functions.extensions[$0]
            }
        }
    }
    
    public 
    struct NativeScript 
    {
        typealias Initializer = @convention(c)
            (
                UnsafeMutableRawPointer?, 
                UnsafeMutableRawPointer?
            ) -> UnsafeMutableRawPointer?
        typealias Deinitializer = @convention(c)
            (
                UnsafeMutableRawPointer?, 
                UnsafeMutableRawPointer?, 
                UnsafeMutableRawPointer?
            ) -> ()
        typealias WitnessDeinitializer = @convention(c)
            (
                UnsafeMutableRawPointer?
            ) -> ()
        typealias Method = @convention(c) 
            (
                UnsafeMutableRawPointer?, 
                UnsafeMutableRawPointer?, 
                UnsafeMutableRawPointer?, 
                Int32, 
                UnsafeMutablePointer<UnsafeMutablePointer<godot_variant>?>?
            ) -> godot_variant
        
        private 
        let functions:godot_gdnative_ext_nativescript_api_struct,
            handle:UnsafeMutableRawPointer
        
        init(functions:godot_gdnative_ext_nativescript_api_struct, handle:UnsafeMutableRawPointer) 
        {
            self.functions  = functions 
            self.handle     = handle 
        }
        
        func register<T>(
            initializer:godot_instance_create_func, 
            deinitializer:godot_instance_destroy_func, 
            for _:T.Type, as symbol:String) 
            where T:Godot.NativeScript
        {
            Godot.print("registering \(T.self) as '\(symbol)'")
            
            self.functions.godot_nativescript_register_class(self.handle, 
                symbol, T.Delegate.name, initializer, deinitializer)
        }
        
        func register(method:godot_instance_method, as symbol:(type:String, method:String)) 
        {
            Godot.print("registering (function) as '\(symbol.type).\(symbol.method)'")
            
            let mode:godot_method_attributes = 
                .init(rpc_type: GODOT_METHOD_RPC_MODE_DISABLED)
            self.functions.godot_nativescript_register_method(self.handle, 
                symbol.type, symbol.method, mode, method)
        }
    }
}
extension Godot 
{
    static 
    func initialize(gdnative core:API.Core)
    {
        Self.api = core 
    }
    
    static 
    func initialize(library handle:UnsafeMutableRawPointer) 
    {
        for descriptor:UnsafePointer<godot_gdnative_api_struct> in self.api.extensions 
        {
            switch GDNATIVE_API_TYPES.init(rawValue: descriptor.pointee.type)
            {
            case GDNATIVE_EXT_NATIVESCRIPT:
                let api:API.NativeScript = .init(
                    functions: UnsafeRawPointer.init(descriptor).load(
                        as: godot_gdnative_ext_nativescript_api_struct.self), 
                    handle: handle)
                
                for (type, _):(NativeScriptCore.Type, [Swift.String]) in self.interface.types 
                {
                    type.register(with: api)
                }
            default:
                break
            }
        }
    }
    
    static 
    func deinitialize() 
    {
    }
}



protocol _GodotVariantRepresentable 
{
    init?(variant:Godot.Variant.Unmanaged)
    
    var variant:Godot.Variant.Unmanaged 
    {
        get 
    }
}
protocol _GodotVariant:Godot.VariantRepresentable
{
    typealias Unmanaged = _GodotVariantUnmanaged
    
    func passRetained() -> Unmanaged
}
extension Godot.Variant 
{
    // there is obviously no `pass(unretained:)`, because swift objects are 
    // already reference-counted 
    func pass<R>(_ body:(Unmanaged) throws -> R) rethrows -> R 
    {
        var unmanaged:Unmanaged = self.passRetained()
        defer { unmanaged.release() }
        return try body(unmanaged)
    }
    func passUnsafePointer<R>(_ body:(UnsafePointer<godot_variant>) throws -> R) 
        rethrows -> R 
    {
        try self.pass 
        {
            try $0.withUnsafePointer(body)
        }
    }
    func passRetainedUnsafeData() -> godot_variant 
    {
        self.passRetained().withUnsafePointer(\.pointee)
    }
    
    var variant:Godot.Variant.Unmanaged 
    {
        self.passRetained()
    }
}
extension Godot 
{
    typealias Variant = _GodotVariant
    typealias VariantRepresentable = _GodotVariantRepresentable
    
    /* struct VariadicArguments<T> where T:VariantRepresentable
    {
        let arguments:[T]
        
        init(_ arguments:[T]) 
        {
            self.arguments = arguments
        }
    } */
    
    // needed because tuples cannot conform to protocols
    struct Void 
    {
    }
    
    final 
    class String 
    {
        private 
        var core:godot_string
        
        fileprivate 
        init(core:godot_string) 
        {
            self.core = core
        }
        
        fileprivate 
        func withUnsafePointer<R>(_ body:(UnsafePointer<godot_string>) throws -> R)
            rethrows -> R 
        {
            try withExtendedLifetime(self)
            {
                try Swift.withUnsafePointer(to: self.core, body)
            }
        }
        
        deinit 
        {
            Godot.api.functions.godot_string_destroy(&self.core)
        }
    }
    
    final 
    class List 
    {
        private 
        var core:godot_array
        
        fileprivate 
        init(core:godot_array) 
        {
            self.core = core
        }
        
        fileprivate 
        func withUnsafePointer<R>(_ body:(UnsafePointer<godot_array>) throws -> R)
            rethrows -> R 
        {
            try withExtendedLifetime(self)
            {
                try Swift.withUnsafePointer(to: self.core, body)
            }
        }
        
        deinit 
        {
            Godot.api.functions.godot_array_destroy(&self.core)
        }
    }
    
    final 
    class Map 
    {
        private 
        var core:godot_dictionary
        
        fileprivate 
        init(core:godot_dictionary) 
        {
            self.core = core
        }
        
        fileprivate 
        func withUnsafePointer<R>(_ body:(UnsafePointer<godot_dictionary>) throws -> R)
            rethrows -> R 
        {
            try withExtendedLifetime(self)
            {
                try Swift.withUnsafePointer(to: self.core, body)
            }
        }
        
        deinit 
        {
            Godot.api.functions.godot_dictionary_destroy(&self.core)
        }
    }
}

extension Godot.Void:Godot.Variant 
{
    init?(variant:Godot.Variant.Unmanaged) 
    {
        guard let _:Swift.Void = variant(as: Swift.Void.self) else { return nil }
    }
    func passRetained() -> Godot.Variant.Unmanaged 
    {
        .init()
    }
}
extension Bool:Godot.Variant 
{
    init?(variant:Godot.Variant.Unmanaged) 
    {
        if let value:Self = variant(as: Bool.self) { self = value } else { return nil }
    }
    func passRetained() -> Godot.Variant.Unmanaged 
    {
        .init(self)
    }
}
extension Int64:Godot.Variant 
{
    init?(variant:Godot.Variant.Unmanaged) 
    {
        if let value:Self = variant(as: Int64.self) { self = value } else { return nil }
    }
    func passRetained() -> Godot.Variant.Unmanaged 
    {
        .init(self)
    }
}
extension Float64:Godot.Variant 
{
    init?(variant:Godot.Variant.Unmanaged) 
    {
        if let value:Self = variant(as: Float64.self) { self = value } else { return nil }
    }
    func passRetained() -> Godot.Variant.Unmanaged 
    {
        .init(self)
    }
}

extension Godot.String:Godot.Variant 
{
    convenience
    init?(variant:Godot.Variant.Unmanaged) 
    {
        guard let core:godot_string = variant.load(as: godot_string.self)
        else 
        { 
            return nil 
        }
        self.init(core: core)
    }
    func passRetained() -> Godot.Variant.Unmanaged 
    {
        .pass(retained: self)
    }
}
extension Godot.List:Godot.Variant 
{
    convenience
    init?(variant:Godot.Variant.Unmanaged) 
    {
        guard let core:godot_array = variant.load(as: godot_array.self)
        else 
        { 
            return nil 
        }
        self.init(core: core)
    }
    func passRetained() -> Godot.Variant.Unmanaged 
    {
        .pass(retained: self)
    }
}
extension Godot.Map:Godot.Variant 
{
    convenience
    init?(variant:Godot.Variant.Unmanaged) 
    {
        guard let core:godot_dictionary = variant.load(as: godot_dictionary.self)
        else 
        { 
            return nil 
        }
        self.init(core: core)
    }
    func passRetained() -> Godot.Variant.Unmanaged 
    {
        .pass(retained: self)
    }
}

struct _GodotVariantUnmanaged 
{
    private 
    var data:godot_variant 
    
    init(data:godot_variant) 
    {
        self.data = data
    }
    fileprivate 
    init<T>(value:T, _ body:(UnsafeMutablePointer<godot_variant>, T) throws -> ()) rethrows
    {
        self.init(data: .init())
        try body(&self.data, value)
    }
}
extension Godot.Variant.Unmanaged 
{
    init() 
    {
        self.data = .init() 
        Godot.api.functions.godot_variant_new_nil(&self.data)
    }
    init(_ value:Bool) 
    {
        self.init(value: value, Godot.api.functions.godot_variant_new_bool)
    }
    init(_ value:Int64) 
    {
        self.init(value: value, Godot.api.functions.godot_variant_new_int)
    }
    init(_ value:UInt64) 
    {
        self.init(value: value, Godot.api.functions.godot_variant_new_uint)
    }
    init(_ value:Float64) 
    {
        self.init(value: value, Godot.api.functions.godot_variant_new_real)
    }
    
    static 
    func pass(retained value:Godot.String) -> Self
    {
        value.withUnsafePointer 
        {
            .init(value: $0, Godot.api.functions.godot_variant_new_string)
        }
    }
    static 
    func pass(retained value:Godot.List) -> Self
    {
        value.withUnsafePointer 
        {
            .init(value: $0, Godot.api.functions.godot_variant_new_array)
        }
    }
    static 
    func pass(retained value:Godot.Map) -> Self
    {
        value.withUnsafePointer 
        {
            .init(value: $0, Godot.api.functions.godot_variant_new_dictionary)
        }
    }
    
    private static 
    func type(of pointer:UnsafePointer<godot_variant>) -> godot_variant_type 
    {
        UnsafeRawPointer.init(pointer).load(as: godot_variant_type.self)
    }
    private 
    var type:godot_variant_type 
    {
        self.withUnsafePointer(Self.type(of:))
    } 
    
    func callAsFunction(as _:Void.Type) -> Void? 
    {
        guard self.type == GODOT_VARIANT_TYPE_NIL       else { return nil }
        return ()
    }
    func callAsFunction(as _:Bool.Type) -> Bool? 
    {
        guard self.type == GODOT_VARIANT_TYPE_BOOL      else { return nil }
        return self.withUnsafePointer(Godot.api.functions.godot_variant_as_bool)
    }
    func callAsFunction(as _:Int64.Type) -> Int64? 
    {
        guard self.type == GODOT_VARIANT_TYPE_INT       else { return nil }
        return self.withUnsafePointer(Godot.api.functions.godot_variant_as_int)
    }
    func callAsFunction(as _:UInt64.Type) -> UInt64? 
    {
        guard self.type == GODOT_VARIANT_TYPE_INT       else { return nil }
        return self.withUnsafePointer(Godot.api.functions.godot_variant_as_uint)
    }
    func callAsFunction(as _:Float64.Type) -> Float64? 
    {
        guard self.type == GODOT_VARIANT_TYPE_REAL      else { return nil }
        return self.withUnsafePointer(Godot.api.functions.godot_variant_as_real)
    }
    
    // needed because class convenience initializers cannot replace `self`
    fileprivate 
    func load(as _:godot_string.Type) -> godot_string? 
    {
        guard self.type == GODOT_VARIANT_TYPE_STRING        else { return nil }
        return self.withUnsafePointer(Godot.api.functions.godot_variant_as_string)
    }
    fileprivate 
    func load(as _:godot_array.Type) -> godot_array? 
    {
        guard self.type == GODOT_VARIANT_TYPE_ARRAY         else { return nil }
        return self.withUnsafePointer(Godot.api.functions.godot_variant_as_array)
    }
    fileprivate 
    func load(as _:godot_dictionary.Type) -> godot_dictionary?
    {
        guard self.type == GODOT_VARIANT_TYPE_DICTIONARY    else { return nil }
        return self.withUnsafePointer(Godot.api.functions.godot_variant_as_dictionary)
    }
    
    func take(unretained _:Godot.String.Type) -> Godot.String? 
    {
        self.load(as:     godot_string.self).map(Godot.String.init(core:))
    }
    func take(unretained _:Godot.List.Type) -> Godot.List? 
    {
        self.load(as:      godot_array.self).map(Godot.List.init(core:))
    }
    func take(unretained _:Godot.Map.Type) -> Godot.Map? 
    {
        self.load(as: godot_dictionary.self).map(Godot.Map.init(core:))
    }
    
    fileprivate 
    func withUnsafePointer<R>(_ body:(UnsafePointer<godot_variant>) throws -> R)
        rethrows -> R 
    {
        try Swift.withUnsafePointer(to: self.data, body)
    }
    
    @available(*, unavailable, message: "unimplemented")
    mutating 
    func retain() 
    {
    }
    mutating 
    func release() 
    {
        Godot.api.functions.godot_variant_destroy(&self.data)
    }
}
extension Godot.Variant.Unmanaged 
{
    var unsafeData:godot_variant 
    {
        self.data 
    }
    
    static 
    func takeUnretainedValue(from pointer:UnsafePointer<godot_variant>) -> Godot.Variant
    {
        switch Self.type(of: pointer)
        {
        case GODOT_VARIANT_TYPE_NIL:
            return Godot.Void.init()
        case GODOT_VARIANT_TYPE_BOOL:
            return Godot.api.functions.godot_variant_as_bool(pointer)
        case GODOT_VARIANT_TYPE_INT:
            return Godot.api.functions.godot_variant_as_int(pointer)
        case GODOT_VARIANT_TYPE_REAL:
            return Godot.api.functions.godot_variant_as_real(pointer)
        
        case GODOT_VARIANT_TYPE_STRING:
            return Godot.String.init(core: 
                Godot.api.functions.godot_variant_as_string(pointer))
        case GODOT_VARIANT_TYPE_ARRAY:
            return Godot.List.init(core: 
                Godot.api.functions.godot_variant_as_array(pointer))
        case GODOT_VARIANT_TYPE_DICTIONARY:
            return Godot.Map.init(core: 
                Godot.api.functions.godot_variant_as_dictionary(pointer))
        
        case let code:
            Godot.print(error: "variant type (code: \(code)) is unsupported")
            return Godot.Void.init()
        }
    }
    
    func takeUnretainedValue() -> Godot.Variant
    {
        self.withUnsafePointer(Self.takeUnretainedValue(from:))
    }
    
    mutating 
    func takeRetainedValue() -> Godot.Variant
    {
        defer { self.release() }
        return self.takeUnretainedValue()
    }
}

extension Godot.String 
{
    convenience
    init(_ string:Swift.String)
    {
        self.init(core: .init())
            Godot.api.functions.godot_string_new(&self.core)
        if  Godot.api.functions.godot_string_parse_utf8(&self.core, string)
        {
            Godot.print(error: "malformed utf-8 bytes in swift string")
        }
    }
}
extension Swift.String 
{
    init(_ string:Godot.String)
    {
        var utf8:godot_char_string = 
            string.withUnsafePointer(Godot.api.functions.godot_string_utf8)
        self.init(cString: unsafeBitCast(utf8, to: UnsafePointer<Int8>.self))
        Godot.api.functions.godot_char_string_destroy(&utf8)
    } 
}

extension Godot.List:RandomAccessCollection, MutableCollection
{
    convenience 
    init(capacity:Int = 0) 
    {
        self.init(core: .init())
        Godot.api.functions.godot_array_new(&self.core)
        self.resize(to: capacity)
    }
    
    func resize(to capacity:Int) 
    {
        Godot.api.functions.godot_array_resize(&self.core, .init(capacity))
    }
    
    var startIndex:Int 
    {
        0
    }
    var endIndex:Int 
    {
        .init(Godot.api.functions.godot_array_size(&self.core))
    }
    
    subscript(index:Int) -> Godot.Variant 
    {
        get 
        {
            self.withUnsafePointer
            {
                var unmanaged:Godot.Variant.Unmanaged = 
                    .init(data: Godot.api.functions.godot_array_get($0, .init(index)))
                return unmanaged.takeRetainedValue()
            }
        }
        set(value) 
        {
            value.passUnsafePointer 
            {
                (value:UnsafePointer<godot_variant>) in 
                
                Godot.api.functions.godot_array_set(&self.core, .init(index), value)
            }
        }
    } 
}
extension Godot.List:ExpressibleByArrayLiteral 
{
    convenience 
    init(arrayLiteral elements:Godot.Variant...) 
    {
        self.init(capacity: elements.count)
        for (i, element):(Int, Godot.Variant) in elements.enumerated()
        {
            self[i] = element 
        }
    }
}
extension Godot.Map
{
    convenience 
    init() 
    {
        self.init(core: .init())
        Godot.api.functions.godot_dictionary_new(&self.core)
    }
    
    subscript(key:Godot.Variant) -> Godot.Variant 
    {
        get 
        {
            key.passUnsafePointer 
            {
                (key:UnsafePointer<godot_variant>) in 
                
                self.withUnsafePointer
                {
                    var unmanaged:Godot.Variant.Unmanaged = 
                        .init(data: Godot.api.functions.godot_dictionary_get($0, key))
                    return unmanaged.takeRetainedValue()
                }
            }
        }
        set(value) 
        {
            key.passUnsafePointer 
            {
                (key:UnsafePointer<godot_variant>) in 
                
                value.passUnsafePointer 
                {
                    (value:UnsafePointer<godot_variant>) in 
                    
                    Godot.api.functions.godot_dictionary_set(&self.core, key, value)
                }
            }
        }
    } 
} 
extension Godot.Map:ExpressibleByDictionaryLiteral 
{
    convenience 
    init(dictionaryLiteral items:(Godot.Variant, Godot.Variant)...) 
    {
        self.init()
        for (key, value):(Godot.Variant, Godot.Variant) in items 
        {
            self[key] = value 
        }
    }
}


extension Optional:Godot.VariantRepresentable where Wrapped:Godot.VariantRepresentable 
{
    init?(variant:Godot.Variant.Unmanaged) 
    {
        if let wrapped:Wrapped  = .init(variant: variant)
        {
            self = .some(wrapped)
        }
        else if let _:Void      = variant(as: Void.self)
        {
            self = .none 
        }
        else 
        {
            return nil 
        }
    }
    var variant:Godot.Variant.Unmanaged 
    {
        self?.variant ?? .init()
    }
}

extension String:Godot.VariantRepresentable 
{
    init?(variant:Godot.Variant.Unmanaged) 
    {
        if let value:Godot.String = .init(variant: variant) 
        { 
            self.init(value) 
        } 
        else 
        { 
            return nil 
        }
    }
    var variant:Godot.Variant.Unmanaged 
    {
        Godot.String.init(self).passRetained()
    }
} 
extension UInt64:Godot.VariantRepresentable 
{
    init?(variant:Godot.Variant.Unmanaged) 
    {
        if let value:Self = variant(as: UInt64.self) { self = value } else { return nil }
    }
    var variant:Godot.Variant.Unmanaged 
    {
        .init(self)
    }
}
extension UInt32:Godot.VariantRepresentable 
{
    init?(variant:Godot.Variant.Unmanaged) 
    {
        guard let value:UInt64 = variant(as: UInt64.self) else { return nil }
        self.init(exactly: value)
    }
    var variant:Godot.Variant.Unmanaged 
    {
        .init(UInt64.init(self))
    }
}
extension UInt16:Godot.VariantRepresentable 
{
    init?(variant:Godot.Variant.Unmanaged) 
    {
        guard let value:UInt64 = variant(as: UInt64.self) else { return nil }
        self.init(exactly: value)
    }
    var variant:Godot.Variant.Unmanaged 
    {
        .init(UInt64.init(self))
    }
}
extension UInt8:Godot.VariantRepresentable 
{
    init?(variant:Godot.Variant.Unmanaged) 
    {
        guard let value:UInt64 = variant(as: UInt64.self) else { return nil }
        self.init(exactly: value)
    }
    var variant:Godot.Variant.Unmanaged 
    {
        .init(UInt64.init(self))
    }
}

extension Int32:Godot.VariantRepresentable 
{
    init?(variant:Godot.Variant.Unmanaged) 
    {
        guard let value:Int64 = variant(as: Int64.self) else { return nil }
        self.init(exactly: value)
    }
    var variant:Godot.Variant.Unmanaged 
    {
        .init(Int64.init(self))
    }
}
extension Int16:Godot.VariantRepresentable 
{
    init?(variant:Godot.Variant.Unmanaged) 
    {
        guard let value:Int64 = variant(as: Int64.self) else { return nil }
        self.init(exactly: value)
    }
    var variant:Godot.Variant.Unmanaged 
    {
        .init(Int64.init(self))
    }
}
extension Int8:Godot.VariantRepresentable 
{
    init?(variant:Godot.Variant.Unmanaged) 
    {
        guard let value:Int64 = variant(as: Int64.self) else { return nil }
        self.init(exactly: value)
    }
    var variant:Godot.Variant.Unmanaged 
    {
        .init(Int64.init(self))
    }
}

extension Int:Godot.VariantRepresentable 
{
    init?(variant:Godot.Variant.Unmanaged) 
    {
        guard let value:Int64 = variant(as: Int64.self) else { return nil }
        self.init(exactly: value)
    }
    var variant:Godot.Variant.Unmanaged 
    {
        .init(Int64.init(self))
    }
} 
extension UInt:Godot.VariantRepresentable 
{
    init?(variant:Godot.Variant.Unmanaged) 
    {
        guard let value:UInt64 = variant(as: UInt64.self) else { return nil }
        self.init(exactly: value)
    }
    var variant:Godot.Variant.Unmanaged 
    {
        .init(UInt64.init(self))
    }
} 

extension Godot 
{    
    struct MeshInstance:NativeScriptDelegate 
    {
        static 
        let name:Swift.String = "MeshInstance"
        
        init(_:UnsafeMutableRawPointer)
        {
        }
    }
}

extension Godot 
{
    enum Error:Swift.Error 
    {
        case invalidArgument(Godot.Variant, expected:Any.Type)
        case invalidArgumentTuple(Int, expected:Any.Type)
        case invalidArgumentCount(Int, expected:Int)
    }
}
extension Godot.Error:CustomStringConvertible 
{
    var description:String 
    {
        switch self 
        {
        case .invalidArgumentCount(let count, expected: let expected):
            if count < expected
            {
                let positions:String = (count ..< expected).map{ "#\($0)" }.joined(separator: ",")
                return "missing arguments for parameter\(expected - count > 1 ? "s" : "") \(positions) in call"
            }
            else 
            {
                let positions:String = (expected ..< count).map{ "#\($0)" }.joined(separator: ",")
                return "extra arguments at positions\(count - expected > 1 ? "s" : "") \(positions) in call"
            }
        case .invalidArgumentTuple(let count, expected: let expected):
            return "cannot convert Godot.List with \(count) elements to expected argument type '\(String.init(reflecting: expected))'"
        case .invalidArgument(let value, expected: let expected):
            return "cannot convert value of type '\(String.init(reflecting: type(of: value)))' to expected argument type '\(String.init(reflecting: expected))'"
        }
    }
}

@_cdecl("godot_gdnative_init")
public 
func godot_gdnative_init(options:UnsafePointer<godot_gdnative_init_options>)
{
    Godot.initialize(gdnative: .init(functions: options.pointee.api_struct.pointee))
}

@_cdecl("godot_nativescript_init")
public 
func godot_nativescript_init(handle:UnsafeMutableRawPointer) 
{
    Godot.initialize(library: handle)
}

@_cdecl("godot_gdnative_terminate")
public 
func godot_gdnative_terminate(options _:UnsafePointer<godot_gdnative_terminate_options>)
{
    Godot.deinitialize()
}
