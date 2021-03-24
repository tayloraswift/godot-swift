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
        
        // store the type names. they can be computed on the fly, but this 
        // makes the implementation much simpler
        case void
        case tuple([Self])
        case scalar(type:String) 
        
        init(_ type:SwiftGrammar.SwiftType, prefix:String, start:Int = 0) 
        {
            var counter:Int = start 
            self.init(type, prefix: prefix, counter: &counter)
        }
        init(_ type:SwiftGrammar.SwiftType, prefix:String, counter:inout Int) 
        {
            switch type 
            {
            case .compound(let types):
                guard !types.isEmpty 
                else 
                {
                    self = .void 
                    break 
                }
                
                var elements:[Self] = []
                for type:SwiftGrammar.SwiftType in types.map(\.type)  
                {
                    elements.append(Self.init(type, prefix: prefix, counter: &counter))
                }
                self = .tuple(elements)
            
            default:
                self = .scalar(type: "\(prefix)\(counter)")
                counter += 1 
            }
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
        
        // `exclude` specifies a leading (unparameterized) type to append to 
        //  the parameters tuple
        init(function:SwiftGrammar.FunctionType, exclude:String, 
            prefix:(domain:String, range:String))   
        {
            var domain:[Form.Parameter] = [], 
                counter:Int             = 0
            for parameter:SwiftGrammar.FunctionParameter in function.parameters.dropFirst()
            {
                domain.append(.init(`inout`: parameter.inout, 
                    type: .init(parameter.type, prefix: prefix.domain, counter: &counter)))
            }
            self.exclude    = exclude 
            self.domain     = domain
            self.range      = .init(function.return, prefix: prefix.range)
        }
    }
}


extension Synthesizer.Form 
{
    var types:[String] 
    {
        switch self 
        {
        case .scalar(type: let type):
            return [type]
        case .void: 
            return []
        case .tuple(let elements):
            return elements.flatMap(\.types)
        }
    }
    
    static 
    func tree(_ root:Self) -> String 
    {
        switch root 
        {
        case .scalar(type: let type):    
            return type
        case .void: 
            return "Void"
        case .tuple(let elements):
            return "(\(elements.map(Self.tree(_:)).joined(separator: ", ")))"
        }
    }
    
    func structure(nodes list:String, from variable:String) -> String 
    {
        switch self 
        {
        case .void, .scalar(type: _):
            return Source.fragment
            {
                ".pass(retained: \(variable))" 
            }
        case .tuple(let elements):
            return Source.fragment
            {
                ".pass(retained: \(list).init(consuming: "
                Source.fragment(indent: 1) 
                {
                    elements.enumerated().map
                    {
                        $0.1.structure(nodes: list, from: "\(variable).\($0.0)")
                    }.joined(separator: ", \n")
                }
                "))"
            }
        }
    }
    
    func update(nodes list:String, in variable:(base:String, path:String), at position:Int) -> String 
    {
        switch self 
        {
        case .void:
            return ""
        case .scalar(type: _):
            return "\(variable.base).\(list)\(variable.path).\(list)[unmanaged: \(position)].assign(retained: \(variable.base)\(variable.path).\(position))"
        case .tuple(let elements):
            return Source.fragment 
            {
                for (i, element):(Int, Self) in elements.enumerated()
                {
                    element.update(nodes: list, in: (variable.base, "\(variable.path).\(position)"), at: i)
                }
            }
        }
    }
    
    func destructure(nodes list:(root:String, label:String, type:String), 
        into variable:(base:String, path:String), at position:Int, mutable:Bool) 
        -> String 
    {
        switch self 
        {
        case .void:
            return Source.fragment
            {
                """
                if let value:Void = \(list.root)[unmanaged: \(position)].take(unretained: Void.self)
                {
                    \(variable.base)\(variable.path).\(position) = value 
                }
                else 
                {
                    Godot.print(error: Godot.Error.invalidArgument(\(list.root)[\(position)], expected: Void.self), 
                        function: symbol)
                    return .pass(retained: ())
                }
                """
            }
        case .scalar(type: let type):
            return Source.fragment
            {
                """
                if let value:\(type) = \(list.root)[unmanaged: \(position)].take(unretained: \(type).self)
                {
                    \(variable.base)\(variable.path).\(position) = value 
                }
                else 
                {
                    Godot.print(error: Godot.Error.invalidArgument(\(list.root)[\(position)], expected: \(type).self), 
                        function: symbol)
                    return .pass(retained: ())
                }
                """
            }
        case .tuple(let elements):
            return Source.fragment
            {
                """
                if let \(list.root):\(list.type) = \(list.root)[unmanaged: \(position)].take(unretained: \(list.type).self)
                {
                """
                Source.fragment(indent: 1) 
                {
                    if mutable 
                    {
                        "\(variable.base).\(list.label)\(variable.path).\(position).\(list.label) = \(list.root)"
                    }
                    for (i, element):(Int, Self) in elements.enumerated()
                    {
                        element.destructure(nodes: list, 
                            into: (variable.base, "\(variable.path).\(position)"), 
                            at: i, mutable: mutable)
                    }
                }
                """
                }
                else 
                {
                    Godot.print(error: Godot.Error.invalidArgument(\(list.root)[\(position)], expected: \(list.type).self), 
                        function: symbol)
                    return .pass(retained: ())
                }
                """
            }
        }
    }
}
extension Synthesizer.Form.Parameter 
{
    static 
    func tree(_ domain:[Self], nodes list:(label:String, type:String)) -> String? 
    {
        func lists(root:Synthesizer.Form) -> String 
        {
            switch root 
            {
            case .void, .scalar(type: _): 
                return "Void"
            case .tuple(let elements):
                return "(\(elements.map{ lists(root: $0) }.joined(separator: ", ")), \(list.label):\(list.type))"
            }
        }
        
        let body:String = domain.map{ Synthesizer.Form.tree($0.type) }.joined(separator: ", ")
        let tail:String = domain.map{ $0.inout ? lists(root: $0.type) : "Void" }.joined(separator: ", ")
        if domain.isEmpty 
        {
            return nil 
        }
        return Source.fragment 
        {
            if domain.contains(where: \.inout) 
            {
                """
                (
                    \(body), 
                    \(list.label):
                    (\(tail), \(list.label):Godot.VariadicArguments)
                )
                """
            }
            else 
            {
                """
                (
                    \(body), 
                    \(list.label):Void
                )
                """
            }
        }
    }
}
extension Synthesizer.FunctionParameterization
{
    var signature:String 
    {
        let domain:[String] = [self.exclude] + self.domain.map 
        {
            "\($0.inout ? "inout " : "")\(Synthesizer.Form.tree($0.type))"
        }
        let range:String = Synthesizer.Form.tree(self.range)
        return "(\(domain.joined(separator: ", "))) -> \(range)"
    }
    
    private 
    var generics:[String] 
    {
        self.domain.flatMap(\.type.types) + self.range.types
    }
    
    private 
    func call(_ name:String, with variable:(delegate:String, inputs:String)) -> String 
    {
        """
        \(name)(self)(\(
        ([variable.delegate] + self.domain.enumerated().map 
        {
            "\($0.1.inout ? "&" : "")\(variable.inputs).\($0.0)"
        }).joined(separator: ", ")))
        """
    }
    
    func generateBindingOperatorOverload() -> String
    {
        let signature:String = "(T) -> \(self.signature)"
        let generics:[(parameter:String, constraint:String)] = 
            [("T", ":Godot.NativeScript")] 
            +
            self.generics.map{ ($0, ":Godot.VariantRepresentable") }
        
        print("generating variadic template for generic function type '\(signature)'")
        
        return Source.fragment
        {
            """
            func <- <\(generics.map(\.parameter).joined(separator: ", "))>
                (method:@escaping \(signature), symbol:String) 
                -> Godot.NativeScriptInterface<T>.Member
                where \(generics.map 
                    {
                        "\($0.parameter)\($0.constraint)"
                    }.joined(separator: ",\n        "))
            {
                .method(witness: 
                {
            """
            Source.fragment(indent: 2) 
            {
                """
                (self:T, delegate:\(self.exclude), arguments:Godot.VariadicArguments) 
                    -> Godot.Variant.Unmanaged in
                
                guard arguments.count == \(self.domain.count) 
                else 
                {
                    Godot.print(error: Godot.Error.invalidArgumentCount(arguments.count, expected: \(self.domain.count)), 
                        function: symbol)
                    return .pass(retained: ())
                }
                """
                
                if let domain:String = 
                    Synthesizer.Form.Parameter.tree(self.domain, nodes: ("list", "Godot.List"))
                {
                    if self.domain.contains(where: \.inout) 
                    {
                        """
                        
                        var inputs:
                        \(domain)
                        
                        inputs.list.list = arguments
                        
                        """
                    }
                    else 
                    {
                        """
                        
                        let inputs:
                        \(domain)
                        
                        """
                    }
                }
                for (position, parameter):(Int, Synthesizer.Form.Parameter) in 
                    self.domain.enumerated() 
                {
                    parameter.type.destructure(nodes: ("arguments", "list", "Godot.List"), 
                        into: ("inputs", ""), at: position, mutable: parameter.inout)
                }
                
                """
                
                let output:\(Synthesizer.Form.tree(self.range)) = \(self.call("method", with: ("delegate", "inputs")))
                
                """
                
                for (position, parameter):(Int, Synthesizer.Form.Parameter) in 
                    self.domain.enumerated() 
                    where parameter.inout 
                {
                    parameter.type.update(nodes: "list", in: ("inputs", ""), at: position)
                }
                """
                return \(self.range.structure(nodes: "Godot.List", from: "output"))
                """
            }
            """
                }, symbol: symbol)
            }
            """
        }
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
            if function.parameters.contains(where: \.variadic) 
            {
                print("warning: swift cannot recieve variadic arguments dynamically. subsequent build stages will fail.")
            }
            
            return .init(function: function, exclude: "T.Delegate", prefix: ("U", "V"))
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
            
            // sort by function signatures, to provide some stability in the 
            // generated code. precompute the signatures to prevent O(n log n) 
            // signature computations
            for parameterization:FunctionParameterization in (parameterizations
                .map{ (function: $0, signature: $0.signature) }
                .sorted{ $0.signature < $1.signature }
                .map(\.function))
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
                            metatype:UnsafeMutableRawPointer?
                        ) -> UnsafeMutableRawPointer? in 
                        
                        \(typename).Interface.initialize(delegate: delegate, metatype: metatype)
                    }
                    let deinitializer:Godot.API.NativeScript.Deinitializer =
                    {
                        (
                            delegate:UnsafeMutableRawPointer?, 
                            metatype:UnsafeMutableRawPointer?, 
                            instance:UnsafeMutableRawPointer?
                        ) in
                        
                        \(typename).Interface.deinitialize(instance: instance, metatype: metatype)
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
                        
                        \(typename).interface.call(
                            method:    .init(bitPattern: metadata), 
                            instance:   instance, 
                            delegate:   delegate, 
                            arguments: (arguments, .init(count)))
                    }
                    
                    let unregister:Godot.API.NativeScript.WitnessDeinitializer = 
                    {
                        (metatype:UnsafeMutableRawPointer?) in 
                        
                        guard let metatype:UnsafeMutableRawPointer = metatype 
                        else 
                        {
                            fatalError("(swift) \(typename).sanitizer received nil metatype pointer")
                        }
                        
                        Unmanaged<Godot.Metatype>.fromOpaque(metatype).release()
                    }
                    
                    let symbols:[String] = [\(symbols.map{ "\"\($0)\"" }.joined(separator: ", "))]
                    #if ENABLE_ARC_SANITIZER
                    let tracker:Godot.Metatype.RetainTracker = 
                        .init(type: \(typename).self, symbols: symbols)
                    #endif
                    
                    for symbol:String in symbols
                    {
                        // register type 
                        #if ENABLE_ARC_SANITIZER
                        let metatype:UnsafeMutableRawPointer = Unmanaged<Godot.Metatype>
                            .passRetained(.init(symbol: symbol, tracker: tracker))
                            .toOpaque()
                        #else 
                        let metatype:UnsafeMutableRawPointer = Unmanaged<Godot.Metatype>
                            .passRetained(.init(symbol: symbol))
                            .toOpaque()
                        #endif
                        
                        let constructor:godot_instance_create_func = .init(
                            create_func:    initializer, method_data: metatype, free_func: unregister)
                        let destructor:godot_instance_destroy_func = .init(
                            destroy_func: deinitializer, method_data: metatype, free_func: nil)
                        
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
