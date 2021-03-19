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
    enum Form:Hashable  
    {
        struct Parameter:Hashable 
        {
            let `inout`:Bool 
            let type:Form 
            //let variadic:Bool
        }
        
        case scalar 
        case compound([Self])
        
        init(_ type:SwiftGrammar.SwiftType) 
        {
            switch type 
            {
            case .compound(let elements):
                self = .compound(elements.map{ Self.init($0.type) })
            default:
                self = .scalar 
            }
        }
        
        func tree(prefix:String = "", counter:Int, suffix:String = "") -> String 
        {
            var counter:Int = counter 
            return self.tree(prefix: prefix, counter: &counter, suffix: suffix)
        }
        func tree(prefix:String = "", counter:inout Int, suffix:String = "") -> String 
        {
            switch self 
            {
            case .scalar: 
                defer 
                {
                    counter += 1
                }
                return "\(prefix)\(counter)\(suffix)"
            case .compound(let elements):
                var components:[String] = []
                for element:Self in elements 
                {
                    components.append(element.tree(
                        prefix: prefix, counter: &counter, suffix: suffix))
                }
                return "(\(components.joined(separator: ", ")))"
            }
        }
    }
}
extension Synthesizer.Form 
{
    func prebind(expression:String, to variable:String, counter:inout Int, depth:Int = 0)
        -> String 
    {
        switch self 
        {
        case .scalar:
            defer 
            {
                counter += 1
            }
            @Source.Code 
            var code:String
            {
                if depth == 0 
                {
            """
                    let \(variable):Godot.Variant.Unmanaged = \(expression).variant 
            """
                }
                else 
                {
            """
                    let \(variable):Godot.Variant = 
                    {
                        var unmanaged:Godot.Variant.Unmanaged = \(expression).variant
                        return unmanaged.takeRetainedValue() 
                    }()
            """
                }
            }
            return code 
        case .compound(let elements):
            @Source.Code 
            var code:String
            {
                var variables:[String] = []
                for (i, element):(Int, Self) in elements.enumerated()
                {
                    let variable:String = "l\(depth)m\(counter)"
                    let _               = variables.append(variable)
                    element.prebind(expression: "\(expression).\(i)", 
                        to:      variable, 
                        counter: &counter, 
                        depth:   depth + 1)
                }
            """
                    let \(depth == 0 ? "list" : variable):Godot.List = 
                    [
            """
                for variable:String in variables 
                {
            """
                        \(variable),
            """
                }
            """
                    ]
            """
                if depth == 0 
                {
            """
                    let \(variable):Godot.Variant.Unmanaged = list.passRetained()
            """
                }
            }
            return code
        }
    }
    
    func postbind(expression:(conversion:(String) -> String, variant:String), to variable:String, 
        prefix:String, counter:inout Int, depth:Int = 0)
        -> String 
    {
        let expected:String = "\(self.tree(prefix: prefix, counter: counter)).self"
        switch self 
        {
        case .scalar:
            defer 
            {
                counter += 1
            }
            @Source.Code 
            var code:String
            {
            """
                    if let value:\(prefix)\(counter) = \(expression.conversion("\(prefix)\(counter)")) 
                    {
                        \(variable) = value 
                    }
                    else 
                    {
                        Godot.print(error: Godot.Error.invalidArgument(\(expression.variant), expected: \(expected)), 
                            function: symbol)
                        return .init()
                    }
            """
            }
            return code 
        case .compound(let elements):
            @Source.Code 
            var code:String
            {
                let list:String = "l\(depth)m\(counter)"
            """
                    guard let \(list):Godot.List = \(expression.conversion("Godot.List")) 
                    else 
                    {
                        Godot.print(error: Godot.Error.invalidArgument(\(expression.variant), expected: \(expected)), 
                            function: symbol)
                        return .init()
                    }
                    guard \(list).count == \(elements.count) 
                    else 
                    {
                        Godot.print(error: Godot.Error.invalidArgumentTuple(\(list.count), expected: \(expected)), 
                            function: symbol)
                        return .init()
                    }
            """
                for (i, element):(Int, Self) in elements.enumerated()
                {
                    element.postbind(expression: 
                        (
                        {   "\(list)[\(i)].pass(\($0).init(variant:))" },
                            "\(list)[\(i)]"    
                        ), 
                        to: "\(variable).\(i)", 
                        prefix:  prefix, 
                        counter: &counter, 
                        depth:   depth + 1)
                }
            }
            return code 
        }
    }
} 
extension Synthesizer 
{
    struct FunctionParameterization:Hashable
    {
        private 
        let exclude:String
        private 
        let domain:[Form.Parameter], 
            range:Form 
        
        init(function:SwiftGrammar.FunctionType, exclude:String)   
        {
            // `exclude` specifies a leading (unparameterized) type to append to 
            //  the parameters tuple
            self.exclude    = exclude 
            self.domain     = function.parameters.dropFirst().map 
            {
                .init(`inout`: $0.inout, type: .init($0.type))
            }
            self.range      = .init(function.return)
        }
    }
}
extension Synthesizer.FunctionParameterization
{
    func generateBindingOperatorOverload(prefix:(domain:String, range:String) = ("U", "V")) -> String
    {
        var counter:(domain:Int, range:Int) = (0, 0)
        var signature:(domain:[String], range:String, function:String) 
        signature.range     = self.range.tree(prefix: prefix.range, counter: &counter.range)
        signature.domain    = [self.exclude]
        
        var types:[String]  = []
        for parameter:Synthesizer.Form.Parameter in self.domain 
        {
            let type:String = parameter.type.tree(prefix: prefix.domain, counter: &counter.domain)
            types.append(type)
            signature.domain.append("\(parameter.inout ? "inout " : "")\(type)")
        }
        signature.function = "(T) -> (\(signature.domain.joined(separator: ", "))) -> \(signature.range)"
        
        print("generating variadic template for generic function type '\(signature.function)'")
        
        @Source.Code 
        var code:String 
        {
            let generics:[(parameter:String, constraint:String)] = 
                [("T", ":Godot.NativeScript")] 
                +
                (0 ..< counter.domain).map{ ("\(prefix.domain)\($0)", ":Godot.VariantRepresentable") }
                +
                (0 ..< counter.range).map{  ("\(prefix.range)\($0)",  ":Godot.VariantRepresentable") }
        """
        func <- <\(generics.map(\.parameter).joined(separator: ", "))>
            (method:@escaping \(signature.function), symbol:String) 
            -> Godot.NativeScriptInterface<T>.Member
            where \(generics.map 
                {
                    "\($0.parameter)\($0.constraint)"
                }.joined(separator: ",\n        "))
        {
            .method(witness: 
            {
                (self:T, delegate:\(self.exclude), arguments:[Godot.Variant.Unmanaged]) -> Godot.Variant.Unmanaged in
                
                guard arguments.count == \(self.domain.count) 
                else 
                {
                    Godot.print(error: Godot.Error.invalidArgumentCount(arguments.count, expected: \(self.domain.count)), 
                        function: symbol)
                    return .init()
                }
        """
            var inputs:[String] = ["delegate"]
            if !self.domain.isEmpty 
            {
        """
                var inputs:(\((types + ["Void"]).joined(separator: ", ")))
        """
                // trailing `Void` ensures tuple always has at least 2 elements
                
                var counter:(domain:Int, range:Int) = (0, 0)
                for (position, parameter):(Int, Synthesizer.Form.Parameter) in self.domain.enumerated() 
                {
                    let expression:(conversion:(String) -> String, variant:String) = 
                    (
                    {   "\($0).init(variant: arguments[\(position)])" }, 
                                            "arguments[\(position)].takeUnretainedValue()"
                    )
                    
                    let _ = inputs.append("\(parameter.inout ? "&" : "")inputs.\(position)")
        """
        \(parameter.type.postbind(expression: expression, to: "inputs.\(position)", 
                    prefix:     prefix.domain, 
                    counter:    &counter.domain))
        """
                }
            }
        """
                let output:\(signature.range) = method(self)(\(inputs.joined(separator: ", ")))
        \(self.range.prebind(expression: "output", to: "result", 
                    counter: &counter.range))
                return result 
            }, symbol: symbol)
        }
        """
        }
        return code
    }
}

extension Synthesizer 
{
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
            
            return .init(function: function, exclude: "T.Delegate")
        })
        
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
            
            """

            for parameterization:FunctionParameterization in parameterizations 
            {
                parameterization.generateBindingOperatorOverload()
            }
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
                        
                        let variants:[Godot.Variant.Unmanaged]
                        if let arguments:UnsafeMutablePointer<UnsafeMutablePointer<godot_variant>?> = arguments 
                        {
                            variants = (0 ..< .init(count)).map 
                            {
                                guard let pointer:UnsafeMutablePointer<godot_variant> = arguments[$0]
                                else 
                                {
                                    fatalError("(swift) \(typename).\\(name)(delegate:arguments:) received nil argument pointer")
                                }
                                
                                return .init(data: pointer.pointee)
                            }
                        }
                        else 
                        {
                            variants = []
                        }
                        
                        return \(typename).interface[method: index].witness(self, .init(delegate), variants).unsafeData
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
