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
        typealias Binding = (type:NativeScriptCore.Type, symbol:String)
        
        public 
        let types:[(type:NativeScriptCore.Type, symbols:[String])]
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
                let symbol:String, 
                    metatype:Metatype 
                
                init(_ symbol:String, metatype:Metatype)
                {
                    self.symbol     = symbol
                    self.metatype   = metatype
                }
                
                func track() 
                {
                    self.metatype.instances[self.symbol]?.wrappingIncrement(ordering: .sequentiallyConsistent)
                }
                func untrack() 
                {
                    self.metatype.instances[self.symbol]?.wrappingDecrement(ordering: .sequentiallyConsistent)
                }
            }
            
            private 
            var instances:[String: ManagedAtomic<Int>] 
            
            init(symbols:[String]) 
            {
                self.instances = .init(uniqueKeysWithValues: symbols.map{ ($0, .init(0)) })
            }
            
            deinit 
            {
                func plural(_ count:Int) -> String 
                {
                    count == 1 ? "\(count) leaked instance" : "\(count) leaked instances"
                }
                
                let leaked:[String: Int] = self.instances.compactMapValues 
                {
                    let count:Int = $0.load(ordering: .relaxed)
                    return count != 0 ? count : nil
                }
                if !leaked.isEmpty 
                {
                    Godot.print(warning: 
                        """
                        detected \(plural(leaked.values.reduce(0, +))) of \(String.init(reflecting: T.self)):
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
            typealias Property  = KeyPath<T,                                      Godot.Variant?>
            #if BUILD_STAGE_INERT
            typealias Method    = Any.Type 
            #else 
            typealias Method    =        (T) -> (T.Delegate, [Godot.Variant?]) -> Godot.Variant?
            #endif 
        }
        
        typealias Property  = (witness:Witness.Property, symbol:String)
        typealias Method    = (witness:Witness.Method,   symbol:String)
        
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
    
    fileprivate static 
    func with<R>(string:String, body:(UnsafeMutablePointer<godot_string>) throws -> R) rethrows 
        -> R
    {
        var data:godot_string = .init()
        Self.api.functions.godot_string_new(&data)
        if Self.api.functions.godot_string_parse_utf8(&data, string)
        {
            fatalError("(swift) malformed utf-8 string")
        }
        
        defer 
        {
            Self.api.functions.godot_string_destroy(&data)
        }
        
        return try body(&data)
    }
    
    static 
    func print(_ items:Any..., separator:String = " ", terminator:String = "") 
    {
        Self.with(string: "(swift) \(items.map{"\($0)"}.joined(separator: separator))\(terminator)") 
        {
            Self.api.functions.godot_print($0)
        }
    }
    static 
    func print(warning:String, function:String = #function, file:String = #file, line:Int32 = #line) 
    {
        Self.api.functions.godot_print_warning("(swift) \(warning)", function, file, line)
    }
    static 
    func print(error:String, function:String = #function, file:String = #file, line:Int32 = #line) 
    {
        Self.api.functions.godot_print_error("(swift) \(error)", function, file, line)
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
                
                for (type, _):(NativeScriptCore.Type, [String]) in self.interface.types 
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

// godot basic type-bridging 
extension Godot 
{
    /*
    void (*godot_variant_new_nil)(godot_variant *r_dest);
    void (*godot_variant_new_bool)(godot_variant *r_dest, const godot_bool p_b);
    void (*godot_variant_new_uint)(godot_variant *r_dest, const uint64_t p_i);
    void (*godot_variant_new_int)(godot_variant *r_dest, const int64_t p_i);
    void (*godot_variant_new_real)(godot_variant *r_dest, const double p_r);
    void (*godot_variant_new_string)(godot_variant *r_dest, const godot_string *p_s);
    void (*godot_variant_new_vector2)(godot_variant *r_dest, const godot_vector2 *p_v2);
    void (*godot_variant_new_rect2)(godot_variant *r_dest, const godot_rect2 *p_rect2);
    void (*godot_variant_new_vector3)(godot_variant *r_dest, const godot_vector3 *p_v3);
    void (*godot_variant_new_transform2d)(godot_variant *r_dest, const godot_transform2d *p_t2d);
    void (*godot_variant_new_plane)(godot_variant *r_dest, const godot_plane *p_plane);
    void (*godot_variant_new_quat)(godot_variant *r_dest, const godot_quat *p_quat);
    void (*godot_variant_new_aabb)(godot_variant *r_dest, const godot_aabb *p_aabb);
    void (*godot_variant_new_basis)(godot_variant *r_dest, const godot_basis *p_basis);
    void (*godot_variant_new_transform)(godot_variant *r_dest, const godot_transform *p_trans);
    void (*godot_variant_new_color)(godot_variant *r_dest, const godot_color *p_color);
    void (*godot_variant_new_node_path)(godot_variant *r_dest, const godot_node_path *p_np);
    void (*godot_variant_new_rid)(godot_variant *r_dest, const godot_rid *p_rid);
    void (*godot_variant_new_object)(godot_variant *r_dest, const godot_object *p_obj);
    void (*godot_variant_new_dictionary)(godot_variant *r_dest, const godot_dictionary *p_dict);
    void (*godot_variant_new_array)(godot_variant *r_dest, const godot_array *p_arr);
    void (*godot_variant_new_pool_byte_array)(godot_variant *r_dest, const godot_pool_byte_array *p_pba);
    void (*godot_variant_new_pool_int_array)(godot_variant *r_dest, const godot_pool_int_array *p_pia);
    void (*godot_variant_new_pool_real_array)(godot_variant *r_dest, const godot_pool_real_array *p_pra);
    void (*godot_variant_new_pool_string_array)(godot_variant *r_dest, const godot_pool_string_array *p_psa);
    void (*godot_variant_new_pool_vector2_array)(godot_variant *r_dest, const godot_pool_vector2_array *p_pv2a);
    void (*godot_variant_new_pool_vector3_array)(godot_variant *r_dest, const godot_pool_vector3_array *p_pv3a);
    void (*godot_variant_new_pool_color_array)(godot_variant *r_dest, const godot_pool_color_array *p_pca);
    */
    enum Variant 
    {
        final 
        class List 
        {
            private 
            var core:godot_array
            
            private 
            init(core:godot_array) 
            {
                self.core   = core
            }
            
            convenience 
            init(capacity:Int = 0) 
            {
                var core:godot_array = .init()
                Godot.api.functions.godot_array_new(&core)
                
                self.init(core: core)
                self.resize(to: capacity)
            }
            
            // performs an unbalanced retain when passing to swift. 
            // swift is responsible for releasing the passed list.
            // the original variant container is still valid. 
            fileprivate static 
            func pass(retained variant:UnsafePointer<godot_variant>) -> List 
            {
                let core:godot_array = Godot.api.functions.godot_variant_as_array(variant)
                return .init(core: core)
            }
            
            // takes a value from swift, without performing a (balanced) release. 
            // the required release should take place when the swift class 
            // gets deinitialized.
            fileprivate static 
            func take(unretained self:List, destination variant:UnsafeMutablePointer<godot_variant>)  
            {
                withExtendedLifetime(self)
                {
                    Godot.api.functions.godot_variant_new_array(variant, &self.core)
                }
            }
            
            // note: take(retained:) does not make sense, as swift classes are 
            // already reference-counted.
            
            deinit 
            {
                Godot.api.functions.godot_array_destroy(&self.core)
            }
        }
        
        final 
        class UnorderedMap 
        {
            private 
            var core:godot_dictionary
            
            private 
            init(core:godot_dictionary) 
            {
                self.core   = core
            }
            
            convenience 
            init() 
            {
                var core:godot_dictionary = .init()
                Godot.api.functions.godot_dictionary_new(&core)
                self.init(core: core)
            }
            
            // performs an unbalanced retain when passing to swift. 
            // swift is responsible for releasing the passed dictionary.
            // the original variant container is still valid. 
            fileprivate static 
            func pass(retained variant:UnsafePointer<godot_variant>) -> UnorderedMap 
            {
                let core:godot_dictionary = Godot.api.functions.godot_variant_as_dictionary(variant)
                return .init(core: core)
            }
            
            // takes a value from swift, without performing a (balanced) release. 
            // the required release should take place when the swift class 
            // gets deinitialized.
            fileprivate static 
            func take(unretained self:UnorderedMap, destination variant:UnsafeMutablePointer<godot_variant>)  
            {
                withExtendedLifetime(self)
                {
                    Godot.api.functions.godot_variant_new_dictionary(variant, &self.core)
                }
            }
            
            // note: take(retained:) does not make sense, as swift classes are 
            // already reference-counted.
            
            deinit 
            {
                Godot.api.functions.godot_dictionary_destroy(&self.core)
            }
        }
        
        enum Array 
        {
            case uint8([UInt8])
            case int([Int])
            case double([Double])
            case string([String])
            //case vector2([Vector2<Double>])
            //case vector3([Vector3<Double>])
            //case rgba([RGBA<Double>])
        }
        
        case bool(Bool)
        case int(Int)
        case uint64(UInt64)
        case double(Double)
        case string(String)
        
        case list(List)
        case unorderedMap(UnorderedMap)
        
        case array(Variant.Array)
        
        // case vector2(Vector2<Double>)
        // case vector3(Vector3<Double>)
        
        // case matrix2(Matrix2<Double>) // godot_transform2d
        // case matrix3(Matrix3<Double>) // godot_basis 
        
        // case rectangle2(Vector2<Double>.Rectangle) // godot_rect 
        // case rectangle3(Vector3<Double>.Rectangle) // godot_aabb
        
        // case plane(Vector3<Double>.Plane)
        
        // case rgba(RGBA<Double>)
        // case quaternion(Vector4<Double>.Quaternion)
        
        // godot_node_path
        // godot_rid
        // godot_object
        
        /* static 
        func take(retained value:inout godot_variant) -> Self? 
        {
            defer 
            {
                Godot.api.functions.godot_variant_destroy(&value)
            }
            return .take(unretained: &value)
        } */
        
        // move-initializes a reference-counted value to swift. 
        // swift is responsible for releasing the passed list.
        // the original variant container is no longer valid. 
        static 
        func pass(unretained pointer:UnsafeMutablePointer<godot_variant>) -> Self? 
        {
            let value:Self? = .pass(retained: pointer)
            Godot.api.functions.godot_variant_destroy(pointer)
            return value
        }
        
        static 
        func pass(retained pointer:UnsafePointer<godot_variant>) -> Self? 
        {
            switch Godot.api.functions.godot_variant_get_type(pointer)
            {
            case GODOT_VARIANT_TYPE_NIL:
                return nil 
            case GODOT_VARIANT_TYPE_BOOL:
                return .bool(Godot.api.functions.godot_variant_as_bool(pointer))
            
            case GODOT_VARIANT_TYPE_INT:
                let uint64:UInt64   = Godot.api.functions.godot_variant_as_uint(pointer)
                if let int:Int      = .init(exactly: Int64.init(bitPattern: uint64))
                {
                    return .int(int)
                }
                else 
                {
                    return .uint64(uint64)
                }
            
            case GODOT_VARIANT_TYPE_REAL:
                return .double(Godot.api.functions.godot_variant_as_real(pointer))
            
            case GODOT_VARIANT_TYPE_STRING:
                var data:godot_string       = Godot.api.functions.godot_variant_as_string(pointer)
                var utf8:godot_char_string  = Godot.api.functions.godot_string_utf8(&data)
                
                let string:String = withUnsafePointer(to: utf8) 
                {
                    $0.withMemoryRebound(to: UnsafePointer<Int8>.self, capacity: 1) 
                    {
                        .init(cString: $0.pointee)
                    }
                }
                
                Godot.api.functions.godot_char_string_destroy(&utf8)
                Godot.api.functions.godot_string_destroy(&data)
                
                return .string(string)
            
            case GODOT_VARIANT_TYPE_DICTIONARY:
                return .unorderedMap(.pass(retained: pointer))
            case GODOT_VARIANT_TYPE_ARRAY:
                return .list(.pass(retained: pointer))
            
            case GODOT_VARIANT_TYPE_VECTOR2:
                Godot.print(error: "variant type 'VECTOR2' is unsupported")
                return nil 
            case GODOT_VARIANT_TYPE_RECT2:
                Godot.print(error: "variant type 'RECT2' is unsupported")
                return nil 
            case GODOT_VARIANT_TYPE_VECTOR3:
                Godot.print(error: "variant type 'VECTOR3' is unsupported")
                return nil 
            case GODOT_VARIANT_TYPE_TRANSFORM2D:
                Godot.print(error: "variant type 'TRANSFORM2D' is unsupported")
                return nil 
            case GODOT_VARIANT_TYPE_PLANE:
                Godot.print(error: "variant type 'PLANE' is unsupported")
                return nil 
            case GODOT_VARIANT_TYPE_QUAT:
                Godot.print(error: "variant type 'QUAT' is unsupported")
                return nil 
            case GODOT_VARIANT_TYPE_AABB:
                Godot.print(error: "variant type 'AABB' is unsupported")
                return nil 
            case GODOT_VARIANT_TYPE_BASIS:
                Godot.print(error: "variant type 'BASIS' is unsupported")
                return nil 
            case GODOT_VARIANT_TYPE_TRANSFORM:
                Godot.print(error: "variant type 'TRANSFORM' is unsupported")
                return nil 

            case GODOT_VARIANT_TYPE_COLOR:
                Godot.print(error: "variant type 'COLOR' is unsupported")
                return nil
            case GODOT_VARIANT_TYPE_NODE_PATH:
                Godot.print(error: "variant type 'NODE_PATH' is unsupported")
                return nil
            case GODOT_VARIANT_TYPE_RID:
                Godot.print(error: "variant type 'RID' is unsupported")
                return nil
            case GODOT_VARIANT_TYPE_OBJECT:
                Godot.print(error: "variant type 'OBJECT' is unsupported")
                return nil
            
            case GODOT_VARIANT_TYPE_POOL_BYTE_ARRAY:
                Godot.print(error: "variant type 'POOL_BYTE_ARRAY' is unsupported")
                return nil
            case GODOT_VARIANT_TYPE_POOL_INT_ARRAY:
                Godot.print(error: "variant type 'POOL_INT_ARRAY' is unsupported")
                return nil
            case GODOT_VARIANT_TYPE_POOL_REAL_ARRAY:
                Godot.print(error: "variant type 'POOL_REAL_ARRAY' is unsupported")
                return nil
            case GODOT_VARIANT_TYPE_POOL_STRING_ARRAY:
                Godot.print(error: "variant type 'POOL_STRING_ARRAY' is unsupported")
                return nil
            case GODOT_VARIANT_TYPE_POOL_VECTOR2_ARRAY:
                Godot.print(error: "variant type 'POOL_VECTOR2_ARRAY' is unsupported")
                return nil
            case GODOT_VARIANT_TYPE_POOL_VECTOR3_ARRAY:
                Godot.print(error: "variant type 'POOL_VECTOR3_ARRAY' is unsupported")
                return nil
            case GODOT_VARIANT_TYPE_POOL_COLOR_ARRAY:
                Godot.print(error: "variant type 'POOL_COLOR_ARRAY' is unsupported")
                return nil
                
            case let code:
                Godot.print(error: "unknown variant type (code: \(code))")
                return nil 
            }
        }
        
        static 
        func take(unretained self:Self?) -> godot_variant 
        {
            var data:godot_variant = .init()
            Self.take(unretained: self, destination: &data)
            return data 
        }
        
        static 
        func take(unretained self:Self?, destination pointer:UnsafeMutablePointer<godot_variant>) 
        {
            switch self 
            {
            case nil:
                Godot.api.functions.godot_variant_new_nil(pointer)
            case .bool(let bool)?:
                Godot.api.functions.godot_variant_new_bool(pointer, bool)
            case .int(let int)?:
                Godot.api.functions.godot_variant_new_int(pointer, .init(int))
            case .uint64(let uint64)?:
                Godot.api.functions.godot_variant_new_uint(pointer, uint64)
            case .double(let double):
                Godot.api.functions.godot_variant_new_real(pointer, double)
            case .string(let string):
                Godot.with(string: string)
                {
                    Godot.api.functions.godot_variant_new_string(pointer, $0)
                }
            
            case .list(let list):
                List.take(unretained: list, destination: pointer)
            case .unorderedMap(let map):
                UnorderedMap.take(unretained: map, destination: pointer)
            
            case .array(_):
                Godot.print(error: "variant type 'POOL_???_ARRAY' is unsupported")
                Godot.api.functions.godot_variant_new_nil(pointer)
            }
        }
    }
}
extension Godot.Variant.List:RandomAccessCollection, MutableCollection
{
    var startIndex:Int 
    {
        0
    }
    var endIndex:Int 
    {
        .init(Godot.api.functions.godot_array_size(&self.core))
    }
    
    subscript(index:Int) -> Godot.Variant? 
    {
        get 
        {
            guard let pointer:UnsafePointer<godot_variant> = 
                Godot.api.functions.godot_array_operator_index_const(&self.core, .init(index))
            else 
            {
                return nil 
            }
            return .pass(retained: pointer) 
        }
        set(value) 
        {
            guard let pointer:UnsafeMutablePointer<godot_variant> = 
                Godot.api.functions.godot_array_operator_index(&self.core, .init(index))
            else 
            {
                return 
            }
            // deinitialize the existing value 
            Godot.api.functions.godot_variant_destroy(pointer)
            // initialize the new value
            Godot.Variant.take(unretained: value, destination: pointer)
        }
    }
    
    func resize(to capacity:Int) 
    {
        Godot.api.functions.godot_array_resize(&self.core, .init(capacity))
    }
}
extension Godot.Variant.UnorderedMap
{
    subscript(key:Godot.Variant?) -> Godot.Variant? 
    {
        get 
        {
            var key:godot_variant = Godot.Variant.take(unretained: key)
            let pointer:UnsafePointer<godot_variant>? = 
                Godot.api.functions.godot_dictionary_operator_index_const(&self.core, &key)
            Godot.api.functions.godot_variant_destroy(&key)
            
            if let pointer:UnsafePointer<godot_variant> = pointer 
            {
                return .pass(retained: pointer) 
            }
            else 
            {
                return nil 
            }
        }
        set(value) 
        {
            var key:godot_variant = Godot.Variant.take(unretained: key)
            let pointer:UnsafeMutablePointer<godot_variant>? = 
                Godot.api.functions.godot_dictionary_operator_index(&self.core, &key)
            Godot.api.functions.godot_variant_destroy(&key)
            
            if let pointer:UnsafeMutablePointer<godot_variant> = pointer 
            {
                // deinitialize the existing value 
                Godot.api.functions.godot_variant_destroy(pointer)
                // initialize the new value
                Godot.Variant.take(unretained: value, destination: pointer)
            }
        }
    }
}

extension Godot 
{    
    struct MeshInstance:NativeScriptDelegate 
    {
        static 
        let name:String = "MeshInstance"
        
        init(_:UnsafeMutableRawPointer)
        {
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
