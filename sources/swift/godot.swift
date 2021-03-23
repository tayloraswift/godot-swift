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
    var interface:Interface 
    {
        .init(properties: [], methods: [])
    }
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
            typealias Method    = (T, T.Delegate, Godot.VariadicArguments) -> Godot.Variant.Unmanaged
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
    fileprivate private(set) 
    static 
    var api:API.Core        = .init()
    
    fileprivate private(set) 
    static 
    var runtime:API.Runtime = .init()
    
    public 
    enum API 
    {
    }
    
    static 
    func print(_ items:Any..., separator:Swift.String = " ", terminator:Swift.String = "") 
    {
        Godot.String.init("(swift) \(items.map{"\($0)"}.joined(separator: separator))\(terminator)")
            .withUnsafePointer(Self.api.core.1.0.godot_print)
    }
    static 
    func print(warning:Swift.String, function:Swift.String = #function, file:Swift.String = #file, line:Int32 = #line) 
    {
        Self.api.core.1.0.godot_print_warning("(swift) \(warning)", function, file, line)
    }
    static 
    func print(error:Swift.String, function:Swift.String = #function, file:Swift.String = #file, line:Int32 = #line) 
    {
        Self.api.core.1.0.godot_print_error("(swift) \(error)", function, file, line)
    }
    static 
    func print(error:Godot.Error, function:Swift.String = #function, file:Swift.String = #file, line:Int32 = #line) 
    {
        Self.print(error: error.description, function: function, file: file, line: line)
    }
}
extension Godot.API 
{
    //public 
    struct Core 
    {
        fileprivate 
        let core:
        (
            Void, 
            (
                godot_gdnative_core_api_struct, 
                godot_gdnative_core_1_1_api_struct, 
                godot_gdnative_core_1_2_api_struct
            )
        )
        
        init() 
        {
            self.core.1.0   = .init() 
            self.core.1.1   = .init()
            self.core.1.2   = .init()
        }
    }
}
extension Godot.API.Core 
{        
    init(head:godot_gdnative_core_api_struct) 
    {
        // find the highest api version available 
        var version:godot_gdnative_api_version = head.version
        var next:UnsafePointer<godot_gdnative_api_struct>? = head.next 
        while let current:UnsafePointer<godot_gdnative_api_struct> = next 
        {
            version = current.pointee.version
            next    = current.pointee.next
        }
        
        guard   let v1_1:UnsafePointer<godot_gdnative_api_struct> = head.next, 
                let v1_2:UnsafePointer<godot_gdnative_api_struct> = v1_1.pointee.next 
        else 
        {
            fatalError("godot-swift requires gdnative version 1.2 or higher (have version \(version.major).\(version.minor))")
        }
        
        self.core.1.0   = head
        self.core.1.1   = UnsafeRawPointer.init(v1_1)
            .load(as: godot_gdnative_core_1_1_api_struct.self)
        self.core.1.2   = UnsafeRawPointer.init(v1_2)
            .load(as: godot_gdnative_core_1_2_api_struct.self)
    }
    
    /* fileprivate mutating 
    func loadTypeMetadata() 
    {

    } */
    

    
    fileprivate 
    var extensions:[UnsafePointer<godot_gdnative_api_struct>] 
    {
        (0 ..< .init(self.core.1.0.num_extensions)).compactMap
        {
            self.core.1.0.extensions[$0]
        }
    }
}
extension Godot.API 
{
    struct Runtime 
    {
        private 
        typealias Function  = UnsafeMutablePointer<godot_method_bind>
        
        private 
        typealias Functions = 
        (
            retain:Function?,
            release:Function?,
            classname:Function?
        )
        
        private 
        var functions:Functions 
        
        init() 
        {
            self.functions = (nil, nil, nil)
        }
    }
}
extension Godot.API.Runtime 
{
    mutating 
    func load() 
    {
        self.load(("Reference", "reference"  ), as: \.retain)
        self.load(("Reference", "unreference"), as: \.release)
        self.load(("Object"   , "get_class"  ), as: \.classname)
    }
    
    private mutating 
    func load(_ symbol:(class:String, method:String), as path:WritableKeyPath<Functions, Function?>) 
    {
        if let function:Function = 
            Godot.api.core.1.0.godot_method_bind_get_method(symbol.class, symbol.method)
        {
            self.functions[keyPath: path] = function 
        }
        else 
        {
            fatalError("could not load gdscript function '\(symbol.class).\(symbol.method)'")
        }
    } 
    
    func retain(_ object:UnsafeMutableRawPointer) 
    {
        var status:Bool = false 
        Godot.api.core.1.0.godot_method_bind_ptrcall(
            self.functions.retain, object, nil, &status)
        guard status 
        else 
        {
            fatalError("could not retain object of class '\(self.classname(of: object))' at <\(object)>")
        }
    }
    @discardableResult
    func release(_ object:UnsafeMutableRawPointer) -> Bool 
    {
        var status:Bool = false 
        Godot.api.core.1.0.godot_method_bind_ptrcall(
            self.functions.release, object, nil, &status)
        return status // true if we released the last reference
    }
    
    func classname(of delegate:UnsafeMutableRawPointer) -> Swift.String 
    {
        var core:godot_string = .init()
        Godot.api.core.1.0.godot_method_bind_ptrcall(
            self.functions.classname, delegate, nil, &core)
        return Swift.String.init(Godot.String.init(core: core))
    }
}

extension Godot.API 
{
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
        let builtin:godot_gdnative_ext_nativescript_api_struct,
            handle:UnsafeMutableRawPointer
        
        init(builtin:godot_gdnative_ext_nativescript_api_struct, handle:UnsafeMutableRawPointer) 
        {
            self.builtin    = builtin 
            self.handle     = handle 
        }
    }
}
extension Godot.API.NativeScript 
{        
    func register<T>(
        initializer:godot_instance_create_func, 
        deinitializer:godot_instance_destroy_func, 
        for _:T.Type, as symbol:String) 
        where T:Godot.NativeScript
    {
        Godot.print("registering \(T.self) as '\(symbol)'")
        
        self.builtin.godot_nativescript_register_class(self.handle, 
            symbol, T.Delegate.name, initializer, deinitializer)
    }
    
    func register(method:godot_instance_method, as symbol:(type:String, method:String)) 
    {
        Godot.print("registering (function) as '\(symbol.type).\(symbol.method)'")
        
        let mode:godot_method_attributes = 
            .init(rpc_type: GODOT_METHOD_RPC_MODE_DISABLED)
        self.builtin.godot_nativescript_register_method(self.handle, 
            symbol.type, symbol.method, mode, method)
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
                    builtin: UnsafeRawPointer.init(descriptor)
                        .load(as: godot_gdnative_ext_nativescript_api_struct.self), 
                    handle: handle)
                
                for (type, _):(NativeScriptCore.Type, [Swift.String]) in self.interface.types 
                {
                    type.register(with: api)
                }
            default:
                break
            }
        }
        
        self.runtime.load()
    }
    
    static 
    func deinitialize() 
    {
    }
}



protocol _GodotVariantRepresentable 
{
    init?(unretainedValue value:Godot.Variant.Unmanaged) 
    var retainedValue:Godot.Variant.Unmanaged 
    {
        get
    }
}

protocol _GodotVariant:Godot.VariantRepresentable
{
    typealias Unmanaged = _GodotVariantUnmanaged
}

extension Godot 
{
    typealias Variant = _GodotVariant
    typealias VariantRepresentable = _GodotVariantRepresentable
    
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
            Godot.api.core.1.0.godot_string_destroy(&self.core)
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
            Godot.api.core.1.0.godot_array_destroy(&self.core)
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
            Godot.api.core.1.0.godot_dictionary_destroy(&self.core)
        }
    }
}
extension Godot 
{
    enum Ancestor 
    {
        typealias AnyDelegate           = AnyObject & Unmanaged.MeshInstance
        typealias AnyObject             = Resource 
        
        typealias Resource              = _GodotAncestorResource
        
        enum Unmanaged 
        {
            typealias MeshInstance      = _GodotAncestorUnmanagedMeshInstance
        }
    }
    
    struct AnyDelegate:NativeScriptDelegate, Ancestor.AnyDelegate
    {
        private 
        enum Existential 
        {
            case unmanaged(UnsafeMutableRawPointer)
            case managed(AnyObject)
        }
        
        private 
        let existential:Existential
        
        static 
        let name:Swift.String = "Object"
        
        init(_ delegate:UnsafeMutableRawPointer) 
        {
            // FIXME 
            self.existential = .unmanaged(delegate)
        }
    }
    
    enum Unmanaged 
    {
    }
    
    final 
    class AnyObject:NativeScriptDelegate, Ancestor.AnyObject 
    {
        static 
        let name:Swift.String = "Reference"
        
        private 
        let object:UnsafeMutableRawPointer
        
        init(_ object:UnsafeMutableRawPointer)
        {
            self.object = object
        }
    }
    
    final 
    class Resource:NativeScriptDelegate, Ancestor.Resource 
    {
        static 
        let name:Swift.String = "Resource"
        
        private 
        let object:UnsafeMutableRawPointer
        
        init(_ object:UnsafeMutableRawPointer)
        {
            self.object = object
        }
    }
}

extension Godot.Unmanaged 
{
    struct MeshInstance:Godot.NativeScriptDelegate, Godot.Ancestor.Unmanaged.MeshInstance
    {
        static 
        let name:Swift.String = "MeshInstance"
        
        init(_:UnsafeMutableRawPointer)
        {
        }
    }
}

protocol _GodotAncestorUnmanagedMeshInstance {}
protocol _GodotAncestorResource {}


extension Godot 
{
    struct VariadicArguments 
    {
        private 
        let arguments:[UnsafeMutablePointer<Variant.Unmanaged>]
        
        static 
        func bind<R>(_ start:UnsafeMutablePointer<UnsafeMutablePointer<godot_variant>?>?, count:Int, 
            _ body:(Self) throws -> R) 
            rethrows -> R
        {
            guard count > 0, 
                let base:UnsafeMutablePointer<UnsafeMutablePointer<godot_variant>?> = start 
            else 
            {
                return try body(.init(arguments: []))
            }
            
            // assert arguments pointers are non-nil 
            guard ((0 ..< count).allSatisfy{ base[$0] != nil }) 
            else 
            {
                Godot.print(error: "received nil argument pointer in method call")
                return try body(.init(arguments: []))
            }
            
            return try body(.init(arguments: (0 ..< count).map 
            {
                // can use `!` because we already checked for non-nil pointers
                UnsafeMutableRawPointer.init(base[$0]!).bindMemory(
                    to: Variant.Unmanaged.self, capacity: 1)
            }))
        }
        
        static 
        func call<T>(_ method:
            (
                witness:(T, T.Delegate, Godot.VariadicArguments) -> Godot.Variant.Unmanaged, 
                symbol:Swift.String
            ), 
            instance:UnsafeMutableRawPointer?, 
            delegate:UnsafeMutableRawPointer?, 
            arguments:
            (
                start:UnsafeMutablePointer<UnsafeMutablePointer<godot_variant>?>?,
                count:Int
            ))
            -> godot_variant 
            where T:Godot.NativeScript
        {
            var description:Swift.String 
            {
                "method '\(method.symbol)' (from interface of \(Swift.String.init(reflecting: T.self)))"
            }
            
            // unretained because godot retained `self` in the initializer call
            guard let instance:Swift.AnyObject = (instance.map 
            {
                Swift.Unmanaged<Swift.AnyObject>.fromOpaque($0).takeUnretainedValue()
            })
            else 
            {
                fatalError("(swift) \(description) received nil instance pointer")
            }
            guard let delegate:T.Delegate = delegate.map(T.Delegate.init(_:)) 
            else 
            {
                fatalError("(swift) \(description) received nil delegate pointer")
            }
            
            guard let self:T = instance as? T
            else 
            {
                fatalError("(swift) cannot call \(description) on instance of type \(Swift.String.init(reflecting: type(of: instance)))")
            }
            
            return Self.bind(arguments.start, count: arguments.count)
            {
                method.witness(self, delegate, $0).unsafeData
            }
        }
    }
}

extension Godot.Void:Godot.Variant 
{
    init?(unretainedValue value:Godot.Variant.Unmanaged) 
    {
        guard let _:Swift.Void = value(as: Swift.Void.self) else { return nil }
    }
    var retainedValue:Godot.Variant.Unmanaged 
    {
        .init()
    }
} 
extension Bool:Godot.Variant 
{
    init?(unretainedValue value:Godot.Variant.Unmanaged) 
    {
        if let value:Self = value(as: Bool.self) { self = value } else { return nil }
    }
    var retainedValue:Godot.Variant.Unmanaged 
    {
        .init(self)
    }
}
extension Int64:Godot.Variant 
{
    init?(unretainedValue value:Godot.Variant.Unmanaged) 
    {
        if let value:Self = value(as: Int64.self) { self = value } else { return nil }
    }
    var retainedValue:Godot.Variant.Unmanaged 
    {
        .init(self)
    }
}
extension Float64:Godot.Variant 
{
    init?(unretainedValue value:Godot.Variant.Unmanaged) 
    {
        if let value:Self = value(as: Float64.self) { self = value } else { return nil }
    }
    var retainedValue:Godot.Variant.Unmanaged 
    {
        .init(self)
    }
}

extension Godot.String:Godot.Variant 
{
    convenience
    init?(unretainedValue value:Godot.Variant.Unmanaged) 
    {
        guard let core:godot_string = value.load(as: godot_string.self)
        else 
        { 
            return nil 
        }
        self.init(core: core)
    }
    var retainedValue:Godot.Variant.Unmanaged 
    {
        self.withUnsafePointer
        {
            return .init(value: $0, Godot.api.core.1.0.godot_variant_new_string)
        }
    }
}
extension Godot.List:Godot.Variant 
{
    convenience
    init?(unretainedValue value:Godot.Variant.Unmanaged) 
    {
        guard let core:godot_array = value.load(as: godot_array.self)
        else 
        { 
            return nil 
        }
        self.init(core: core)
    }
    var retainedValue:Godot.Variant.Unmanaged 
    {
        self.withUnsafePointer
        {
            .init(value: $0, Godot.api.core.1.0.godot_variant_new_array)
        }
    }
}
extension Godot.Map:Godot.Variant 
{
    convenience
    init?(unretainedValue value:Godot.Variant.Unmanaged) 
    {
        guard let core:godot_dictionary = value.load(as: godot_dictionary.self)
        else 
        { 
            return nil 
        }
        self.init(core: core)
    }
    var retainedValue:Godot.Variant.Unmanaged 
    {
        self.withUnsafePointer
        {
            .init(value: $0, Godot.api.core.1.0.godot_variant_new_dictionary)
        }
    }
}

struct _GodotVariantUnmanaged 
{
    private 
    var data:godot_variant 
    
    fileprivate 
    var unsafeData:godot_variant 
    {
        self.data 
    } 
    
    fileprivate 
    init(unsafeData data:godot_variant) 
    {
        self.data = data
    }
    
    fileprivate 
    init<T>(value:T, _ body:(UnsafeMutablePointer<godot_variant>, T) throws -> ()) rethrows
    {
        self.data = .init()
        try body(&self.data, value)
    }
}
extension Godot.Variant.Unmanaged 
{
    init() 
    {
        self.data = .init() 
        Godot.api.core.1.0.godot_variant_new_nil(&self.data)
    }
    init(_ value:Bool) 
    {
        self.init(value: value, Godot.api.core.1.0.godot_variant_new_bool)
    }
    init(_ value:Int64) 
    {
        self.init(value: value, Godot.api.core.1.0.godot_variant_new_int)
    }
    init(_ value:UInt64) 
    {
        self.init(value: value, Godot.api.core.1.0.godot_variant_new_uint)
    }
    init(_ value:Float64) 
    {
        self.init(value: value, Godot.api.core.1.0.godot_variant_new_real)
    }
    
    private 
    func withUnsafePointer<R>(_ body:(UnsafePointer<godot_variant>) throws -> R)
        rethrows -> R 
    {
        try Swift.withUnsafePointer(to: self.data, body)
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
        return self.withUnsafePointer(Godot.api.core.1.0.godot_variant_as_bool)
    }
    func callAsFunction(as _:Int64.Type) -> Int64? 
    {
        guard self.type == GODOT_VARIANT_TYPE_INT       else { return nil }
        return self.withUnsafePointer(Godot.api.core.1.0.godot_variant_as_int)
    }
    func callAsFunction(as _:UInt64.Type) -> UInt64? 
    {
        guard self.type == GODOT_VARIANT_TYPE_INT       else { return nil }
        return self.withUnsafePointer(Godot.api.core.1.0.godot_variant_as_uint)
    }
    func callAsFunction(as _:Float64.Type) -> Float64? 
    {
        guard self.type == GODOT_VARIANT_TYPE_REAL      else { return nil }
        return self.withUnsafePointer(Godot.api.core.1.0.godot_variant_as_real)
    }
    
    // needed because class convenience initializers cannot replace `self`
    fileprivate 
    func load(as _:godot_string.Type) -> godot_string? 
    {
        guard self.type == GODOT_VARIANT_TYPE_STRING        else { return nil }
        return self.withUnsafePointer(Godot.api.core.1.0.godot_variant_as_string)
    }
    fileprivate 
    func load(as _:godot_array.Type) -> godot_array? 
    {
        guard self.type == GODOT_VARIANT_TYPE_ARRAY         else { return nil }
        return self.withUnsafePointer(Godot.api.core.1.0.godot_variant_as_array)
    }
    fileprivate 
    func load(as _:godot_dictionary.Type) -> godot_dictionary?
    {
        guard self.type == GODOT_VARIANT_TYPE_DICTIONARY    else { return nil }
        return self.withUnsafePointer(Godot.api.core.1.0.godot_variant_as_dictionary)
    }
    
    @available(*, unavailable, message: "unimplemented")
    mutating 
    func retain() 
    {
    }
    mutating 
    func release() 
    {
        Godot.api.core.1.0.godot_variant_destroy(&self.data)
    }
}
extension Godot.Variant.Unmanaged 
{
    static 
    func pass<T, R>(_ value:T, _ body:(Self) throws -> R) rethrows -> R
        where T:Godot.VariantRepresentable 
    {
        var unmanaged:Self = .pass(retained: value)
        defer { unmanaged.release() }
        return try body(unmanaged)
    }
    static 
    func pass<R>(_ value:Godot.Variant, _ body:(Self) throws -> R) rethrows -> R
    {
        var unmanaged:Self = .pass(retained: value)
        defer { unmanaged.release() }
        return try body(unmanaged)
    }
    static 
    func pass<R>(_ value:Godot.Variant, _ body:(UnsafePointer<godot_variant>) throws -> R) rethrows -> R
    {
        var unmanaged:Self = .pass(retained: value)
        defer { unmanaged.release() }
        return try unmanaged.withUnsafePointer(body)
    }
    
    static 
    func pass<T>(retained value:T) -> Self 
        where T:Godot.VariantRepresentable 
    {
        value.retainedValue
    }
    static 
    func pass(retained value:Godot.Variant) -> Self
    {
        value.retainedValue
    }
    static 
    func pass(retained value:Void) -> Self
    {
        .init()
    }
    
    // FIXME: this should really use an atomic swap
    private mutating 
    func assign(_ other:Self) 
    {
        // deinitialize existing value 
        self.release() 
        self = other
    }
    mutating 
    func assign<T>(retained value:T) 
        where T:Godot.VariantRepresentable 
    {
        self.assign(.pass(retained: value))
    }
    mutating 
    func assign(retained value:Godot.Variant) 
    {
        self.assign(.pass(retained: value))
    }
    
    mutating 
    func take<T>(retained _:T.Type) -> T? 
        where T:Godot.VariantRepresentable 
    {
        defer { self.release() }
        return T.init(unretainedValue: self)
    }
    func take<T>(unretained _:T.Type) -> T? 
        where T:Godot.VariantRepresentable 
    {
        return T.init(unretainedValue: self)
    }
    func take(unretained _:Void.Type) -> Void?
    {
        self(as: Void.self)
    }
    func take(unretained _:Godot.Variant.Protocol) -> Godot.Variant
    {
        self.withUnsafePointer 
        {
            switch Self.type(of: $0)
            {
            case GODOT_VARIANT_TYPE_NIL:
                return Godot.Void.init()
            case GODOT_VARIANT_TYPE_BOOL:
                return Godot.api.core.1.0.godot_variant_as_bool($0)
            case GODOT_VARIANT_TYPE_INT:
                return Godot.api.core.1.0.godot_variant_as_int($0)
            case GODOT_VARIANT_TYPE_REAL:
                return Godot.api.core.1.0.godot_variant_as_real($0)
            
            case GODOT_VARIANT_TYPE_STRING:
                return Godot.String.init(core: 
                    Godot.api.core.1.0.godot_variant_as_string($0))
            case GODOT_VARIANT_TYPE_ARRAY:
                return Godot.List.init(core: 
                    Godot.api.core.1.0.godot_variant_as_array($0))
            case GODOT_VARIANT_TYPE_DICTIONARY:
                return Godot.Map.init(core: 
                    Godot.api.core.1.0.godot_variant_as_dictionary($0))
            
            case GODOT_VARIANT_TYPE_OBJECT:
                guard let delegate:UnsafeMutableRawPointer = 
                    self.withUnsafePointer(Godot.api.core.1.0.godot_variant_as_object)
                else 
                {
                    Godot.print(error: "encountered nil delegate pointer while unwrapping variant")
                    return Godot.Void.init()
                }
                
                Godot.runtime.retain(delegate)
                Godot.runtime.release(delegate)
                //let tag:UnsafeRawPointer = Godot.api.type(of: core)
                //print(tag)
                //Godot.api.core.1.0.godot_object_destroy(core)
                
                Godot.print(error: "variant type 'delegate' is unsupported")
                return Godot.Void.init()
            
            case let code:
                Godot.print(error: "variant type (code: \(code)) is unsupported")
                return Godot.Void.init()
            }
        }
    }
}

extension Godot.String 
{
    convenience
    init(_ string:Swift.String)
    {
        self.init(core: .init())
            Godot.api.core.1.0.godot_string_new(&self.core)
        if  Godot.api.core.1.0.godot_string_parse_utf8(&self.core, string)
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
            string.withUnsafePointer(Godot.api.core.1.0.godot_string_utf8)
        self.init(cString: unsafeBitCast(utf8, to: UnsafePointer<Int8>.self))
        Godot.api.core.1.0.godot_char_string_destroy(&utf8)
    } 
}

extension Godot.VariadicArguments:RandomAccessCollection, MutableCollection
{
    var startIndex:Int 
    {
        self.arguments.startIndex
    }
    var endIndex:Int 
    {
        self.arguments.endIndex
    }
    
    subscript(unmanaged index:Int) -> Godot.Variant.Unmanaged 
    {
        get 
        {
            self.arguments[index].pointee
        }
        set(value)
        {
            self.arguments[index].pointee = value
        }
    } 
    subscript(index:Int) -> Godot.Variant 
    {
        get 
        {
            self[unmanaged: index].take(unretained: Godot.Variant.self) 
        }
        set(value) 
        {
            self[unmanaged: index].assign(retained: value)
        }
    } 
}
extension Godot.List:RandomAccessCollection, MutableCollection
{
    convenience 
    init(capacity:Int = 0) 
    {
        self.init(core: .init())
        Godot.api.core.1.0.godot_array_new(&self.core)
        self.resize(to: capacity)
    }
    
    func resize(to capacity:Int) 
    {
        Godot.api.core.1.0.godot_array_resize(&self.core, .init(capacity))
    }
    
    var startIndex:Int 
    {
        0
    }
    var endIndex:Int 
    {
        .init(self.withUnsafePointer(Godot.api.core.1.0.godot_array_size))
    }
    
    subscript(unmanaged index:Int) -> Godot.Variant.Unmanaged 
    {
        get 
        {
            guard let raw:UnsafeRawPointer = (self.withUnsafePointer 
            {
                Godot.api.core.1.0.godot_array_operator_index_const($0, .init(index))
            }).map(UnsafeRawPointer.init(_:))
            else 
            {
                fatalError("nil pointer to list element (\(index))")
            }
            let pointer:UnsafePointer<Godot.Variant.Unmanaged> = 
                raw.bindMemory(to: Godot.Variant.Unmanaged.self, capacity: 1)
            defer 
            {
                raw.bindMemory(to:           godot_variant.self, capacity: 1)
            }
            return pointer.pointee 
        }
        set(value)
        {
            guard let raw:UnsafeMutableRawPointer = 
                Godot.api.core.1.0.godot_array_operator_index(&self.core, .init(index))
                .map(UnsafeMutableRawPointer.init(_:))
            else 
            {
                fatalError("nil pointer to list element (\(index))")
            } 
            let pointer:UnsafeMutablePointer<Godot.Variant.Unmanaged> = 
                raw.bindMemory(to: Godot.Variant.Unmanaged.self, capacity: 1)
            defer 
            {
                raw.bindMemory(to:           godot_variant.self, capacity: 1)
            }
            pointer.pointee = value 
        } 
        /* _modify
        {
            let raw:UnsafeMutableRawPointer =
            {
                guard let raw:UnsafeMutableRawPointer = 
                    Godot.api.core.1.0.godot_array_operator_index(&self.core, .init(index))
                    .map(UnsafeMutableRawPointer.init(_:))
                else 
                {
                    fatalError("nil pointer to list element (\(index))")
                }
                return raw
            }()
            
            let pointer:UnsafeMutablePointer<Godot.Variant.Unmanaged> = 
                raw.bindMemory(to: Godot.Variant.Unmanaged.self, capacity: 1)
            defer 
            {
                raw.bindMemory(to:           godot_variant.self, capacity: 1)
            }
            
            yield &pointer.pointee
        }  */

    } 
    subscript(index:Int) -> Godot.Variant 
    {
        get 
        {
            self[unmanaged: index].take(unretained: Godot.Variant.self) 
        }
        set(value) 
        {
            // deinitialize the existing value 
            self[unmanaged: index].assign(retained: value)
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
            self[unmanaged: i] = .pass(retained: element)
        }
    }
    
    convenience 
    init(consuming elements:Godot.Variant.Unmanaged...)
    {
        self.init(capacity: elements.count)
        for (i, unmanaged):(Int, Godot.Variant.Unmanaged) in elements.enumerated()
        {
            self[unmanaged: i] = unmanaged 
        }
    }
}
extension Godot.Map
{
    convenience 
    init() 
    {
        self.init(core: .init())
        Godot.api.core.1.0.godot_dictionary_new(&self.core)
    }
    
    subscript(unmanaged key:Godot.Variant) -> Godot.Variant.Unmanaged 
    {
        get 
        {
            guard let raw:UnsafeRawPointer = 
            (Godot.Variant.Unmanaged.pass(key)
            {
                (key:UnsafePointer<godot_variant>) in 
                self.withUnsafePointer 
                {
                    Godot.api.core.1.0.godot_dictionary_operator_index_const($0, key)
                }
            }).map(UnsafeRawPointer.init(_:))
            else 
            {
                fatalError("nil pointer to unordered map element (\(key))")
            }
            let pointer:UnsafePointer<Godot.Variant.Unmanaged> = 
                raw.bindMemory(to: Godot.Variant.Unmanaged.self, capacity: 1)
            defer 
            {
                raw.bindMemory(to:           godot_variant.self, capacity: 1)
            }
            return pointer.pointee 
        }
        set(value)
        {
            guard let raw:UnsafeMutableRawPointer = 
            (Godot.Variant.Unmanaged.pass(key)
            {
                (key:UnsafePointer<godot_variant>) in 
                Godot.api.core.1.0.godot_dictionary_operator_index(&self.core, key)
            }).map(UnsafeMutableRawPointer.init(_:))
            else 
            {
                preconditionFailure("nil pointer to unordered map element (\(key))")
            }
            let pointer:UnsafeMutablePointer<Godot.Variant.Unmanaged> = 
                raw.bindMemory(to: Godot.Variant.Unmanaged.self, capacity: 1)
            defer 
            {
                raw.bindMemory(to:           godot_variant.self, capacity: 1)
            }
            pointer.pointee = value 
        }
    } 
    subscript(key:Godot.Variant) -> Godot.Variant 
    {
        get 
        {
            self[unmanaged: key].take(unretained: Godot.Variant.self) 
        }
        set(value) 
        {
            self[unmanaged: key].assign(retained: value)
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
            self[unmanaged: key] = .pass(retained: value)
        }
    }
}

extension Optional:Godot.VariantRepresentable where Wrapped:Godot.VariantRepresentable 
{
    init?(unretainedValue value:Godot.Variant.Unmanaged) 
    {
        if let wrapped:Wrapped  = value.take(unretained: Wrapped.self) 
        {
            self = .some(wrapped)
        }
        else if let _:Void      = value.take(unretained: Void.self) 
        {
            self = .none 
        }
        else 
        {
            return nil 
        }
    }
    var retainedValue:Godot.Variant.Unmanaged 
    {
        self?.retainedValue ?? .init()
    }
}

extension String:Godot.VariantRepresentable 
{
    init?(unretainedValue value:Godot.Variant.Unmanaged) 
    {
        if let value:Godot.String = value.take(unretained: Godot.String.self) 
        { 
            self.init(value) 
        } 
        else 
        { 
            return nil 
        }
    }
    var retainedValue:Godot.Variant.Unmanaged 
    {
        .pass(retained: Godot.String.init(self))
    }
} 
extension UInt64:Godot.VariantRepresentable 
{
    init?(unretainedValue value:Godot.Variant.Unmanaged) 
    {
        if let value:Self = value(as: UInt64.self) { self = value } else { return nil }
    }
    var retainedValue:Godot.Variant.Unmanaged 
    {
        .init(self)
    }
}
extension UInt32:Godot.VariantRepresentable 
{
    init?(unretainedValue value:Godot.Variant.Unmanaged) 
    {
        guard let value:UInt64 = value(as: UInt64.self) else { return nil }
        self.init(exactly: value)
    }
    var retainedValue:Godot.Variant.Unmanaged 
    {
        .init(UInt64.init(self))
    }
}
extension UInt16:Godot.VariantRepresentable 
{
    init?(unretainedValue value:Godot.Variant.Unmanaged) 
    {
        guard let value:UInt64 = value(as: UInt64.self) else { return nil }
        self.init(exactly: value)
    }
    var retainedValue:Godot.Variant.Unmanaged 
    {
        .init(UInt64.init(self))
    }
}
extension UInt8:Godot.VariantRepresentable 
{
    init?(unretainedValue value:Godot.Variant.Unmanaged) 
    {
        guard let value:UInt64 = value(as: UInt64.self) else { return nil }
        self.init(exactly: value)
    }
    var retainedValue:Godot.Variant.Unmanaged 
    {
        .init(UInt64.init(self))
    }
}

extension Int32:Godot.VariantRepresentable 
{
    init?(unretainedValue value:Godot.Variant.Unmanaged) 
    {
        guard let value:Int64 = value(as: Int64.self) else { return nil }
        self.init(exactly: value)
    }
    var retainedValue:Godot.Variant.Unmanaged 
    {
        .init(Int64.init(self))
    }
}
extension Int16:Godot.VariantRepresentable 
{
    init?(unretainedValue value:Godot.Variant.Unmanaged) 
    {
        guard let value:Int64 = value(as: Int64.self) else { return nil }
        self.init(exactly: value)
    }
    var retainedValue:Godot.Variant.Unmanaged 
    {
        .init(Int64.init(self))
    }
}
extension Int8:Godot.VariantRepresentable 
{
    init?(unretainedValue value:Godot.Variant.Unmanaged) 
    {
        guard let value:Int64 = value(as: Int64.self) else { return nil }
        self.init(exactly: value)
    }
    var retainedValue:Godot.Variant.Unmanaged 
    {
        .init(Int64.init(self))
    }
}

extension Int:Godot.VariantRepresentable 
{
    init?(unretainedValue value:Godot.Variant.Unmanaged) 
    {
        guard let value:Int64 = value(as: Int64.self) else { return nil }
        self.init(exactly: value)
    }
    var retainedValue:Godot.Variant.Unmanaged 
    {
        .init(Int64.init(self))
    }
} 
extension UInt:Godot.VariantRepresentable 
{
    init?(unretainedValue value:Godot.Variant.Unmanaged) 
    {
        guard let value:UInt64 = value(as: UInt64.self) else { return nil }
        self.init(exactly: value)
    }
    var retainedValue:Godot.Variant.Unmanaged 
    {
        .init(UInt64.init(self))
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
    Godot.initialize(gdnative: .init(head: options.pointee.api_struct.pointee))
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
