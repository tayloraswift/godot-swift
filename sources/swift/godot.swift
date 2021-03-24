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
    
    associatedtype Delegate:Godot.AnyDelegate
    
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

public 
enum Godot:_GodotLibrary
{
    public 
    typealias Library               = _GodotLibrary
    public 
    typealias NativeScriptCore      = _GodotNativeScriptCore
    typealias NativeScript          = _GodotNativeScript
    
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

extension Godot 
{
    final 
    class Metatype
    {
    #if ENABLE_ARC_SANITIZER
        
        private 
        let tracker:RetainTracker 
        let symbol:Swift.String
        
        init(symbol:Swift.String, tracker:RetainTracker)
        {
            self.symbol     = symbol
            self.tracker    = tracker
        }
        
        func track() 
        {
            self.tracker.table[self.symbol]?.wrappingIncrement(ordering: .relaxed)
        }
        func untrack() 
        {
            self.tracker.table[self.symbol]?.wrappingDecrement(ordering: .relaxed)
        }
        
    #else 
        
        let symbol:Swift.String
        
        init(symbol:Swift.String)
        {
            self.symbol = symbol
        }
    
    #endif 
    }
}
extension Godot.Metatype 
{
    final 
    class RetainTracker 
    {
        private 
        let type:Godot.NativeScriptCore.Type
        var table:[Swift.String: ManagedAtomic<Int>] 
        
        init(type:Godot.NativeScriptCore.Type, symbols:[Swift.String]) 
        {
            self.type   = type 
            self.table  = .init(uniqueKeysWithValues: symbols.map{ ($0, .init(0)) })
        }
        
        deinit 
        {
            func plural(_ count:Int) -> Swift.String 
            {
                count == 1 ? "\(count) leaked instance" : "\(count) leaked instances"
            }
            
            let leaked:[Swift.String: Int] = self.table.compactMapValues 
            {
                let count:Int = $0.load(ordering: .relaxed)
                return count != 0 ? count : nil
            }
            if !leaked.isEmpty 
            {
                Godot.print(warning: 
                    """
                    detected \(plural(leaked.values.reduce(0, +))) of \(Swift.String.init(reflecting: self.type)):
                    \(leaked.sorted{ $0.key < $1.key }.map
                    { 
                        "    \(plural($0.value)) of '\($0.key)'" 
                    }.joined(separator: "\n"))
                    """)
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
    
    // debug utilities 
    static 
    func dump(_ string:godot_string) 
    {
        withUnsafeBytes(of: string) 
        {
            let storage:UnsafePointer<Int32>    = $0.load(as: UnsafePointer<Int32>.self)
            let count:Int                       = .init(storage[-1])
            let retains:Int32                   =       storage[-2]
            let scalars:[Unicode.Scalar]        = (0 ..< count).map 
            {
                Unicode.Scalar.init(Int.init(storage[$0])) ?? "\u{0}" 
            }
            Swift.print(
                """
                Godot::String (\($0.count) bytes)
                {
                    copy-on-write data (buffer at \(storage)) 
                    {
                        count           : \(count)
                        scalars         : \(scalars) 
                        reference count : \(retains)
                    }
                }
                """
            )
        }
    }
    static 
    func dump(_ array:godot_array) 
    {
        withUnsafeBytes(of: array) 
        {
            let storage:UnsafeRawPointer        = $0.load(as: UnsafeRawPointer.self)
            let retains:UInt32                  = storage.load(as: UInt32.self)
            
            if let cowdata:UnsafePointer<Int32> = storage.load(
                fromByteOffset: 2 * MemoryLayout<UnsafePointer<Int32>?>.stride, 
                as:                              UnsafePointer<Int32>?.self)
            {
                Swift.print(
                    """
                    Godot::Array (\($0.count) bytes)
                    {
                        Godot::Array::ArrayPrivate (buffer at \(storage)) 
                        {
                            reference count : \(retains)
                            
                            copy-on-write data (buffer at \(cowdata)) 
                            {
                                count           : \(cowdata[-1])
                                reference count : \(cowdata[-2])
                            }
                        }
                    }
                    """
                )
            }
            else 
            {
                Swift.print(
                    """
                    Godot::Array (\($0.count) bytes)
                    {
                        Godot::Array::ArrayPrivate (buffer at \(storage)) 
                        {
                            reference count : \(retains)
                            
                            copy-on-write data (nil)
                        }
                    }
                    """
                )
            }
        }
    }
    static 
    func dump(object:UnsafeMutableRawPointer) 
    {
        let id:UInt64 = object.load(fromByteOffset: 8 * 9, as: UInt64.self)
        var stringname:godot_string_name    = object.load(fromByteOffset: 8 * 30, 
            as: godot_string_name.self)
        let classname:Swift.String          = .init(Godot.String.init(retained: 
            Godot.api.core.1.0.godot_string_name_get_name(&stringname)))
        
        let retains:UInt32                  = object.load(fromByteOffset: 8 * 31, as: UInt32.self)
        
        Swift.print(
            """
            Godot::Object (object at \(object))
            {
                object id       : \(id)
                class name      : \(classname)
                reference count : \(retains)
            }
            """
        )
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
    
    @discardableResult
    func retain(_ object:UnsafeMutableRawPointer) -> UnsafeMutableRawPointer
    {
        var status:Bool = false 
        Godot.api.core.1.0.godot_method_bind_ptrcall(
            self.functions.retain, object, nil, &status)
        guard status 
        else 
        {
            fatalError("could not retain object of class '\(self.classname(of: object))' at <\(object)>")
        }
        return object 
    }
    @discardableResult
    func release(_ object:UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? 
    {
        var status:Bool = false 
        Godot.api.core.1.0.godot_method_bind_ptrcall(
            self.functions.release, object, nil, &status)
        return status ? nil : object // nil if we released the last reference
    }
    
    func classname(of delegate:UnsafeMutableRawPointer) -> Swift.String 
    {
        var core:godot_string = .init()
        Godot.api.core.1.0.godot_method_bind_ptrcall(
            self.functions.classname, delegate, nil, &core)
        return Swift.String.init(Godot.String.init(retained: core))
    }
    
    /* func _testsemantics() 
    {
        do 
        {
            // +1
            var s1:godot_string = Godot.api.core.1.0.godot_string_chars_to_utf8("foofoo")
            
            Godot.dump(s1)
            
            // +2
            var v1:godot_variant = .init() 
            Godot.api.core.1.0.godot_variant_new_string(&v1, &s1)
            
            Godot.dump(s1)
            
            // +3
            var s2:godot_string = Godot.api.core.1.0.godot_variant_as_string(&v1)
            
            Godot.dump(s1)
            Godot.dump(s2)
            
            Godot.api.core.1.0.godot_variant_destroy(&v1)
            // +2
            
            Godot.dump(s1)
            
            Godot.api.core.1.0.godot_string_destroy(&s2)
            // +1
            
            Godot.dump(s1)
        }
        
        do 
        {
            // +1 
            var a1:godot_array = .init() 
            Godot.api.core.1.0.godot_array_new(&a1)
            
            Godot.dump(a1)
            
            Godot.api.core.1.0.godot_array_resize(&a1, 5)
            
            Godot.dump(a1)
            
            // +2
            var v1:godot_variant = .init() 
            Godot.api.core.1.0.godot_variant_new_array(&v1, &a1)
            
            Godot.dump(a1)
            
            // +3
            var a2:godot_array = Godot.api.core.1.0.godot_variant_as_array(&v1)
            
            Godot.dump(a1)
            Godot.dump(a2)
            
            Godot.api.core.1.0.godot_variant_destroy(&v1)
            // +2
            
            Godot.dump(a1)
            
            Godot.api.core.1.0.godot_array_destroy(&a2)
            // +1
            
            Godot.dump(a1)
        }
    } */
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
            symbol, T.Delegate.metaclass, initializer, deinitializer)
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
        
        //self.runtime._testsemantics()
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
        init(retained core:godot_string) 
        {
            self.core = core
        }
        
        private 
        init(with initializer:(UnsafeMutablePointer<godot_string>) throws -> ()) rethrows 
        {
            self.core = .init()
            try withExtendedLifetime(self) 
            {
                try initializer(&self.core)
            }
        }
        // needs to be fileprivate so Godot.print(...) can access it
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
        init(retained core:godot_array) 
        {
            self.core = core
        }
        
        private 
        init(with initializer:(UnsafeMutablePointer<godot_array>) throws -> ()) rethrows 
        {
            self.core = .init()
            try withExtendedLifetime(self) 
            {
                try initializer(&self.core)
            }
        }
        private 
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
        init(retained core:godot_dictionary) 
        {
            self.core = core
        }
        
        private 
        init(with initializer:(UnsafeMutablePointer<godot_dictionary>) throws -> ()) rethrows 
        {
            self.core = .init()
            try withExtendedLifetime(self) 
            {
                try initializer(&self.core)
            }
        }
        private 
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

protocol _GodotAnyDelegate:Godot.VariantRepresentable 
{
    static 
    var metaclass:String 
    {
        get
    }
    static 
    var metaclassID:UnsafeMutableRawPointer
    {
        get 
    }
    
    init?(unretained:UnsafeMutableRawPointer) 
    var core:UnsafeMutableRawPointer 
    {
        get 
    }
}
protocol _GodotAnyObject:Godot.AnyDelegate              
{
    // non-failable init assumes instance has been type-checked, and does 
    // not perform any retains!
    init(retained:UnsafeMutableRawPointer) 
}
protocol _GodotAnyResource:Godot.AnyObject          {}
protocol _GodotAnyUnmanaged:Godot.AnyDelegate
{
    // non-failable init assumes instance has been type-checked, and does 
    // not perform any retains!
    init(core:UnsafeMutableRawPointer)
}
protocol _GodotAnyMeshInstance:Godot.AnyUnmanaged   {}

extension Godot 
{
    typealias AnyDelegate       = _GodotAnyDelegate 
    
    typealias AnyObject         = _GodotAnyObject
    typealias AnyUnmanaged      = _GodotAnyUnmanaged
    
    typealias AnyResource       = _GodotAnyResource
    typealias AnyMeshInstance   = _GodotAnyMeshInstance
    
    @propertyWrapper 
    struct Metaclass 
    {
        let wrappedValue:Swift.String 
        
        private(set) lazy 
        var projectedValue:UnsafeMutableRawPointer =
        {
            var name:godot_string_name = .init() 
                Godot.api.core.1.0.godot_string_name_new_data(&name, self.wrappedValue)
            defer 
            {
                Godot.api.core.1.0.godot_string_name_destroy(&name)
            }
            
            guard let id:UnsafeMutableRawPointer = 
                withUnsafePointer(to: name, Godot.api.core.1.2.godot_get_class_tag)
            else 
            {
                fatalError("could not load class metadata for class '\(self.wrappedValue)'")
            }
            return id
        }()
        
        init(wrappedValue:Swift.String) 
        {
            self.wrappedValue = wrappedValue
        }
    }
    
    enum Ancestor 
    {
        typealias Delegate          = Object & Unmanaged.MeshInstance
        typealias Object            = Resource 
        
        typealias Resource          = _GodotAncestorResource
        
        enum Unmanaged 
        {
            typealias MeshInstance  = _GodotAncestorUnmanagedMeshInstance
        }
    }
    
    struct Delegate:AnyDelegate, Ancestor.Delegate
    {
        private 
        enum Existential 
        {
            case unmanaged(core:UnsafeMutableRawPointer)
            case managed(Object)
        }
        
        @Metaclass 
        static 
        var metaclass:Swift.String = "Object"
        static 
        var metaclassID:UnsafeMutableRawPointer { self.$metaclass }
        
        private 
        let existential:Existential
    }
}
extension Godot.Delegate:Godot.Variant
{
    init(unretained core:UnsafeMutableRawPointer) 
    {
        if let object:Godot.Object = .init(unretained: core) 
        {
            self.existential = .managed(object)
        }
        else 
        {
            self.existential = .unmanaged(core: core)
        }
    }
    
    var core:UnsafeMutableRawPointer 
    {
        switch self.existential 
        {
        case .unmanaged(core: let core):    return core 
        case .managed(let object):          return object.core
        }
    }
}

extension Godot.AnyObject 
{
    init?(unretained core:UnsafeMutableRawPointer) 
    {
        // cast_to does not appear to perform its own retain, so no balancing 
        // release is necessary 
        guard let _:UnsafeMutableRawPointer = 
            Godot.api.core.1.2.godot_object_cast_to(core, Self.metaclassID)
        else 
        {
            return nil 
        }
        self.init(retained: Godot.runtime.retain(core))
    }
}
extension Godot.AnyUnmanaged 
{
    init?(unretained core:UnsafeMutableRawPointer) 
    {
        guard let _:UnsafeMutableRawPointer = 
            Godot.api.core.1.2.godot_object_cast_to(core, Self.metaclassID)
        else 
        {
            return nil 
        }
        self.init(core: core)
    }
}

// reference types 
extension Godot 
{
    final 
    class Object:Godot.AnyObject, Ancestor.Object 
    {
        @Metaclass 
        static 
        var metaclass:Swift.String = "Reference"
        static 
        var metaclassID:UnsafeMutableRawPointer { self.$metaclass }
        
        let core:UnsafeMutableRawPointer
        
        init(retained core:UnsafeMutableRawPointer) 
        {
            self.core = core
        }
        deinit 
        {
            Godot.runtime.release(self.core)
        }
    }
    
    final 
    class Resource:Godot.AnyResource, Ancestor.Resource 
    {
        @Metaclass 
        static 
        var metaclass:Swift.String = "Resource"
        static 
        var metaclassID:UnsafeMutableRawPointer { self.$metaclass }
        
        let core:UnsafeMutableRawPointer
        
        init(retained core:UnsafeMutableRawPointer) 
        {
            self.core = core
        }
        deinit 
        {
            Godot.runtime.release(self.core)
        }
    }
}
protocol _GodotAncestorResource {}

// trivial-value types
extension Godot 
{
    enum Unmanaged 
    {
    }
}
extension Godot.Unmanaged 
{
    struct MeshInstance:Godot.AnyMeshInstance, Godot.Ancestor.Unmanaged.MeshInstance
    {
        @Godot.Metaclass 
        static 
        var metaclass:Swift.String = "MeshInstance"
        static 
        var metaclassID:UnsafeMutableRawPointer { self.$metaclass }
        
        let core:UnsafeMutableRawPointer
        
        init(core:UnsafeMutableRawPointer) 
        {
            self.core = core
        }
    }
}
protocol _GodotAncestorUnmanagedMeshInstance {}



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
                fatalError("(swift) received nil argument pointer from gdscript method call")
            }
            
            // can use `!` because we already checked for non-nil pointers
            defer 
            {
                for i:Int in 0 ..< count 
                {
                    UnsafeMutableRawPointer.init(base[i]!).bindMemory(
                        to: godot_variant.self, capacity: 1)
                }
            }
            return try body(.init(arguments: (0 ..< count).map 
                {
                    UnsafeMutableRawPointer.init(base[$0]!).bindMemory(
                        to: Variant.Unmanaged.self, capacity: 1)
                }))
        }
    }
}
extension Godot.NativeScriptInterface
{
    static 
    func initialize(delegate:UnsafeMutableRawPointer?, metatype:UnsafeMutableRawPointer?) 
        -> UnsafeMutableRawPointer? 
    {
        var description:String 
        {
            "initializer (from interface of \(String.init(reflecting: T.self)))"
        }
        
        guard let core:UnsafeMutableRawPointer = delegate 
        else 
        {
            fatalError("(swift) \(description) received nil delegate pointer")
        }
        // allow recovery on mismatched delegate type
        guard let delegate:T.Delegate = .init(unretained: core)
        else 
        {
            Godot.print(error: 
                """
                cannot call \(description) with delegate of class \
                '\(Godot.runtime.classname(of: core))' \
                (expected delegate of class '\(T.Delegate.metaclass)' or one of its subclasses)
                """)
            
            return nil
        } 
        
        #if ENABLE_ARC_SANITIZER
        if let metatype:UnsafeMutableRawPointer = metatype 
        {
            Unmanaged<Godot.Metatype>.fromOpaque(metatype)
                .takeUnretainedValue()
                .track()
        }
        else 
        {
            Godot.print(warning: "\(description) is missing expected type metadata")
        }
        #endif
        
        return Unmanaged<AnyObject>
            .passRetained(T.init(delegate: delegate) as AnyObject).toOpaque() 
    }
    
    static 
    func deinitialize(instance:UnsafeMutableRawPointer?, metatype:UnsafeMutableRawPointer?) 
    {
        var description:String 
        {
            "deinitializer (from interface of \(String.init(reflecting: T.self)))"
        }
        
        guard let instance:UnsafeMutableRawPointer = instance 
        else 
        {
            fatalError("(swift) \(description) received nil instance pointer")
        }
        
        #if ENABLE_ARC_SANITIZER
        if let metatype:UnsafeMutableRawPointer = metatype 
        {
            Unmanaged<Godot.Metatype>.fromOpaque(metatype)
                .takeUnretainedValue()
                .untrack()
        }
        else 
        {
            Godot.print(warning: "\(description) is missing expected type metadata")
        }
        #endif
        
        Unmanaged<AnyObject>.fromOpaque(instance).release()
    }
    
    #if !BUILD_STAGE_INERT
    func call(method index:Int,
        instance:UnsafeMutableRawPointer?, 
        delegate:UnsafeMutableRawPointer?, 
        arguments:
        (
            start:UnsafeMutablePointer<UnsafeMutablePointer<godot_variant>?>?,
            count:Int
        ))
        -> godot_variant 
    {
        var description:String 
        {
            "method '\(self[method: index].symbol)' (from interface of \(String.init(reflecting: T.self)))"
        }
        // everything here is unretained because godot retained `self` and 
        // `delegate` in the initializer call
        
        // load `self`
        guard   let opaque:UnsafeMutableRawPointer  = instance, 
                let instance:T                      = Unmanaged<AnyObject>
                    .fromOpaque(opaque)
                    .takeUnretainedValue() as? T
        else 
        {
            fatalError("(swift) \(description) received nil or invalid instance pointer")
        }
        // load `delegate`
        guard   let unretained:UnsafeMutableRawPointer  = delegate, 
                let delegate:T.Delegate                 = .init(unretained: unretained)
        else 
        {
            fatalError("(swift) \(description) received nil or invalid delegate pointer")
        }
        
        return Godot.VariadicArguments.bind(arguments.start, count: arguments.count)
        {
            self[method: index].witness(instance, delegate, $0).unsafeData
        }
    }
    #endif
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
        guard let core:godot_string = value.load(where: GODOT_VARIANT_TYPE_STRING, 
            Godot.api.core.1.0.godot_variant_as_string)
        else 
        { 
            return nil 
        }
        self.init(retained: core)
    }
    var retainedValue:Godot.Variant.Unmanaged 
    {
        self.withUnsafePointer
        {
            .init(value: $0, Godot.api.core.1.0.godot_variant_new_string)
        }
    }
}
extension Godot.List:Godot.Variant 
{
    convenience
    init?(unretainedValue value:Godot.Variant.Unmanaged) 
    {
        guard let core:godot_array = value.load(where: GODOT_VARIANT_TYPE_ARRAY, 
            Godot.api.core.1.0.godot_variant_as_array)
        else 
        { 
            return nil 
        }
        self.init(retained: core)
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
        guard let core:godot_dictionary = value.load(where: GODOT_VARIANT_TYPE_DICTIONARY, 
            Godot.api.core.1.0.godot_variant_as_dictionary)
        else 
        { 
            return nil 
        }
        self.init(retained: core)
    }
    var retainedValue:Godot.Variant.Unmanaged 
    {
        self.withUnsafePointer
        {
            .init(value: $0, Godot.api.core.1.0.godot_variant_new_dictionary)
        }
    }
}
extension Godot.AnyDelegate 
{
    init?(unretainedValue value:Godot.Variant.Unmanaged) 
    {
        guard let core:UnsafeMutableRawPointer = value.load(where: GODOT_VARIANT_TYPE_OBJECT, 
            Godot.api.core.1.0.godot_variant_as_object) ?? nil
        else 
        {
            return nil 
        }
        // `godot_variant_as_object` passes object unretained
        self.init(unretained: core)
    }
    var retainedValue:Godot.Variant.Unmanaged 
    {
        withExtendedLifetime(self) 
        {
            // `godot_variant_new_object` passes the object retained, unlike 
            // `godot_variant_as_object` for some reason
            .init(value: self.core, Godot.api.core.1.0.godot_variant_new_object)
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
    
    // needed because class convenience initializers cannot replace `self`
    fileprivate 
    func load<T>(where type:godot_variant_type, _ body:(UnsafePointer<godot_variant>) throws -> T) 
        rethrows -> T? 
    {
        try self.withUnsafePointer{ Self.type(of: $0) == type ? try body($0) : nil }
    }
    fileprivate 
    func load(where type:godot_variant_type) -> Void? 
    {
            self.withUnsafePointer( Self.type(of:) )  == type ?     ()       : nil
    }
    fileprivate 
    init<T>(value:T, _ body:(UnsafeMutablePointer<godot_variant>, T) throws -> ()) 
        rethrows
    {
        self.data = .init()
        try body(&self.data, value)
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
    
    func callAsFunction(as _:Void.Type) -> Void? 
    {
        self.load(where: GODOT_VARIANT_TYPE_NIL)
    }
    func callAsFunction(as _:Bool.Type) -> Bool? 
    {
        self.load(where: GODOT_VARIANT_TYPE_BOOL, Godot.api.core.1.0.godot_variant_as_bool)
    }
    func callAsFunction(as _:Int64.Type) -> Int64? 
    {
        self.load(where: GODOT_VARIANT_TYPE_INT, Godot.api.core.1.0.godot_variant_as_int)
    }
    func callAsFunction(as _:UInt64.Type) -> UInt64? 
    {
        self.load(where: GODOT_VARIANT_TYPE_INT, Godot.api.core.1.0.godot_variant_as_uint)
    }
    func callAsFunction(as _:Float64.Type) -> Float64? 
    {
        self.load(where: GODOT_VARIANT_TYPE_REAL, Godot.api.core.1.0.godot_variant_as_real)
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
                return Godot.String.init(retained: 
                    Godot.api.core.1.0.godot_variant_as_string($0))
            case GODOT_VARIANT_TYPE_ARRAY:
                return Godot.List.init(retained: 
                    Godot.api.core.1.0.godot_variant_as_array($0))
            case GODOT_VARIANT_TYPE_DICTIONARY:
                return Godot.Map.init(retained: 
                    Godot.api.core.1.0.godot_variant_as_dictionary($0))
            
            case GODOT_VARIANT_TYPE_OBJECT:
                guard let value:UnsafeMutableRawPointer = 
                    Godot.api.core.1.0.godot_variant_as_object($0)
                else 
                {
                    Godot.print(error: "encountered nil delegate pointer while unwrapping variant")
                    return Godot.Void.init()
                }
                // loading an object pointer from a variant does not seem to 
                // increment its reference count, so we take it unretained
                return Godot.Delegate.init(unretained: value)
            
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
        self.init(retained: Godot.api.core.1.0.godot_string_chars_to_utf8(string))
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
        self.init(with: Godot.api.core.1.0.godot_array_new)
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
        self.init(with: Godot.api.core.1.0.godot_dictionary_new)
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
