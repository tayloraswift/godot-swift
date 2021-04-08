import GDNative

@_cdecl("godot_gdnative_init")
public 
func godot_gdnative_init(options:UnsafePointer<godot_gdnative_init_options>)
{
    Godot.initialize(api: options.pointee.api_struct.pointee)
}

@_cdecl("godot_nativescript_init")
public 
func godot_nativescript_init(handle:UnsafeMutableRawPointer) 
{
    Godot.Library.wrap(handle: handle).initialize()
}
@_cdecl("godot_nativescript_terminate")
public 
func godot_nativescript_terminate(handle:UnsafeMutableRawPointer) 
{
    Godot.Library.wrap(handle: handle).deinitialize()
}

@_cdecl("godot_gdnative_terminate")
public 
func godot_gdnative_terminate(options _:UnsafePointer<godot_gdnative_terminate_options>)
{
    Godot.deinitialize()
}

public 
enum Godot
{
    fileprivate private(set) static 
    var api:
    (
        Swift.Void,
        (
            godot_gdnative_core_api_struct, 
            godot_gdnative_core_1_1_api_struct, 
            godot_gdnative_core_1_2_api_struct
        ),
        nativescript:
        (
            swift:Int32, // language index
            (
                godot_gdnative_ext_nativescript_api_struct, 
                godot_gdnative_ext_nativescript_1_1_api_struct
            )
        )
    )
    = 
    (
        (), (.init(), .init(), .init()), (-1, (.init(), .init()))
    )
    
    private static 
    func version(from head:godot_gdnative_api_struct) -> (major:Int, minor:Int)
    {
        // find the highest api version available 
        var version:godot_gdnative_api_version = head.version
        var next:UnsafePointer<godot_gdnative_api_struct>? = head.next 
        while let current:UnsafePointer<godot_gdnative_api_struct> = next 
        {
            version = current.pointee.version
            next    = current.pointee.next
        }
        return (.init(version.major), .init(version.minor))
    }
    
    private static 
    func loadCoreAPI(head:godot_gdnative_core_api_struct) 
        -> 
        (
            godot_gdnative_core_api_struct, 
            godot_gdnative_core_1_1_api_struct, 
            godot_gdnative_core_1_2_api_struct
        )
    {
        guard   let v1_1:UnsafePointer<godot_gdnative_api_struct> = head.next, 
                let v1_2:UnsafePointer<godot_gdnative_api_struct> = v1_1.pointee.next 
        else 
        {
            let (major, minor):(Int, Int) = withUnsafeBytes(of: head)
            {
                Self.version(from: $0.load(as: godot_gdnative_api_struct.self))
            }
            fatalError("godot-swift requires gdnative version 1.2 or higher (have version \(major).\(minor))")
        }
        
        return 
            (
            head,
            UnsafeRawPointer.init(v1_1).load(as: godot_gdnative_core_1_1_api_struct.self),
            UnsafeRawPointer.init(v1_2).load(as: godot_gdnative_core_1_2_api_struct.self)
            )
    }
    
    private static 
    func loadNativeScriptAPI(head:UnsafePointer<godot_gdnative_api_struct>) 
        -> 
        (
            godot_gdnative_ext_nativescript_api_struct, 
            godot_gdnative_ext_nativescript_1_1_api_struct 
        )
    {
        guard   let v1_1:UnsafePointer<godot_gdnative_api_struct> = head.pointee.next 
        else 
        {
            let (major, minor):(Int, Int) = Self.version(from: head.pointee)
            fatalError("godot-swift requires gdnative nativescript version 1.1 or higher (have version \(major).\(minor))")
        }
        
        return 
            (
            UnsafeRawPointer.init(head).load(as: godot_gdnative_ext_nativescript_api_struct.self),
            UnsafeRawPointer.init(v1_1).load(as: godot_gdnative_ext_nativescript_1_1_api_struct.self)
            )
    }
    
    fileprivate static 
    func initialize(api head:godot_gdnative_core_api_struct) 
    {
        // gather extensions 
        var extensions:
        (
            nativescript:UnsafePointer<godot_gdnative_api_struct>?, 
            Swift.Void
        ) 
        = 
        (nil, ())
        for i:Int in 0 ..< Int.init(head.num_extensions)
        {
            switch (head.extensions[i]?.pointee.type).map(GDNATIVE_API_TYPES.init(rawValue:))
            {
            case GDNATIVE_EXT_NATIVESCRIPT?:
                extensions.nativescript = head.extensions[i]
            default:
                break
            }
        }
        
        guard let nativescript:UnsafePointer<godot_gdnative_api_struct> = extensions.nativescript 
        else 
        {
            fatalError("could not find gdnative nativescript extension")
        }
        
        Self.api.1              = Self.loadCoreAPI        (head: head)
        Self.api.nativescript.1 = Self.loadNativeScriptAPI(head: nativescript)
        
        // instance binding 
        let bridge:godot_instance_binding_functions = .init(
            alloc_instance_binding_data: 
            {
                // do not allocate anything, just store the metatype pointer 
                (
                    _:UnsafeMutableRawPointer?, // `nil`, ... from `data`?
                    metatype:UnsafeRawPointer?, 
                    _:UnsafeMutableRawPointer? // object, not used here
                ) -> UnsafeMutableRawPointer? 
                in
                // cast away the const, but this is okay because we are just 
                // using the metatype pointer to encode an integer index
                .init(mutating: metatype)
            },
            free_instance_binding_data: 
            {
                (
                    _:UnsafeMutableRawPointer?, // `nil`, ... from `data`?
                    _:UnsafeMutableRawPointer? // metatype
                )
                in
                // do nothing 
            }, 
            refcount_incremented_instance_binding:  nil,
            refcount_decremented_instance_binding:  nil,
            data:                                   nil, 
            free_func:                              nil) 
        
        Self.api.nativescript.swift = Self.api.nativescript.1.1
            .godot_nativescript_register_instance_binding_data_functions(bridge)
        
        for (i, metatype):(Int, AnyDelegate.Type) in Self.DelegateTypes.enumerated()
        {
            Self.api.nativescript.1.1.godot_nativescript_set_global_type_tag(
                Self.api.nativescript.swift, 
                metatype.symbol, 
                UnsafeRawPointer.init(bitPattern: i)) 
        }
    }
    
    fileprivate static 
    func deinitialize() 
    {
        // must happen before clearing nativescript api, for obvious reasons
        Self.api.nativescript.1.1
            .godot_nativescript_unregister_instance_binding_data_functions(Self.api.nativescript.swift)
        Self.api.nativescript.1.1   = .init()
        Self.api.nativescript.1.0   = .init()
        
        Self.api.1.2                = .init()
        Self.api.1.1                = .init()
        Self.api.1.0                = .init()
        Self.api.nativescript.swift = -1
    }
    
    // global functions 
    static 
    func type(of core:UnsafeMutableRawPointer) -> Godot.AnyDelegate.Type 
    {
        let index:Int = .init(bitPattern: Self.api.nativescript.1.1
            .godot_nativescript_get_instance_binding_data(Self.api.nativescript.swift, core))
        return Self.DelegateTypes[index]
    }
    
    static 
    func print(_ items:Any..., separator:Swift.String = " ", terminator:Swift.String = "") 
    {
        Godot.String.init("(swift) \(items.map{"\($0)"}.joined(separator: separator))\(terminator)")
            .withUnsafePointer(Self.api.1.0.godot_print)
    }
    static 
    func print(warning:Swift.String, function:Swift.String = #function, file:Swift.String = #file, line:Int32 = #line) 
    {
        Self.api.1.0.godot_print_warning("(swift) \(warning)", function, file, line)
    }
    static 
    func print(error:Swift.String, function:Swift.String = #function, file:Swift.String = #file, line:Int32 = #line) 
    {
        Self.api.1.0.godot_print_error("(swift) \(error)", function, file, line)
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
            Self.api.1.0.godot_string_name_get_name(&stringname)))
        
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

// public because we need to inspect them externally in the inert build stage
protocol _GodotNativeLibrary 
{
    static 
    var interface:Godot.Library.Interface 
    {
        get
    }
}

protocol _GodotAnyNativeScript
{
#if BUILD_STAGE_INERT
    static 
    var __signatures__:[String]
    {
        get 
    }
#else 
    static 
    func register(_ symbols:[String], with:Godot.Library)
#endif 
}

protocol _GodotNativeScript:Godot.AnyNativeScript
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
}
extension Godot 
{
    typealias AnyNativeScript   = _GodotAnyNativeScript
    typealias NativeScript      = _GodotNativeScript
    
    typealias NativeLibrary     = _GodotNativeLibrary 
    
    struct Library:NativeLibrary 
    {
        private 
        let handle:UnsafeMutableRawPointer 
        
        fileprivate static
        func wrap(handle:UnsafeMutableRawPointer) -> Self
        {
            .init(handle: handle)
        }
    }
}
extension Godot.Library 
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
    typealias Dispatcher = @convention(c) 
        (
            UnsafeMutableRawPointer?, 
            UnsafeMutableRawPointer?, 
            UnsafeMutableRawPointer?, 
            Int32, 
            UnsafeMutablePointer<UnsafeMutablePointer<godot_variant>?>?
        ) -> godot_variant
    
    @resultBuilder 
    struct Interface 
    {
        typealias Binding = (type:Godot.AnyNativeScript.Type, symbol:Swift.String)
        
        let types:[(type:Godot.AnyNativeScript.Type, symbols:[Swift.String])]
    }
    
    fileprivate 
    func initialize() 
    {
        for (type, symbols):(Godot.AnyNativeScript.Type, [Swift.String]) in Self.interface.types 
        {
        #if !BUILD_STAGE_INERT
            type.register(symbols, with: self)
        #endif
        }
        
        // assert unsafebitcast memory layouts 
        MemoryLayout<godot_vector2>.assert()
        MemoryLayout<godot_vector3>.assert()
        
        MemoryLayout<godot_rect2>.assert()
        MemoryLayout<godot_aabb>.assert()
        
        MemoryLayout<godot_transform2d>.assert()
        MemoryLayout<godot_transform>.assert()
        MemoryLayout<godot_basis>.assert() 
    }
    fileprivate 
    func deinitialize() 
    {
    }
    
    func register<T>(
        initializer:godot_instance_create_func, 
        deinitializer:godot_instance_destroy_func, 
        for _:T.Type, as symbol:String) 
        where T:Godot.NativeScript
    {
        Godot.print("registering \(T.self) as '\(symbol)'")
        
        Godot.api.nativescript.1.0.godot_nativescript_register_class(self.handle, 
            symbol, T.Delegate.symbol, initializer, deinitializer)
    }
    
    func register(method:godot_instance_method, as symbol:(type:String, method:String)) 
    {
        Godot.print("registering (function) as '\(symbol.type).\(symbol.method)'")
        
        let mode:godot_method_attributes = 
            .init(rpc_type: GODOT_METHOD_RPC_MODE_DISABLED)
        Godot.api.nativescript.1.0.godot_nativescript_register_method(self.handle, 
            symbol.type, symbol.method, mode, method)
    }
}
extension Godot 
{
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

// arc sanitizer 
extension Godot 
{
    final 
    class NativeScriptMetadata
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
#if ENABLE_ARC_SANITIZER
extension Godot 
{
    final 
    class RetainTracker 
    {
        private 
        let type:Godot.AnyNativeScript.Type
        var table:[Swift.String: ManagedAtomic<Int>] 
        
        init(type:Godot.AnyNativeScript.Type, symbols:[Swift.String]) 
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
#endif 

/* func _testsemantics() 
{
    do 
    {
        // +1
        var s1:godot_string = Godot.api.1.0.godot_string_chars_to_utf8("foofoo")
        
        Godot.dump(s1)
        
        // +2
        var v1:godot_variant = .init() 
        Godot.api.1.0.godot_variant_new_string(&v1, &s1)
        
        Godot.dump(s1)
        
        // +3
        var s2:godot_string = Godot.api.1.0.godot_variant_as_string(&v1)
        
        Godot.dump(s1)
        Godot.dump(s2)
        
        Godot.api.1.0.godot_variant_destroy(&v1)
        // +2
        
        Godot.dump(s1)
        
        Godot.api.1.0.godot_string_destroy(&s2)
        // +1
        
        Godot.dump(s1)
    }
    
    do 
    {
        // +1 
        var a1:godot_array = .init() 
        Godot.api.1.0.godot_array_new(&a1)
        
        Godot.dump(a1)
        
        Godot.api.1.0.godot_array_resize(&a1, 5)
        
        Godot.dump(a1)
        
        // +2
        var v1:godot_variant = .init() 
        Godot.api.1.0.godot_variant_new_array(&v1, &a1)
        
        Godot.dump(a1)
        
        // +3
        var a2:godot_array = Godot.api.1.0.godot_variant_as_array(&v1)
        
        Godot.dump(a1)
        Godot.dump(a2)
        
        Godot.api.1.0.godot_variant_destroy(&v1)
        // +2
        
        Godot.dump(a1)
        
        Godot.api.1.0.godot_array_destroy(&a2)
        // +1
        
        Godot.dump(a1)
    }
} */

// user-facing DSL
infix operator <- : AssignmentPrecedence

func <- <T>(type:T.Type, symbol:String) -> Godot.Library.Interface.Binding
    where T:Godot.AnyNativeScript
{
    (T.self, symbol)
}

extension Godot.Library.Interface 
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

// functionality factored from generated bindings
extension Godot.NativeScriptInterface
{
    static 
    func initialize(delegate:UnsafeMutableRawPointer?, metadata:UnsafeMutableRawPointer?) 
        -> UnsafeMutableRawPointer? 
    {
        var description:String 
        {
            "initializer from interface of type '\(String.init(reflecting: T.self))'"
        }
        
        guard let core:UnsafeMutableRawPointer = delegate 
        else 
        {
            fatalError("(swift) \(description) received nil delegate pointer")
        }
        // allow recovery on mismatched delegate type
        let metatype:Godot.AnyDelegate.Type = Godot.type(of: core)
        guard let delegate:T.Delegate = metatype.init(unretained: core) as? T.Delegate
        else 
        {
            Godot.print(error: 
                """
                cannot call \(description) with delegate of type '\(String.init(reflecting: metatype))' \ 
                (aka 'Godot::\(metatype.symbol)'), expected delegate of type \
                '\(String.init(reflecting: T.Delegate.self))' (aka 'Godot::\(T.Delegate.symbol)') \ 
                or one of its subclasses
                """)
            
            return nil
        } 
        
        #if ENABLE_ARC_SANITIZER
        if let metadata:UnsafeMutableRawPointer = metadata 
        {
            Unmanaged<Godot.NativeScriptMetadata>.fromOpaque(metadata)
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
    func deinitialize(instance:UnsafeMutableRawPointer?, metadata:UnsafeMutableRawPointer?) 
    {
        var description:String 
        {
            "deinitializer from interface of type '\(String.init(reflecting: T.self))'"
        }
        
        guard let instance:UnsafeMutableRawPointer = instance 
        else 
        {
            fatalError("(swift) \(description) received nil instance pointer")
        }
        
        #if ENABLE_ARC_SANITIZER
        if let metadata:UnsafeMutableRawPointer = metadata 
        {
            Unmanaged<Godot.NativeScriptMetadata>.fromOpaque(metadata)
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
            """
            method '\(self[method: index].symbol)' \ 
            from interface of type '\(String.init(reflecting: T.self))'
            """
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
        guard   let core:UnsafeMutableRawPointer    = delegate, 
                let delegate:T.Delegate             = Godot.type(of: core)
                    .init(unretained: core) as? T.Delegate
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
extension Godot 
{
    struct VariadicArguments
    {
        private 
        let arguments:UnsafeMutableBufferPointer<UnsafeMutablePointer<Variant.Unmanaged>>
        
        typealias RawArgument       = UnsafeMutablePointer<godot_variant>
        typealias RawArgumentVector = UnsafeMutablePointer<RawArgument?>
        
        static 
        func bind<R>(_ start:RawArgumentVector?, count:Int, 
            body:(Self) throws -> R) 
            rethrows -> R
        {
            if count > 0 
            {
                // assert arguments pointers are non-nil 
                guard let base:RawArgumentVector = start
                else 
                {
                    fatalError("(swift) received nil argument-vector pointer from gdscript method call")
                }
                for i:Int in 0 ..< count where base[i] == nil 
                {
                    fatalError("(swift) recieved nil argument pointer from gdscript method call at position \(i)")
                }
            }
            
            let buffer:UnsafeMutableBufferPointer<RawArgument?> = 
                .init(start: start, count: count)
            
            return try buffer.withMemoryRebound(
                to: UnsafeMutablePointer<Variant.Unmanaged>.self) 
            {
                try body(.init(arguments: $0))
            }
        }
    }
}

// variant-related functionality
protocol _GodotVariantRepresentable 
{
    // this needs to be a static function, to handle covariant `Self`. 
    // it’s better to not call these methods directly, the preferred form is the  
    // generic methods on `Godot.Variant.Unmanaged`.
    static 
    func takeUnretained(_:Godot.Variant.Unmanaged) -> Self?
    func passRetained() -> Godot.Variant.Unmanaged 
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
    
    enum Transform2 
    {
        struct Affine  
        {
            let matrix:Vector2<Float>.Matrix3
        }
    }
    enum Transform3 
    {
        struct Linear 
        {
            let matrix:Vector3<Float>.Matrix 
        }
        struct Affine  
        {
            let matrix:Vector3<Float>.Matrix4
        }
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
            Godot.api.1.0.godot_string_destroy(&self.core)
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
            Godot.api.1.0.godot_array_destroy(&self.core)
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
            Godot.api.1.0.godot_dictionary_destroy(&self.core)
        }
    }
}

extension Godot 
{    
    /* mutating 
    func load() 
    {
        self.retain     = .load(method: "reference",   in: Godot.AnyObject.self)
        self.release    = .load(method: "unreference", in: Godot.AnyObject.self)
        self.classname  = .load(method: "get_class",   in: Godot.AnyDelegate.self)
    }
    
    private mutating 
    func load(_ symbol:(class:String, method:String), as path:WritableKeyPath<Functions, BoundMethod?>) 
    {
        if let function:Function = 
            Godot.api.1.0.godot_method_bind_get_method(symbol.class, symbol.method)
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
        //let status:Bool = self.retain(self: object)
        var status:Bool = false 
        Godot.api.1.0.godot_method_bind_ptrcall(
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
        Godot.api.1.0.godot_method_bind_ptrcall(
            self.functions.release, object, nil, &status)
        return status ? nil : object // nil if we released the last reference
    }
    
    func classname(of delegate:UnsafeMutableRawPointer) -> Swift.String 
    {
        var core:godot_string = .init()
        Godot.api.1.0.godot_method_bind_ptrcall(
            self.functions.classname, delegate, nil, &core)
        return Swift.String.init(Godot.String.init(retained: core))
    } */
    class AnyDelegate
    {
        class 
        var symbol:Swift.String { "Object" }
        final 
        let core:UnsafeMutableRawPointer 
        // non-failable init assumes instance has been type-checked!
        required
        init(unretained core:UnsafeMutableRawPointer) 
        {
            self.core = core
            //Swift.print("--- bridged object of type \(self._classname())")
        }
        
        // static variables are lazy, which is good because we need to wait for 
        // the library to be loaded before we can bind methods. also reduces startup overhead
        private static 
        var classname:BoundMethod = .bind(method: "get_class", from: AnyDelegate.self)
        
        final
        func classname() -> Swift.String 
        {
            AnyDelegate.classname(self: self)
        }
    }
    class AnyObject:AnyDelegate              
    {
        override class 
        var symbol:Swift.String { "Reference" }
        
        required 
        init(unretained core:UnsafeMutableRawPointer) 
        {
            super.init(unretained: core)
            guard self.retain()
            else 
            {
                fatalError(
                    """
                    could not retain delegate of type \
                    '\(Swift.String.init(reflecting: Self.self))' at <\(self.core)>
                    """)
            }
        }
        deinit
        { 
            self.release()
        }
        
        private static 
        var retain:BoundMethod  = .bind(method: "reference",   from: AnyObject.self), 
            release:BoundMethod = .bind(method: "unreference", from: AnyObject.self)
        
        @discardableResult
        final
        func retain() -> Bool 
        {
            Self.retain(self: self) 
        }
        @discardableResult
        final
        func release() -> Bool 
        {
            Self.release(self: self) 
        }
    }
}

// basic variants 
extension Godot.Void:Godot.Variant 
{
    static 
    func takeUnretained(_ value:Godot.Variant.Unmanaged) -> Self?
    {
        value.load(where: GODOT_VARIANT_TYPE_NIL){ _ in Self.init() }
    }
    func passRetained() -> Godot.Variant.Unmanaged 
    {
        .init(Godot.api.1.0.godot_variant_new_nil)
    }
} 
extension Bool:Godot.Variant 
{
    static 
    func takeUnretained(_ value:Godot.Variant.Unmanaged) -> Self?
    {
        value.load(where: GODOT_VARIANT_TYPE_BOOL, Godot.api.1.0.godot_variant_as_bool)
    }
    func passRetained() -> Godot.Variant.Unmanaged 
    {
        .init(value: self, Godot.api.1.0.godot_variant_new_bool)
    }
}
extension FixedWidthInteger where Self:SignedInteger 
{
    static 
    func takeUnretained(_ value:Godot.Variant.Unmanaged) -> Self?
    {
        value.load(where: GODOT_VARIANT_TYPE_INT, Godot.api.1.0.godot_variant_as_int)
            .map(Self.init(exactly:)) ?? nil
    }
    func passRetained() -> Godot.Variant.Unmanaged 
    {
        .init(value: .init(self), Godot.api.1.0.godot_variant_new_int)
    }
}
extension FixedWidthInteger where Self:UnsignedInteger 
{
    static 
    func takeUnretained(_ value:Godot.Variant.Unmanaged) -> Self?
    {
        value.load(where: GODOT_VARIANT_TYPE_INT, Godot.api.1.0.godot_variant_as_uint)
            .map(Self.init(exactly:)) ?? nil
    }
    func passRetained() -> Godot.Variant.Unmanaged 
    {
        .init(value: .init(self), Godot.api.1.0.godot_variant_new_uint)
    }
}
extension BinaryFloatingPoint 
{
    static 
    func takeUnretained(_ value:Godot.Variant.Unmanaged) -> Self?
    {
        value.load(where: GODOT_VARIANT_TYPE_REAL, Godot.api.1.0.godot_variant_as_real)
            .map(Self.init(_:))
    }
    func passRetained() -> Godot.Variant.Unmanaged 
    {
        .init(value: .init(self), Godot.api.1.0.godot_variant_new_real)
    }
}

extension Int64:Godot.Variant               {}
extension Float64:Godot.Variant             {}

extension Float32:Godot.VariantRepresentable{}
extension Float16:Godot.VariantRepresentable{}

extension Int32:Godot.VariantRepresentable  {}
extension Int16:Godot.VariantRepresentable  {}
extension Int8:Godot.VariantRepresentable   {}
extension Int:Godot.VariantRepresentable    {}

extension UInt64:Godot.VariantRepresentable {}
extension UInt32:Godot.VariantRepresentable {}
extension UInt16:Godot.VariantRepresentable {}
extension UInt8:Godot.VariantRepresentable  {}
extension UInt:Godot.VariantRepresentable   {}

fileprivate 
protocol _GodotRawAggregate 
{
    associatedtype Unpacked 
    associatedtype Packed
    
    init(packing:Unpacked)
    var unpacked:Unpacked 
    {
        get 
    }
    // used for runtime sanity checks
    static 
    func trace() -> Bool
}
extension Godot 
{
    fileprivate 
    typealias RawAggregate = _GodotRawAggregate
}
extension godot_vector2:Godot.RawAggregate 
{
    fileprivate 
    typealias Packed = (Float32, Float32)
    
    fileprivate
    init(packing vector:Vector2<Float32>)
    {
        self = unsafeBitCast(vector*, to: Self.self)
    }
    fileprivate
    var unpacked:Vector2<Float32> 
    {
        unsafeBitCast(self, to: Packed.self)*
    }
    
    fileprivate static 
    func trace() -> Bool 
    {
        let tracer:Vector2<Float32> = (1, 2)*
        
        var data:Self = .init()
        Godot.api.1.0.godot_vector2_new(&data, tracer.x, tracer.y)
        
        return data.unpacked == tracer
    }
}
extension godot_vector3:Godot.RawAggregate 
{
    fileprivate
    typealias Packed = (Float32, Float32, Float32)
    
    fileprivate
    init(packing vector:Vector3<Float32>)
    {
        self = unsafeBitCast(vector*, to: Self.self)
    }
    fileprivate
    var unpacked:Vector3<Float32> 
    {
        unsafeBitCast(self, to: Packed.self)*
    }
    
    fileprivate static 
    func trace() -> Bool 
    {
        let tracer:Vector3<Float32> = (1, 2, 3)*
        
        var data:Self = .init()
        Godot.api.1.0.godot_vector3_new(&data, tracer.x, tracer.y, tracer.z)
        
        return data.unpacked == tracer
    }
}
extension godot_rect2:Godot.RawAggregate 
{
    fileprivate
    typealias Packed = ((Float32, Float32), (Float32, Float32))
    
    fileprivate 
    init(packing bounds:Vector2<Float32>.Matrix2)
    {
        let position:Vector2<Float32>   =            bounds.0
        let size:Vector2<Float32>       = bounds.1 - bounds.0
        self = unsafeBitCast((position*, size*), to: Self.self)
    }
    fileprivate 
    var unpacked:Vector2<Float32>.Matrix2
    {
        let packed:Packed               = unsafeBitCast(self, to: Packed.self)
        let position:Vector2<Float32>   = packed.0*
        let size:Vector2<Float32>       = packed.1*
        return (position, position + size)
    }
    
    fileprivate static 
    func trace() -> Bool 
    {
        let tracer:Vector2<Float32>.Matrix2 = ((1, 2)*, (4, 6)*)
        
        let start:godot_vector2 = .init(packing:            tracer.0)
        let size:godot_vector2  = .init(packing: tracer.1 - tracer.0)
        var data:Self           = .init()
        withUnsafePointer(to: start)
        {
            (start:UnsafePointer<godot_vector2>) in 
            withUnsafePointer(to: size)
            {
                (size:UnsafePointer<godot_vector2>) in  
                Godot.api.1.0.godot_rect2_new_with_position_and_size(&data, start, size)
            }
        }
        
        return data.unpacked == tracer 
    }
}
extension godot_aabb:Godot.RawAggregate 
{
    fileprivate
    typealias Packed = ((Float32, Float32, Float32), (Float32, Float32, Float32))
    
    fileprivate 
    init(packing bounds:Vector3<Float32>.Matrix2)
    {
        let position:Vector3<Float32>   =            bounds.0
        let size:Vector3<Float32>       = bounds.1 - bounds.0
        self = unsafeBitCast((position*, size*), to: Self.self)
    }
    fileprivate 
    var unpacked:Vector3<Float32>.Matrix2
    {
        let packed:Packed               = unsafeBitCast(self, to: Packed.self)
        let position:Vector3<Float32>   = packed.0*
        let size:Vector3<Float32>       = packed.1*
        return (position, position + size)
    }
    
    fileprivate static 
    func trace() -> Bool 
    {
        let tracer:Vector3<Float32>.Matrix2 = ((1, 2, 3)*, (5, 7, 9)*)
        
        let start:godot_vector3 = .init(packing:            tracer.0)
        let size:godot_vector3  = .init(packing: tracer.1 - tracer.0)
        var data:Self           = .init()
        withUnsafePointer(to: start)
        {
            (start:UnsafePointer<godot_vector3>) in 
            withUnsafePointer(to: size)
            {
                (size:UnsafePointer<godot_vector3>) in  
                Godot.api.1.0.godot_aabb_new(&data, start, size)
            }
        }
        
        return data.unpacked == tracer 
    }
}
extension godot_transform2d:Godot.RawAggregate 
{
    // godot does not provide an interface for accessing the basis vectors, 
    // so we have to (unsafely) extract them from raw memory 
    fileprivate
    typealias Packed = ((Float32, Float32), (Float32, Float32), (Float32, Float32))
    
    fileprivate 
    init(packing matrix:Vector2<Float32>.Matrix3)
    {
        self = unsafeBitCast((matrix.0*, matrix.1*, matrix.2*), to: Self.self)
    }
    fileprivate 
    var unpacked:Vector2<Float32>.Matrix3
    {
        let packed:Packed = unsafeBitCast(self, to: Packed.self)
        return (packed.0*, packed.1*, packed.2*)
    }

    fileprivate static 
    func trace() -> Bool 
    {
        let tracer:Vector2<Float32>.Matrix3 = ((1, 2)*, (3, 4)*, (5, 6)*)
        
        var data:godot_transform2d          = .init()
        withUnsafePointer(to: godot_vector2.init(packing: tracer.0))
        {
            (a:UnsafePointer<godot_vector2>) in 
            withUnsafePointer(to: godot_vector2.init(packing: tracer.1))
            {
                (b:UnsafePointer<godot_vector2>) in 
                withUnsafePointer(to: godot_vector2.init(packing: tracer.2))
                {
                    (c:UnsafePointer<godot_vector2>) in 
                    Godot.api.1.0.godot_transform2d_new_axis_origin(&data, a, b, c)
                }
            }
        }
        
        return data.unpacked == tracer 
    }
}
extension godot_transform:Godot.RawAggregate 
{
    // godot does not provide an interface for accessing the basis vectors, 
    // so we have to (unsafely) extract them from raw memory. we cannot cast 
    // directly to Vector3.Matrix, because Vector3 is padded to the size of a 
    // Vector4 instance.
    fileprivate
    typealias Packed = 
    (
        basis:
        (
            (Float32, Float32, Float32), 
            (Float32, Float32, Float32), 
            (Float32, Float32, Float32)
        ),
        origin:
        (Float32, Float32, Float32)
    )
    
    fileprivate 
    init(packing matrix:Vector3<Float32>.Matrix4)
    {
        let rows:Vector3<Float32>.Matrix = (matrix.0, matrix.1, matrix.2)*
        self = unsafeBitCast(((rows.0*, rows.1*, rows.2*), matrix.3*), to: Self.self)
    }
    fileprivate 
    var unpacked:Vector3<Float32>.Matrix4
    {
        let packed:Packed                     =  unsafeBitCast(self, to: Packed.self)
        let columns:Vector3<Float32>.Matrix   = (packed.basis.0*, packed.basis.1*, packed.basis.2*)*
        return (columns.0, columns.1, columns.2, packed.origin*)
    }

    fileprivate static 
    func trace() -> Bool 
    {
        let tracer:Vector3<Float32>.Matrix4 = ((1, 2, 3)*, (4, 5, 6)*, (7, 8, 9)*, (10, 11, 12)*)
        // no transposition, as `godot_transform_new_with_axis_origin` takes all-columns
        var data:godot_transform            = .init()
        withUnsafePointer(to: godot_vector3.init(packing: tracer.0))
        {
            (a:UnsafePointer<godot_vector3>) in 
            withUnsafePointer(to: godot_vector3.init(packing: tracer.1))
            {
                (b:UnsafePointer<godot_vector3>) in 
                withUnsafePointer(to: godot_vector3.init(packing: tracer.2))
                {
                    (c:UnsafePointer<godot_vector3>) in 
                    withUnsafePointer(to: godot_vector3.init(packing: tracer.3))
                    {
                        (d:UnsafePointer<godot_vector3>) in 
                        Godot.api.1.0.godot_transform_new_with_axis_origin(&data, a, b, c, d)
                    }
                }
            }
        }
        
        return data.unpacked == tracer 
    }
}
extension godot_basis:Godot.RawAggregate 
{
    // note: Godot::basis is stored row-major, not column-major
    fileprivate
    typealias Packed = 
    (
        (Float32, Float32, Float32), 
        (Float32, Float32, Float32), 
        (Float32, Float32, Float32)
    )
    
    fileprivate 
    init(packing matrix:Vector3<Float32>.Matrix)
    {
        let rows:Vector3<Float32>.Matrix = matrix*
        self = unsafeBitCast((rows.0*, rows.1*, rows.2*), to: Self.self)
    }
    fileprivate 
    var unpacked:Vector3<Float32>.Matrix
    {
        let packed:Packed = unsafeBitCast(self, to: Packed.self)
        return (packed.0*, packed.1*, packed.2*)*
    }

    fileprivate static 
    func trace() -> Bool 
    {
        let tracer:Vector3<Float32>.Matrix  = ((1, 2, 3)*, (4, 5, 6)*, (7, 8, 9)*)
        
        let rows:Vector3<Float32>.Matrix    = tracer*
        var data:godot_basis                = .init()
        withUnsafePointer(to: godot_vector3.init(packing: rows.0))
        {
            (a:UnsafePointer<godot_vector3>) in 
            withUnsafePointer(to: godot_vector3.init(packing: rows.1))
            {
                (b:UnsafePointer<godot_vector3>) in 
                withUnsafePointer(to: godot_vector3.init(packing: rows.2))
                {
                    (c:UnsafePointer<godot_vector3>) in 
                    Godot.api.1.0.godot_basis_new_with_rows(&data, a, b, c)
                }
            }
        }
        
        return data.unpacked == tracer 
    }
}
extension MemoryLayout where T:Godot.RawAggregate
{
    fileprivate static 
    func assert()
    {
        guard Self.size == MemoryLayout<T.Packed>.size
        else 
        {
            fatalError("memory layout of `Godot::\(T.self)` has size \(Self.size) B (expected \(MemoryLayout<T.Packed>.size) B). check godot version compatibility!")
        }
        
        guard T.trace()
        else 
        {
            fatalError("memory layout of `Godot::\(T.self)` does not appear to match layout assumptions of `\(T.Unpacked.self)`. check godot version compatibility!")
        }
    }
} 


protocol _GodotVariantRepresentableVectorElement:SIMDScalar 
{
    static 
    func load2(_:Godot.Variant.Unmanaged) -> Vector2<Self>?
    static 
    func load3(_:Godot.Variant.Unmanaged) -> Vector3<Self>?
    
    static 
    func store2(_:Vector2<Self>) -> Godot.Variant.Unmanaged
    static 
    func store3(_:Vector3<Self>) -> Godot.Variant.Unmanaged
}
protocol _GodotVariantRepresentableRectangleElement:SIMDScalar 
{
    static 
    func load2x2(_:Godot.Variant.Unmanaged) -> (Vector2<Self>, Vector2<Self>)?
    static 
    func load3x2(_:Godot.Variant.Unmanaged) -> (Vector3<Self>, Vector3<Self>)?
    
    static 
    func store2x2(_:(Vector2<Self>, Vector2<Self>)) -> Godot.Variant.Unmanaged
    static 
    func store3x2(_:(Vector3<Self>, Vector3<Self>)) -> Godot.Variant.Unmanaged
}
protocol _GodotVariantRepresentableVectorStorage:SIMD where Scalar:SIMDScalar 
{
    static 
    func load(_:Godot.Variant.Unmanaged) -> Vector<Self, Scalar>?
    static 
    func store(_:Vector<Self, Scalar>) -> Godot.Variant.Unmanaged
}
protocol _GodotVariantRepresentableRectangleStorage:SIMD where Scalar:SIMDScalar 
{
    static 
    func load2(_:Godot.Variant.Unmanaged) -> (Vector<Self, Scalar>, Vector<Self, Scalar>)?
    static 
    func store2(_:(Vector<Self, Scalar>, Vector<Self, Scalar>)) -> Godot.Variant.Unmanaged
}
extension Godot.VariantRepresentable 
{
    typealias VectorElement     = _GodotVariantRepresentableVectorElement
    typealias VectorStorage     = _GodotVariantRepresentableVectorStorage
    
    typealias RectangleElement  = _GodotVariantRepresentableRectangleElement
    typealias RectangleStorage  = _GodotVariantRepresentableRectangleStorage
}

extension Float16:Godot.VariantRepresentable.VectorElement {}
extension Float32:Godot.VariantRepresentable.VectorElement {}
extension Float64:Godot.VariantRepresentable.VectorElement {}

extension Float16:Godot.VariantRepresentable.RectangleElement {}
extension Float32:Godot.VariantRepresentable.RectangleElement {}
extension Float64:Godot.VariantRepresentable.RectangleElement {}

extension BinaryFloatingPoint where Self:SIMDScalar
{
    static 
    func load2(_ value:Godot.Variant.Unmanaged) -> Vector2<Self>?
    {
        value.load(where: GODOT_VARIANT_TYPE_VECTOR2)
        {
            .init(Godot.api.1.0.godot_variant_as_vector2($0).unpacked)
        } 
    }
    static 
    func load3(_ value:Godot.Variant.Unmanaged) -> Vector3<Self>?
    {
        value.load(where: GODOT_VARIANT_TYPE_VECTOR3)
        {
            .init(Godot.api.1.0.godot_variant_as_vector3($0).unpacked)
        } 
    }
    
    static 
    func store2(_ value:Vector2<Self>) -> Godot.Variant.Unmanaged
    {
        withUnsafePointer(to: godot_vector2.init(packing: .init(value))) 
        {
            .init(value: $0, Godot.api.1.0.godot_variant_new_vector2)
        }
    }
    static 
    func store3(_ value:Vector3<Self>) -> Godot.Variant.Unmanaged
    {
        withUnsafePointer(to: godot_vector3.init(packing: .init(value))) 
        {
            .init(value: $0, Godot.api.1.0.godot_variant_new_vector3)
        }
    }
}
extension BinaryFloatingPoint where Self:SIMDScalar 
{
    static 
    func load2x2(_ value:Godot.Variant.Unmanaged) -> (Vector2<Self>, Vector2<Self>)?
    {
        value.load(where: GODOT_VARIANT_TYPE_RECT2)
        {
            let bounds:(Vector2<Float32>, Vector2<Float32>) = 
                Godot.api.1.0.godot_variant_as_rect2($0).unpacked
            return (.init(bounds.0), .init(bounds.1))
        } 
    }
    static 
    func load3x2(_ value:Godot.Variant.Unmanaged) -> (Vector3<Self>, Vector3<Self>)?
    {
        value.load(where: GODOT_VARIANT_TYPE_AABB)
        {
            let bounds:(Vector3<Float32>, Vector3<Float32>) = 
                Godot.api.1.0.godot_variant_as_aabb($0).unpacked
            return (.init(bounds.0), .init(bounds.1))
        } 
    }
    
    static 
    func store2x2(_ value:(Vector2<Self>, Vector2<Self>)) -> Godot.Variant.Unmanaged
    {
        withUnsafePointer(to: godot_rect2.init(packing: (.init(value.0), .init(value.0)))) 
        {
            .init(value: $0, Godot.api.1.0.godot_variant_new_rect2)
        }
    }
    static 
    func store3x2(_ value:(Vector3<Self>, Vector3<Self>)) -> Godot.Variant.Unmanaged
    {
        withUnsafePointer(to: godot_aabb.init(packing: (.init(value.0), .init(value.0)))) 
        {
            .init(value: $0, Godot.api.1.0.godot_variant_new_aabb)
        }
    }
}

extension SIMD2:Godot.VariantRepresentable.VectorStorage 
    where Scalar:Godot.VariantRepresentable.VectorElement
{
    static 
    func load(_ data:Godot.Variant.Unmanaged) -> Vector2<Scalar>?
    {
        Scalar.load2(data)
    }
    static 
    func store(_ data:Vector2<Scalar>) -> Godot.Variant.Unmanaged
    {
        Scalar.store2(data)
    }
}
extension SIMD3:Godot.VariantRepresentable.VectorStorage 
    where Scalar:Godot.VariantRepresentable.VectorElement
{
    static 
    func load(_ data:Godot.Variant.Unmanaged) -> Vector3<Scalar>?
    {
        Scalar.load3(data)
    }
    static 
    func store(_ data:Vector3<Scalar>) -> Godot.Variant.Unmanaged
    {
        Scalar.store3(data)
    }
}

extension SIMD2:Godot.VariantRepresentable.RectangleStorage 
    where Scalar:Godot.VariantRepresentable.RectangleElement
{
    static 
    func load2(_ data:Godot.Variant.Unmanaged) -> (Vector2<Scalar>, Vector2<Scalar>)?
    {
        Scalar.load2x2(data)
    }
    static 
    func store2(_ data:(Vector2<Scalar>, Vector2<Scalar>)) -> Godot.Variant.Unmanaged
    {
        Scalar.store2x2(data)
    }
}
extension SIMD3:Godot.VariantRepresentable.RectangleStorage 
    where Scalar:Godot.VariantRepresentable.RectangleElement
{
    static 
    func load2(_ data:Godot.Variant.Unmanaged) -> (Vector3<Scalar>, Vector3<Scalar>)?
    {
        Scalar.load3x2(data)
    }
    static 
    func store2(_ data:(Vector3<Scalar>, Vector3<Scalar>)) -> Godot.Variant.Unmanaged
    {
        Scalar.store3x2(data)
    }
}

extension Vector:Godot.VariantRepresentable 
    where Storage:Godot.VariantRepresentable.VectorStorage
{
    static 
    func takeUnretained(_ value:Godot.Variant.Unmanaged) -> Self?
    {
        Storage.load(value)
    }
    func passRetained() -> Godot.Variant.Unmanaged 
    {
        Storage.store(self)
    }
}
extension Vector:Godot.Variant 
    where Storage:Godot.VariantRepresentable.VectorStorage, T == Float32 
{
}

extension VectorFiniteRangeExpression
    where Storage:Godot.VariantRepresentable.RectangleStorage 
{
    static 
    func takeUnretained(_ value:Godot.Variant.Unmanaged) -> Self?
    {
        Storage.load2(value).map{ Self.init(lowerBound: $0.0, upperBound: $0.1) }
    }
    func passRetained() -> Godot.Variant.Unmanaged 
    {
        Storage.store2((self.lowerBound, self.upperBound))
    }
}
extension Vector.Rectangle:Godot.Variant 
    where Storage:Godot.VariantRepresentable.RectangleStorage, T == Float32 
{
}
extension Vector.Rectangle:Godot.VariantRepresentable 
    where Storage:Godot.VariantRepresentable.RectangleStorage, T:Comparable
{
} 
extension Vector.ClosedRectangle:Godot.VariantRepresentable 
    where Storage:Godot.VariantRepresentable.RectangleStorage, T:Comparable
{
} 


extension Godot.Transform2.Affine:Godot.Variant 
{
    static 
    func takeUnretained(_ value:Godot.Variant.Unmanaged) -> Self?
    {
        value.load(where: GODOT_VARIANT_TYPE_TRANSFORM2D)
        {
            .init(matrix: Godot.api.1.0.godot_variant_as_transform2d($0).unpacked)
        } 
    }
    func passRetained() -> Godot.Variant.Unmanaged 
    {
        Swift.withUnsafePointer(to: godot_transform2d.init(packing: self.matrix))
        {
            .init(value: $0, Godot.api.1.0.godot_variant_new_transform2d)
        }
    }
}
extension Godot.Transform3.Affine:Godot.Variant 
{
    static 
    func takeUnretained(_ value:Godot.Variant.Unmanaged) -> Self?
    {
        value.load(where: GODOT_VARIANT_TYPE_TRANSFORM)
        {
            .init(matrix: Godot.api.1.0.godot_variant_as_transform($0).unpacked)
        } 
    }
    func passRetained() -> Godot.Variant.Unmanaged 
    {
        Swift.withUnsafePointer(to: godot_transform.init(packing: self.matrix))
        {
            .init(value: $0, Godot.api.1.0.godot_variant_new_transform)
        }
    }
} 
extension Godot.Transform3.Linear:Godot.Variant 
{
    static 
    func takeUnretained(_ value:Godot.Variant.Unmanaged) -> Self?
    {
        value.load(where: GODOT_VARIANT_TYPE_BASIS)
        {
            .init(matrix: Godot.api.1.0.godot_variant_as_basis($0).unpacked)
        }
    }
    func passRetained() -> Godot.Variant.Unmanaged 
    {
        Swift.withUnsafePointer(to: godot_basis.init(packing: self.matrix))
        {
            .init(value: $0, Godot.api.1.0.godot_variant_new_basis)
        }
    }
} 

extension Godot.String:Godot.Variant 
{
    static 
    func takeUnretained(_ value:Godot.Variant.Unmanaged) -> Self?
    {
        value.load(where: GODOT_VARIANT_TYPE_STRING)
        {
            .init(retained: Godot.api.1.0.godot_variant_as_string($0))
        } 
    }
    func passRetained() -> Godot.Variant.Unmanaged 
    {
        self.withUnsafePointer
        {
            .init(value: $0, Godot.api.1.0.godot_variant_new_string)
        }
    }
}
extension Godot.List:Godot.Variant 
{
    static 
    func takeUnretained(_ value:Godot.Variant.Unmanaged) -> Self?
    {
        value.load(where: GODOT_VARIANT_TYPE_ARRAY)
        {
            .init(retained: Godot.api.1.0.godot_variant_as_array($0))
        }
    }
    func passRetained() -> Godot.Variant.Unmanaged 
    {
        self.withUnsafePointer
        {
            .init(value: $0, Godot.api.1.0.godot_variant_new_array)
        }
    }
}
extension Godot.Map:Godot.Variant 
{
    static 
    func takeUnretained(_ value:Godot.Variant.Unmanaged) -> Self?
    {
        value.load(where: GODOT_VARIANT_TYPE_DICTIONARY)
        {
            .init(retained: Godot.api.1.0.godot_variant_as_dictionary($0))
        }
    }
    func passRetained() -> Godot.Variant.Unmanaged 
    {
        self.withUnsafePointer
        {
            .init(value: $0, Godot.api.1.0.godot_variant_new_dictionary)
        }
    }
}
extension Godot.AnyDelegate:Godot.Variant 
{
    static 
    func takeUnretained(_ value:Godot.Variant.Unmanaged) -> Self?
    {
        value.load(where: GODOT_VARIANT_TYPE_OBJECT) 
        {
            (variant:UnsafePointer<godot_variant>) -> Self? in
            
            guard let core:UnsafeMutableRawPointer = 
                Godot.api.1.0.godot_variant_as_object(variant)
            else 
            {
                return nil
            }
            // `godot_variant_as_object` passes object unretained
            return Godot.type(of: core).init(unretained: core) as? Self
        } ?? nil
    }
    func passRetained() -> Godot.Variant.Unmanaged 
    {
        withExtendedLifetime(self) 
        {
            // `godot_variant_new_object` passes the object retained, unlike 
            // `godot_variant_as_object` for some reason
            .init(value: self.core, Godot.api.1.0.godot_variant_new_object)
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
    fileprivate 
    init(_ body:(UnsafeMutablePointer<godot_variant>) throws -> ()) 
        rethrows
    {
        self.data = .init()
        try body(&self.data)
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
    @available(*, unavailable, message: "unimplemented")
    mutating 
    func retain() 
    {
    }
    mutating 
    func release() 
    {
        Godot.api.1.0.godot_variant_destroy(&self.data)
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
        value.passRetained()
    }
    static 
    func pass(retained value:Godot.Variant) -> Self
    {
        value.passRetained()
    }
    static 
    func pass(retained value:Void) -> Self
    {
        .init(Godot.api.1.0.godot_variant_new_nil)
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
        return T.takeUnretained(self)
    }
    func take<T>(unretained _:T.Type) -> T? 
        where T:Godot.VariantRepresentable 
    {
        T.takeUnretained(self)
    }
    func take(unretained _:Void.Type) -> Void?
    {
        self.load(where: GODOT_VARIANT_TYPE_NIL)
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
                return Godot.api.1.0.godot_variant_as_bool($0)
            case GODOT_VARIANT_TYPE_INT:
                return Godot.api.1.0.godot_variant_as_int($0)
            case GODOT_VARIANT_TYPE_REAL:
                return Godot.api.1.0.godot_variant_as_real($0)
            
            case GODOT_VARIANT_TYPE_VECTOR2:
                return Godot.api.1.0.godot_variant_as_vector2($0).unpacked
            case GODOT_VARIANT_TYPE_VECTOR3:
                return Godot.api.1.0.godot_variant_as_vector3($0).unpacked
            
            case GODOT_VARIANT_TYPE_RECT2:
                let bounds:(Vector2<Float32>, Vector2<Float32>) = 
                    Godot.api.1.0.godot_variant_as_rect2($0).unpacked
                return Vector2<Float32>.Rectangle.init(
                    lowerBound: bounds.0, upperBound: bounds.1)
            
            case GODOT_VARIANT_TYPE_AABB:
                let bounds:(Vector3<Float32>, Vector3<Float32>) = 
                    Godot.api.1.0.godot_variant_as_aabb($0).unpacked
                return Vector3<Float32>.Rectangle.init(
                    lowerBound: bounds.0, upperBound: bounds.1)
            
            case GODOT_VARIANT_TYPE_TRANSFORM2D:
                return Godot.Transform2.Affine.init(matrix: 
                    Godot.api.1.0.godot_variant_as_transform2d($0).unpacked)
            case GODOT_VARIANT_TYPE_TRANSFORM:
                return Godot.Transform3.Affine.init(matrix: 
                    Godot.api.1.0.godot_variant_as_transform($0).unpacked) 
            case GODOT_VARIANT_TYPE_BASIS:
                return Godot.Transform3.Linear.init(matrix: 
                    Godot.api.1.0.godot_variant_as_basis($0).unpacked) 
            
            case GODOT_VARIANT_TYPE_STRING:
                return Godot.String.init(retained: 
                    Godot.api.1.0.godot_variant_as_string($0))
            case GODOT_VARIANT_TYPE_ARRAY:
                return Godot.List.init(retained: 
                    Godot.api.1.0.godot_variant_as_array($0))
            case GODOT_VARIANT_TYPE_DICTIONARY:
                return Godot.Map.init(retained: 
                    Godot.api.1.0.godot_variant_as_dictionary($0))
            
            case GODOT_VARIANT_TYPE_OBJECT:
                guard let core:UnsafeMutableRawPointer = 
                    Godot.api.1.0.godot_variant_as_object($0)
                else 
                {
                    Godot.print(error: "encountered nil delegate pointer while unwrapping variant")
                    return Godot.Void.init()
                }
                // loading an object pointer from a variant does not seem to 
                // increment its reference count, so we take it unretained
                return Godot.type(of: core).init(unretained: core)
            
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
        self.init(retained: Godot.api.1.0.godot_string_chars_to_utf8(string))
    }
}
extension Swift.String 
{
    init(_ string:Godot.String)
    {
        var utf8:godot_char_string = 
            string.withUnsafePointer(Godot.api.1.0.godot_string_utf8)
        self.init(cString: unsafeBitCast(utf8, to: UnsafePointer<Int8>.self))
        Godot.api.1.0.godot_char_string_destroy(&utf8)
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
        self.init(with: Godot.api.1.0.godot_array_new)
        self.resize(to: capacity)
    }
    
    func resize(to capacity:Int) 
    {
        Godot.api.1.0.godot_array_resize(&self.core, .init(capacity))
    }
    
    var startIndex:Int 
    {
        0
    }
    var endIndex:Int 
    {
        .init(self.withUnsafePointer(Godot.api.1.0.godot_array_size))
    }
    
    subscript(unmanaged index:Int) -> Godot.Variant.Unmanaged 
    {
        get 
        {
            guard let raw:UnsafeRawPointer = (self.withUnsafePointer 
            {
                Godot.api.1.0.godot_array_operator_index_const($0, .init(index))
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
                Godot.api.1.0.godot_array_operator_index(&self.core, .init(index))
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
        self.init(with: Godot.api.1.0.godot_dictionary_new)
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
                    Godot.api.1.0.godot_dictionary_operator_index_const($0, key)
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
                Godot.api.1.0.godot_dictionary_operator_index(&self.core, key)
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
    static 
    func takeUnretained(_ value:Godot.Variant.Unmanaged) -> Self?
    {
        if let wrapped:Wrapped  = value.take(unretained: Wrapped.self)
        {
            return .some(wrapped)
        }
        else if let _:Void      = value.take(unretained: Void.self) 
        {
            return .some(.none)
        }
        else 
        {
            return nil 
        }
    }
    func passRetained() -> Godot.Variant.Unmanaged 
    {
        if let wrapped:Wrapped = self 
        {
            return .pass(retained: wrapped)
        }
        else 
        {
            return .pass(retained: ())
        }
    }
}

extension String:Godot.VariantRepresentable 
{
    static 
    func takeUnretained(_ value:Godot.Variant.Unmanaged) -> Self?
    {
        value.take(unretained: Godot.String.self).map(Self.init(_:))
    }
    func passRetained() -> Godot.Variant.Unmanaged 
    {
        .pass(retained: Godot.String.init(self))
    }
} 

// “icall” types. these are related, but orthogonal to `Variant`/`VariantRepresentable`
protocol _GodotBoundMethodPassable
{
    static 
    func take(_ body:(UnsafeMutableRawPointer) -> ()) -> Self 
    func pass(_ body:(UnsafeRawPointer) -> ())
}
extension Godot 
{
    struct BoundMethod 
    {
        typealias Passable = _GodotBoundMethodPassable
        
        private 
        let function:UnsafeMutablePointer<godot_method_bind>
    }
}
extension Godot.BoundMethod 
{
    static 
    func bind<T>(method:String, from _:T.Type) -> Self 
        where T:Godot.AnyDelegate
    {
        guard let function:UnsafeMutablePointer<godot_method_bind> = 
            Godot.api.1.0.godot_method_bind_get_method(T.symbol, method)
        else 
        {
            fatalError("could not load method 'Godot::\(T.symbol).\(method)'")
        }
        return .init(function: function)
    }
    
    func callAsFunction<V0>(self delegate:Godot.AnyDelegate) -> V0
        where V0:Passable 
    {
        .take 
        {
            (result:UnsafeMutableRawPointer) in 
            withExtendedLifetime(delegate)
            {
                Godot.api.1.0.godot_method_bind_ptrcall(self.function, 
                    delegate.core, nil, result)
            }
        }
    }
    func callAsFunction<U0, U1, U2, V0>(self delegate:Godot.AnyDelegate, _ u0:U0, _ u1:U1, _ u2:U2)
        -> V0
        where U0:Passable, U1:Passable, U2:Passable, V0:Passable 
    {
        .take 
        {
            (result:UnsafeMutableRawPointer) in 
            u0.pass 
            {
                (u0:UnsafeRawPointer?) in 
                u1.pass 
                {
                    (u1:UnsafeRawPointer?) in 
                    u2.pass 
                    {
                        (u2:UnsafeRawPointer?) in 
                        
                        withExtendedLifetime(delegate)
                        {
                            var arguments:[UnsafeRawPointer?] = [u0, u1, u2]
                            arguments.withUnsafeMutableBufferPointer 
                            {
                                Godot.api.1.0.godot_method_bind_ptrcall(self.function, 
                                    delegate.core, $0.baseAddress, result)
                            }
                        }
                    }
                }
            }
        }
    }
}
extension Bool:Godot.BoundMethod.Passable 
{
    static 
    func take(_ body:(UnsafeMutableRawPointer) -> ()) -> Self 
    {
        var value:Bool = false
        body(&value)
        return value
    }
    func pass(_ body:(UnsafeRawPointer) -> ())
    {
        fatalError("unimplemented")
    }
}
extension Swift.String:Godot.BoundMethod.Passable 
{
    // closure is responsible for initializing the value
    static 
    func take(_ body:(UnsafeMutableRawPointer) -> ()) -> Self 
    {
        var core:godot_string = .init()
        body(&core)
        return .init(Godot.String.init(retained: core))
    }
    func pass(_ body:(UnsafeRawPointer) -> ())
    {
        fatalError("unimplemented")
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
