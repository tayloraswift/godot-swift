enum Inspector 
{
    static 
    let entrypoint:String = "__inspector_entrypoint_loader__"
}

#if !BUILD_STAGE_INERT 

import TSCBasic
import Workspace

extension Inspector 
{
    static 
    func inspect(workspace:AbsolutePath, toolchain:AbsolutePath, 
        dependency:(package:String, product:String, path:AbsolutePath)) throws
        -> [(typename:String, symbols:[String], signatures:[String])]
    {
        typealias InspectorFunction = () -> [(typename:String, symbols:[String], signatures:[String])]
        
        let triple:Triple = .getHostTriple(usingSwiftCompiler: toolchain)
        
        var configuration:String { "debug" }
        let path:(cache:AbsolutePath, build:AbsolutePath, product:AbsolutePath)
        path.cache      = workspace.appending(component: ".cache")
        path.build      = workspace.appending(component: ".build")
        path.product    = path.build.appending(component: configuration).appending(
            component: "\(triple.dynamicLibraryPrefix)\(dependency.product)\(triple.dynamicLibraryExtension)")
        
        let arguments:[String] = 
        [
            "swift", "build", "--product", dependency.product, 
            "-c", configuration, 
            "--package-path",   "\(dependency.path)", 
            "--cache-path",     "\(path.cache)", 
            "--build-path",     "\(path.build)", 
            "--disable-repository-cache",
            "-Xswiftc", "-DBUILD_STAGE_INERT"
        ]
        
        print("building inert framework with invocation:")
        print(arguments.joined(separator: " "))
        
        let process:Process = .init(arguments: arguments, environment: ProcessEnv.vars, 
            outputRedirection: .none)
        try process.launch()
        let result:ProcessResult = try process.waitUntilExit()
            
        guard case .terminated(code: 0) = result.exitStatus
        else 
        {
            fatalError("error: build stage 'inert' failed")
        }
        
        guard let library:DLHandle = try? dlopen("\(path.product)", mode: [.now, .local]) 
        else 
        {
            fatalError("failed to open incomplete library at '\(path.product)'")
        }
        
        guard let entrypoint:@convention(c) () -> UnsafeMutableRawPointer = 
            dlsym(library, symbol: Self.entrypoint) 
        else 
        {
            fatalError("missing symbol '\(Self.entrypoint)'")
        }
        
        guard let inspector:InspectorFunction = 
            Unmanaged<AnyObject>.fromOpaque(entrypoint()).takeRetainedValue() 
            as? InspectorFunction
        else 
        {
            fatalError("wrong inspector function signature")
        }
        
        // dlclose seems to be broken, so we leak the dynamic library, just as 
        // the swift official tools do: 
        // https://github.com/apple/swift-tools-support-core/blob/main/Sources/TSCUtility/IndexStore.swift#L264
        library.leak()
        
        return inspector()
    }
}

extension Synthesizer 
{
    private 
    struct FunctionParameterization:Hashable, CustomStringConvertible
    {
        private 
        enum Form:Hashable  
        {
            case unparameterized(String) 
            case parameterized 
            case compound([Self])
            
            init(_ type:SwiftGrammar.SwiftType) 
            {
                switch type 
                {
                case .compound(let elements):
                    self = .compound(elements.map{ Self.init($0.type) })
                default:
                    self = .parameterized 
                }
            }
            
            static 
            func form(of function:(parameters:[SwiftGrammar.SwiftType], return:SwiftGrammar.SwiftType), 
                unparameterized:[String]) 
                -> (Self, Self) 
            {
                (
                    .compound(
                        unparameterized.map(Self.unparameterized(_:)) 
                        + 
                        function.parameters.map(Self.init(_:))
                    ), 
                    .init(function.return)
                )
            }
            
            func render(prefix:String, traversed counter:Int = 0) -> (rendered:String, count:Int) 
            {
                switch self 
                {
                case .unparameterized(let name): 
                    return (name, 0)
                case .parameterized: 
                    return ("\(prefix)\(counter)", 1)
                case .compound(let leaves):
                    var traversed:Int       = 0
                    var components:[String] = []
                    for leaf:Self in leaves 
                    {
                        let (component, count):(String, Int) = 
                            leaf.render(prefix: prefix, traversed: counter + traversed)
                        traversed += count 
                        components.append(component)
                    }
                    return ("(\(components.joined(separator: ", ")))", traversed)
                }
            }
        }
        
        private 
        let domain:Form, 
            range:Form 
        private 
        let prefix:String 
        
        init(function:(parameters:[SwiftGrammar.SwiftType], return:SwiftGrammar.SwiftType), 
            unparameterized:[String], // leading type parameters to append to the parameters tuple
            parameterPrefix:String)   // a prefix like 'T' or 'U'
        {
            (self.domain, self.range) = Form.form(of: function, 
                unparameterized: unparameterized)
            self.prefix = parameterPrefix
        }
        
        var description:String 
        {
            let parameterization:
            (
                domain:(rendered:String, count:Int),
                range: (rendered:String, count:Int)
            ) 
            parameterization.domain = domain.render(prefix: self.prefix)
            parameterization.range  =  range.render(prefix: self.prefix, 
                traversed: parameterization.domain.count)
            return "\(parameterization.domain.rendered) -> \(parameterization.range.rendered)"
        }
    }
    
    static 
    func generate(staged:AbsolutePath, interface:[(typename:String, symbols:[String], signatures:[String])])
    {
        let parameterizations:Set<FunctionParameterization> = 
            .init(interface.flatMap(\.signatures).compactMap
        {
            (signature:String) -> FunctionParameterization? in 
            
            guard let type:SwiftGrammar.SwiftType = .init(parsing: signature)
            else 
            {
                print("error: failed to parse signature '\(signature)'")
                return nil 
            }
            
            guard case .function(let function) = type 
            else 
            {
                print("warning: left-hand-side of operator '<-' must be a function returning a function. subsequent build stages will fail.")
                return nil 
            }
            if function.throws 
            {
                print("warning: `throws` for method interface functions is not supported yet. subsequent build stages will fail.")
            }
            if function.parameters.contains(where: \.inout) 
            {
                print("warning: `inout` parameters for method interface functions are not supported yet. subsequent build stages will fail.")
            }
            
            return .init(function: 
                (
                    // first parameter must always be the delegate object, so we ignore it 
                    function.parameters.dropFirst().map(\.type),
                    function.return
                ), 
                unparameterized: ["T.Delegate"], 
                parameterPrefix: "U")
        })
        
        for parameterization:FunctionParameterization in parameterizations 
        {
            print("generating variadic template for generic function type '(T) -> \(parameterization)'")
            // TODO: implement me
        }
        
        Source.generate(file: staged) 
        {
            """
            // generated by '\(#file)'
            
            import GDNative
            
            func <- <T>(property:Godot.NativeScriptInterface<T>.Witness.Property, symbol:String) 
                -> Godot.NativeScriptInterface<T>.Member
                where T:Godot.NativeScript
            {
                .property(witness: property, symbol: symbol)
            }
            func <- <T>(method:@escaping Godot.NativeScriptInterface<T>.Witness.Method, symbol:String) 
                -> Godot.NativeScriptInterface<T>.Member
                where T:Godot.NativeScript
            {
                .method(witness: method, symbol: symbol)
            }
            
            """
            for (typename, symbols, _):(String, [String], [String]) in interface 
            {
                let _ = print("generating 'Godot.NativeScript' conformance for type '\(typename)'")
                // if `instance` is a class, this will simply produce the class instance pointer. 
                // if `instance` is a struct, which does not fit in the protocol-typed object’s
                // inline storage, the struct will be copied to a new allocation, which is 
                // then referred to in a class. this is not efficient, so use of `struct`s in 
                // godot-facing interfaces is discouraged.
                //
                //            `class`                                `struct`
                //       user-data pointer                      user-data pointer 
                //                ↓                                      ↓
                //         instance data                          storage pointer
                //                                                       ↓
                //                                                instance data
            """
            extension \(typename)
            {
                static 
                func register(with api:Godot.API.NativeScript) 
                {
                    let initializer:Godot.API.NativeScript.Initializer = 
                    {
                        (
                            delegate:UnsafeMutableRawPointer?, 
                            metadata:UnsafeMutableRawPointer?
                        ) -> UnsafeMutableRawPointer? in 
                        
                        guard let delegate:UnsafeMutableRawPointer = delegate 
                        else 
                        {
                            fatalError("(swift) \(typename).init(delegate:) received nil delegate pointer")
                        }
                        
                        #if ENABLE_ARC_SANITIZER
                        guard let metadata:UnsafeMutableRawPointer = metadata 
                        else 
                        {
                            fatalError("(swift) \(typename).init(delegate:) received nil metadata pointer")
                        }
                        
                        Unmanaged<\(typename).Interface.Metatype.Symbol>
                            .fromOpaque(metadata)
                            .takeUnretainedValue()
                            .track()
                        #endif
                        
                        return Unmanaged<AnyObject>.passRetained(
                            \(typename).init(delegate: .init(delegate)) as AnyObject).toOpaque() 
                    }
                    let deinitializer:Godot.API.NativeScript.Deinitializer =
                    {
                        (
                            delegate:UnsafeMutableRawPointer?, 
                            metadata:UnsafeMutableRawPointer?, 
                            instance:UnsafeMutableRawPointer?
                        ) in
                        
                        guard let instance:UnsafeMutableRawPointer = instance 
                        else 
                        {
                            fatalError("(swift) `\(typename).deinit` received nil instance pointer")
                        }
                        
                        #if ENABLE_ARC_SANITIZER
                        guard let metadata:UnsafeMutableRawPointer = metadata 
                        else 
                        {
                            fatalError("(swift) \(typename).deinit received nil metadata pointer")
                        }
                        
                        Unmanaged<\(typename).Interface.Metatype.Symbol>
                            .fromOpaque(metadata)
                            .takeUnretainedValue()
                            .untrack()
                        #endif
                        
                        Unmanaged<AnyObject>.fromOpaque(instance).release()
                    }
                    let dispatch:Godot.API.NativeScript.Method = 
                    {
                        (
                            delegate:UnsafeMutableRawPointer?, 
                            metadata:UnsafeMutableRawPointer?, 
                            instance:UnsafeMutableRawPointer?, 
                            count:Int32, 
                            arguments:UnsafeMutablePointer<UnsafeMutablePointer<godot_variant>?>?
                        ) -> godot_variant in 
                        
                        let index:Int   = .init(bitPattern: metadata)
                        let name:String = \(typename).interface[method: index].symbol
                        // unretained because godot retained `self` in the initializer call
                        guard   let instance:UnsafeMutableRawPointer = instance, 
                                let self:\(typename) = 
                                Unmanaged<AnyObject>.fromOpaque(instance).takeUnretainedValue() as? \(typename) 
                        else 
                        {
                            fatalError("(swift) \(typename).\\(name)(delegate:arguments:) received nil or invalid instance pointer")
                        }
                        
                        guard   let delegate:UnsafeMutableRawPointer = delegate 
                        else 
                        {
                            fatalError("(swift) \(typename).\\(name)(delegate:arguments:) received nil delegate pointer")
                        }
                        
                        let variants:[Godot.Variant?]
                        if let arguments:UnsafeMutablePointer<UnsafeMutablePointer<godot_variant>?> = arguments 
                        {
                            variants = (0 ..< .init(count)).map 
                            {
                                guard let pointer:UnsafeMutablePointer<godot_variant> = arguments[$0]
                                else 
                                {
                                    fatalError("(swift) \(typename).\\(name)(delegate:arguments:) received nil argument pointer")
                                }
                                
                                return Godot.Variant.Unmanaged.takeUnretainedValue(from: pointer)
                            }
                        }
                        else 
                        {
                            variants = []
                        }
                        
                        return \(typename).interface[method: index].witness(self)(.init(delegate), variants)?.passRetainedUnsafeData() ?? .init()
                    }
                    
                    let symbols:[String] = [\(symbols.map{ "\"\($0)\"" }.joined(separator: ", "))]
                    
                    #if ENABLE_ARC_SANITIZER
                    let sanitizer:Godot.API.NativeScript.WitnessDeinitializer = 
                    {
                        (metadata:UnsafeMutableRawPointer?) in 
                        
                        guard let metadata:UnsafeMutableRawPointer = metadata 
                        else 
                        {
                            fatalError("(swift) \(typename).sanitizer received nil metadata pointer")
                        }
                        
                        Unmanaged<\(typename).Interface.Metatype.Symbol>
                            .fromOpaque(metadata)
                            .release()
                    }
                    
                    let metatype:\(typename).Interface.Metatype = .init(symbols: symbols)
                    
                    #else 
                    let sanitizer:Godot.API.NativeScript.WitnessDeinitializer? = nil
                    #endif
                    
                    for symbol:String in symbols
                    {
                        // register type 
                        #if ENABLE_ARC_SANITIZER
                        let metadata:UnsafeMutableRawPointer  = 
                            Unmanaged<\(typename).Interface.Metatype.Symbol>
                            .passRetained(.init(symbol, metatype: metatype))
                            .toOpaque()
                        #else 
                        let metadata:UnsafeMutableRawPointer? = nil
                        #endif
                        
                        let constructor:godot_instance_create_func = .init(
                            create_func:    initializer, method_data: metadata, free_func: sanitizer)
                        let destructor:godot_instance_destroy_func = .init(
                            destroy_func: deinitializer, method_data: metadata, free_func: nil)
                        
                        api.register(initializer: constructor, deinitializer: destructor, 
                            for: Self.self, as: symbol)
                        
                        // register methods 
                        for index:Int in Self.interface.methods.indices  
                        {
                            let method:godot_instance_method = .init(
                                method:         dispatch, 
                                method_data:   .init(bitPattern: index), 
                                free_func:      nil)
                            
                            api.register(method: method, 
                                as: (type: symbol, method: Self.interface[method: index].symbol)) 
                        }
                    }
                }
            }
            """
            }
        }
    }
}

#endif
