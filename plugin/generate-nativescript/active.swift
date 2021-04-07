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

final 
class Diagnostics 
{
    final 
    class Delegate<Context> 
    {
        let diagnostics:Diagnostics 
        let context:Context 
        
        init(_ diagnostics:Diagnostics, context:Context)
        {
            self.diagnostics    = diagnostics 
            self.context        = context
        }
    }
    
    enum Diagnostic 
    {
        case error(String)
        case warning(String)
        case note(String)
        
        func plant() -> String 
        {
            switch self 
            {
            case .error     (let message): return 
                """
                #error(
                "\(message)"
                )
                """
            case .warning   (let message): return 
                """
                #warning(
                "\(message)"
                )
                """
            // no swift support for #message yet, unfortunately
            case .note      (let message): return 
                """
                #warning(
                "note: \(message)"
                )
                """
            }
        }
    }
    
    private
    var diagnostics:[Diagnostic] 
    
    init()
    {
        self.diagnostics = []
    }
    
    func with<R, Context>(context:Context, _ body:(Delegate<Context>) throws -> R) 
        rethrows -> R 
    {
        try body(.init(self, context: context))
    }
    
    func emit(_ diagnostic:Diagnostic) 
    {
        self.diagnostics.append(diagnostic)
    }
    
    func plant() -> String 
    {
        Source.fragment 
        {
            for diagnostic:Diagnostic in self.diagnostics 
            {
                diagnostic.plant()
            }
        }
    }
}
extension Diagnostics.Delegate 
{
    func with<R, Next>(context:Next, _ body:(Diagnostics.Delegate<Next>) throws -> R) 
        rethrows -> R 
    {
        try body(.init(self.diagnostics, context: context))
    }
    
    func error(_ message:(Context) -> String)
    {
        self.diagnostics.emit(.error(message(self.context)))
    }
    func warning(_ message:(Context) -> String)
    {
        self.diagnostics.emit(.warning(message(self.context)))
    }
    func note(_ message:(Context) -> String)
    {
        self.diagnostics.emit(.note(message(self.context)))
    }
}

// diagnostic helpers 
extension SwiftGrammar.SwiftType 
{
    func match(vector arity:Int) -> String? 
    {
        if  case .named(let identifiers)                = self,
            let head:SwiftGrammar.TypeIdentifier        = identifiers.first, 
            identifiers.dropFirst().isEmpty, 
            head.identifier == "Vector", 
            let storage:SwiftGrammar.SwiftType          = head.generics.first, 
            let _:SwiftGrammar.SwiftType                = head.generics.dropFirst().first, 
            head.generics.dropFirst(2).isEmpty, 
            
            case .named(let storageIdentifiers)         = storage, 
            let storageHead:SwiftGrammar.TypeIdentifier = storageIdentifiers.first, 
            storageIdentifiers.dropFirst().isEmpty, 
            storageHead.identifier == "SIMD\(arity)", 
            let scalar:SwiftGrammar.SwiftType           = storageHead.generics.first, 
            storageHead.generics.dropFirst().isEmpty 
        {
            return "\(scalar)" 
        }
        else 
        {
            return nil 
        }
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
        
        init(_ type:SwiftGrammar.SwiftType, prefix:String, start:Int = 0, 
            diagnostics:Diagnostics.Delegate<(typename:String, signature:SwiftGrammar.SwiftType, component:String)>) 
        {
            var counter:Int = start 
            self.init(type, prefix: prefix, counter: &counter, diagnostics: diagnostics)
        }
        init(_ type:SwiftGrammar.SwiftType, prefix:String, counter:inout Int, 
                diagnostics:Diagnostics.Delegate<(typename:String, signature:SwiftGrammar.SwiftType, component:String)>) 
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
                    elements.append(Self.init(type, prefix: prefix, counter: &counter, 
                        diagnostics: diagnostics))
                }
                
                // diagnose possible problems with “naked” matrices 
                diagnostics:
                if types.compactMap(\.label).isEmpty
                {
                    let scalars:(vector2:[String], vector3:[String]) = 
                    (
                        types.compactMap{ $0.type.match(vector: 2) },
                        types.compactMap{ $0.type.match(vector: 3) }
                    )
                    if  let scalar:String = scalars.vector2.first, 
                            Set<String>.init(scalars.vector2).count == 1,
                            scalars.vector2.count == 3, 
                            types.count == 3 
                    {
                        diagnostics.warning
                        {
                            _ in 
                            """
                            inferred gdscript for type \
                            'Vector2<\(scalar)>.Matrix3' will be a 'Godot::Array' \
                            of \(types.count) 'Vector2<\(scalar)>'s
                            """
                        }
                        diagnostics.note
                        {
                            _ in 
                            """
                            explicitly wrap the 'Vector2<\(scalar)>.Matrix3' in a \ 
                            'Godot.Transform2.Affine' container to specify a type \
                            of 'Godot::Transform2D'
                            """
                        }
                    }
                    else if let scalar:String = scalars.vector3.first, 
                            Set<String>.init(scalars.vector3).count == 1,
                            scalars.vector3.count == 3, 
                            types.count == 3 
                    {
                        diagnostics.warning
                        {
                            _ in 
                            """
                            inferred gdscript type for type \
                            'Vector3<\(scalar)>.Matrix' will be a 'Godot::Array' \
                            of \(types.count) 'Vector3<\(scalar)>'s
                            """
                        }
                        diagnostics.note
                        {
                            _ in
                            """
                            explicitly wrap the 'Vector3<\(scalar)>.Matrix' in a \ 
                            'Godot.Transform3.Linear' container to specify a type \
                            of 'Godot::Basis'
                            """
                        }
                    }
                    else if let scalar:String = scalars.vector3.first, 
                            Set<String>.init(scalars.vector3).count == 1,
                            scalars.vector3.count == 4, 
                            types.count == 4 
                    {
                        diagnostics.warning
                        {
                            _ in 
                            """
                            inferred gdscript type for type \
                            'Vector3<\(scalar)>.Matrix4' will be a 'Godot::Array' \
                            of \(types.count) 'Vector3<\(scalar)>'s
                            """
                        }
                        diagnostics.note
                        {
                            _ in 
                            """
                            explicitly wrap the 'Vector3<\(scalar)>.Matrix4' in a \ 
                            'Godot.Transform3.Affine' container to specify a type \
                            of 'Godot::Transform'
                            """
                        }
                    }
                    else 
                    {
                        break diagnostics
                    }
                    
                    diagnostics.note
                    { 
                        "in \($0.component) of function(s) with type '\($0.signature)'"
                    }
                    diagnostics.note 
                    {
                        "in interface definition for type '\($0.typename)'"
                    }
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
            prefix:(domain:String, range:String), 
            diagnostics:Diagnostics.Delegate<(typename:String, signature:SwiftGrammar.SwiftType)>)   
        {
            var domain:[Form.Parameter] = [], 
                counter:Int             = 0
            for (i, parameter):(Int, SwiftGrammar.FunctionParameter) in 
                function.parameters.enumerated().dropFirst()
            {
                diagnostics.with(context: 
                    (
                        typename:   diagnostics.context.typename, 
                        signature:  diagnostics.context.signature, 
                        component: "parameter #\(i)"
                    )) 
                {
                    domain.append(.init(`inout`: parameter.inout, type: 
                        .init(parameter.type, prefix: prefix.domain, counter: &counter, diagnostics: $0)))
                }
            }
            self.exclude    = exclude 
            self.domain     = domain
            self.range      = diagnostics.with(context: 
                (
                    typename:   diagnostics.context.typename, 
                    signature:  diagnostics.context.signature, 
                    component: "return value"
                )) 
            {
                .init(function.return, prefix: prefix.range, diagnostics: $0)
            }
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
        let diagnostics:Diagnostics = .init()
        let parameterizations:Set<FunctionParameterization> = 
            .init(interface.flatMap
        {
            (interface:(typename:String, symbols:[String], signatures:[String])) -> [FunctionParameterization] in 
            
            interface.signatures.compactMap  
            {
                (signature:String) in 
                
                guard let type:SwiftGrammar.SwiftType = .init(parsing: signature)
                else 
                {
                    print("error: failed to parse signature '\(signature)'")
                    return nil 
                }
                
                return diagnostics.with(context: (typename: interface.typename, signature: type))
                {
                    (diagnostics:Diagnostics.Delegate<(typename:String, signature:SwiftGrammar.SwiftType)>) 
                        -> FunctionParameterization? in 
                    
                    guard case .function(let function) = type 
                    else 
                    {
                        diagnostics.error 
                        {
                            """
                            function bound by operator '<-' must return a function type (return type is '\($0.signature)').
                            """
                        }
                        diagnostics.note 
                        {
                            "in interface definition for type '\($0.typename)'"
                        }
                        return nil 
                    }
                    if function.throws 
                    {
                        diagnostics.error 
                        {
                            """
                            operator '<-' cannot bind function of type '\($0.signature)' \
                            (`throws` for method interface functions is not supported yet)
                            """
                        }
                        diagnostics.note 
                        {
                            "in interface definition for type '\($0.typename)'"
                        }
                    }
                    if function.parameters.contains(where: \.variadic) 
                    {
                        diagnostics.error 
                        {
                            """
                            operator '<-' cannot bind function of type '\($0.signature)' \
                            (swift cannot recieve variadic arguments dynamically)
                            """
                        }
                        diagnostics.note 
                        {
                            "in interface definition for type '\($0.typename)'"
                        }
                    }
                    
                    return .init(function: function, exclude: "T.Delegate", prefix: ("U", "V"), 
                        diagnostics: diagnostics)
                }
            }
        })
        
        Source.generate(file: staged) 
        {
            """
            // generated by '\(#file)'
            """
            diagnostics.plant()
            """
            
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
            for typename:String in interface.map(\.typename) 
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
                func register(_ symbols:[String], with api:Godot.Library) 
                {
                    let initializer:Godot.Library.Initializer = 
                    {
                        (
                            delegate:UnsafeMutableRawPointer?, 
                            metadata:UnsafeMutableRawPointer?
                        ) -> UnsafeMutableRawPointer? in 
                        
                        \(typename).Interface.initialize(delegate: delegate, metadata: metadata)
                    }
                    let deinitializer:Godot.Library.Deinitializer =
                    {
                        (
                            delegate:UnsafeMutableRawPointer?, 
                            metadata:UnsafeMutableRawPointer?, 
                            instance:UnsafeMutableRawPointer?
                        ) in
                        
                        \(typename).Interface.deinitialize(instance: instance, metadata: metadata)
                    }
                    let dispatch:Godot.Library.Dispatcher = 
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
                    
                    let unregister:Godot.Library.WitnessDeinitializer = 
                    {
                        (metadata:UnsafeMutableRawPointer?) in 
                        
                        guard let metadata:UnsafeMutableRawPointer = metadata 
                        else 
                        {
                            fatalError("(swift) \(typename).sanitizer received nil metadata pointer")
                        }
                        
                        Unmanaged<Godot.NativeScriptMetadata>.fromOpaque(metadata).release()
                    }
                    
                    #if ENABLE_ARC_SANITIZER
                    let tracker:Godot.RetainTracker = 
                        .init(type: \(typename).self, symbols: symbols)
                    #endif
                    
                    for symbol:String in symbols
                    {
                        // register type 
                        #if ENABLE_ARC_SANITIZER
                        let metadata:UnsafeMutableRawPointer = Unmanaged<Godot.NativeScriptMetadata>
                            .passRetained(.init(symbol: symbol, tracker: tracker))
                            .toOpaque()
                        #else 
                        let metadata:UnsafeMutableRawPointer = Unmanaged<Godot.NativeScriptMetadata>
                            .passRetained(.init(symbol: symbol))
                            .toOpaque()
                        #endif
                        
                        let constructor:godot_instance_create_func = .init(
                            create_func:    initializer, method_data: metadata, free_func: unregister)
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
