import ArgumentParser
import PackageModel
import PackageLoading
import TSCBasic
import TSCUtility

extension Main.Synthesizer 
{
    enum Error:Swift.Error 
    {
        case subBuildFailed
        case couldNotOpenSubBuildProduct(String)
        case missingSubBuildProductSymbol(String)
        case invalidSubBuildInterfaceFormat(Any.Type, expected:Any.Type)
    }
    
    struct Interface:Codable  
    {
        typealias Tuple = 
        (
            // `classes` used for `library.json`
            type:String, 
            classes:[String], 
            properties:Int,
            methods:[String],
            signals:[String]
        )
        
        let type:String 
        let classes:[String]
        let properties:Int 
        let methods:[String]
        let signals:[String]
        
        init(_ tuple:Tuple)
        {
            self.type       = tuple.type 
            self.classes    = tuple.classes 
            self.properties = tuple.properties 
            self.methods    = tuple.methods 
            self.signals    = tuple.signals
        }
        
        static 
        let entrypoint:String = "__inspector_entrypoint_loader__"
    }
}

#if !BUILD_STAGE_INERT 

import Workspace

extension Main.Synthesizer.Interface:CustomStringConvertible 
{
    var description:String 
    {
        """
        \(self.type) <- (\(self.classes.map{ "Godot::\($0)" }.joined(separator: ", ")))
        {
            (\(self.properties) \(self.properties       == 1 ? "property" : "properties"))
            (\(self.methods.count) \(self.methods.count == 1 ? "method" : "methods"))
            (\(self.signals.count) \(self.signals.count == 1 ? "signal" : "signals"))
        }
        """
    }
}
extension Main.Synthesizer.Interface 
{
    private final 
    class OutputBuffer 
    {
        private 
        var buffered:String 
        
        init()
        {
            self.buffered = ""
        }
        
        func push(utf8:[UInt8]) 
        {
            let lines:[Substring] = "\(self.buffered)\(String.init(decoding: utf8, as: Unicode.UTF8.self))"
                .split(separator: "\n", omittingEmptySubsequences: false)
            guard let last:Substring = lines.last 
            else 
            {
                return 
            }
            self.buffered = .init(last)
            for line:Substring in lines.dropLast()
            {
                print("(sub-build)".bolded, line)
            }
        }
        
        func flush()
        {
            guard !self.buffered.isEmpty 
            else 
            {
                return 
            }
            
            print("(sub-build)".bolded, self.buffered)
            
            self.buffered = ""
        }
    }
    
    static 
    func load(inspecting dependency:(package:String, product:String, path:AbsolutePath), 
        workspace:AbsolutePath, toolchain:AbsolutePath) 
        throws -> [Self]
    {
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
        
        print(bold: "starting sub-build with invocation:")
        print(arguments.joined(separator: " "))
        
        let output:OutputBuffer = .init()
        
        let process:Process = .init(arguments: arguments, environment: ProcessEnv.vars, 
            outputRedirection: .stream
            {
                output.push(utf8: $0)
            }
            stderr: 
            {
                output.push(utf8: $0)
            })
        try process.launch()
        let result:ProcessResult = try process.waitUntilExit()
        
        output.flush()
        
        guard case .terminated(code: 0) = result.exitStatus
        else 
        {
            throw Main.Synthesizer.Error.subBuildFailed
        }
        
        guard let library:DLHandle = try? dlopen("\(path.product)", mode: [.now, .local]) 
        else 
        {
            throw Main.Synthesizer.Error.couldNotOpenSubBuildProduct("\(path.product)")
        } 
        
        guard let entrypoint:@convention(c) () -> UnsafeMutableRawPointer = 
            dlsym(library, symbol: Self.entrypoint) 
        else 
        {
            throw Main.Synthesizer.Error.missingSubBuildProductSymbol(Self.entrypoint)
        }
        
        print(bold: "inspecting sub-build product '\(path.product.basename)'")
        print(note: "in directory '\(path.product.parentDirectory)'")
        print(note: "through entrypoint '\(Self.entrypoint)'")
        
        let description:AnyObject   = Unmanaged<AnyObject>.fromOpaque(entrypoint()).takeRetainedValue() 
        guard let interfaces:[Self] = (description as? [Tuple])?.map(Self.init(_:))
        else 
        {
            throw Main.Synthesizer.Error.invalidSubBuildInterfaceFormat(Swift.type(of: description), 
                expected: [Tuple].self)
        }
        
        // dlclose seems to be broken, so we leak the dynamic library, just as 
        // the swift official tools do: 
        // https://github.com/apple/swift-tools-support-core/blob/main/Sources/TSCUtility/IndexStore.swift#L264
        library.leak()
        
        return interfaces
    }
    
    static 
    func load(from path:AbsolutePath) -> [Self]? 
    {
        guard let string:String = try? 
            TSCBasic.localFileSystem.readFileContents(path).description
        else 
        {
            print(note: "no cached nativescript interface list available")
            print(note: "at '\(path)'")
            return nil 
        }
        guard   let json:JSON       =      .init(parsing: string), 
                let interfaces:[Self] = try? .init(from: JSON.Decoder.init(json: json))
        else 
        {
            print(warning:  "could not parse cached nativescript interface list")
            print(note:     "from '\(path)'")
            return nil 
        }
        
        print("found \(interfaces.count) cached nativescript interface(s):")
        for (i, interface):(Int, Self) in interfaces.enumerated()
        {
            print("[\(i)]: \(interface)")
        }
        return interfaces
    }
}
#endif 

extension Main.Synthesizer 
{
    func run() throws
    {
    #if BUILD_STAGE_INERT 
        self.synthesize()
    #else  
        // locate toolchain. this gives the `swiftc` tool, not the `swift` tool!
        let toolchain:AbsolutePath = Self.toolchain()
        
        // load plugin settings 
        let settings:Settings = .load(from: 
            self.packagePath.appending(components: ".godot-swift", "settings.json"))
        
        if !settings.updateInterface, let interfaces:[Interface] = Interface.load(from: 
            self.workspace.appending(component: "interfaces.json"))
        {
            // don’t perform a sub-build
            self.synthesize(interfaces: interfaces)
            return 
        }
        
        print(bold: "starting two-stage build...")
        // get basic information about the package 
        let dependency:(package:String, product:String, path:AbsolutePath) = 
            Self.product(at: self.packagePath, containing: self.target, toolchain: toolchain)
        
        do 
        {
            let interfaces:[Interface] = try Interface.load(inspecting: dependency, 
                workspace: self.workspace, toolchain: toolchain)
                
            print("found \(interfaces.count) nativescript interface(s):")
            for (i, interface):(Int, Interface) in interfaces.enumerated()
            {
                print("[\(i)]: \(interface)")
            }
            
            // save interface.json 
            Source.generate(file: self.workspace.appending(component: "interfaces.json")) 
            {
                """
                [
                \(interfaces.map 
                {
                    """
                        {
                            "type"      : "\($0.type)", 
                            "classes"   : \($0.classes),
                            "properties": \($0.properties), 
                            "methods"   : \($0.methods), 
                            "signals"   : \($0.signals)
                        }
                    """
                }.joined(separator: ",\n"))
                ]
                """
            }
                
            self.synthesize(interfaces: interfaces)
            
            // output library configuration file
            Source.generate(file: self.workspace.appending(component: "library.json")) 
            {
                """
                {
                    "product": "\(dependency.product)", 
                    "symbols": \(interfaces.flatMap(\.classes))
                }
                """
            }
        }
        catch Error.subBuildFailed 
        {
            print(error: "sub-build failed")
            throw ExitCode.failure
        }
        catch Error.couldNotOpenSubBuildProduct(let product) 
        {
            print(error: "could not open sub-build dynamic library product '\(product)'")
            throw ExitCode.failure
        }
        catch Error.missingSubBuildProductSymbol(let symbol) 
        {
            print(error: "could not find sub-build dynamic library symbol '\(symbol)'")
            throw ExitCode.failure
        }
        catch Error.invalidSubBuildInterfaceFormat(let type, expected: let expected) 
        {
            print(error: "inspector interface description type (\(type)) does not match expected type \(expected)")
            throw ExitCode.failure
        }
    #endif
    }
    
    private static 
    func product(at path:AbsolutePath, containing target:String, toolchain:AbsolutePath) 
        -> (package:String, product:String, path:AbsolutePath)
    {
        let manifest:Manifest
        do 
        {
            manifest = try tsc_await 
            { 
                ManifestLoader.loadRootManifest(at: path, 
                    swiftCompiler:      toolchain, 
                    swiftCompilerFlags: [], 
                    identityResolver:   DefaultIdentityResolver.init(), 
                    on:                 .global(), 
                    completion:         $0) 
            }
        }
        catch let error 
        {
            fatalError(
                """
                could not parse manifest at '\(path)' 
                \(error)
                """)
        }
        
        print(note: "searching for dynamic library products containing the target '\(target)'")
        let candidates:[String] = manifest.products.compactMap
        {
            (product:ProductDescription) -> String? in 
            if case .library(.dynamic) = product.type, product.targets.contains(target)
            {
                print(note: "found product '\(product.name)'")
                return product.name 
            }
            else 
            {
                return nil 
            }
        }
        
        guard let product:String = candidates.first 
        else 
        {
            print(error: "no dynamic library products containing the target '\(target)' were found")
            fatalError("aborted")
        }
        if candidates.count > 1 
        {
            print(warning: "multiple candidate products found, using '\(product)'")
        }
        else 
        {
            print(note: "using product '\(product)'")
        }
        
        return (manifest.name, product, path)
    }
    
    private static 
    func toolchain() -> AbsolutePath
    {
        // locate toolchain 
        let invocation:[String]
        
        #if os(macOS)
        invocation = ["xcrun", "--sdk", "macosx", "-f", "swiftc"]
        #else
        invocation = ["which", "swiftc"]
        #endif
        
        guard let output:String = try? Process.checkNonZeroExit(arguments: invocation) 
        else 
        {
            fatalError("could not locate swift toolchain")
        }
        
        return .init(output.spm_chomp())
    }
}

#if BUILD_STAGE_INERT 

extension Main.Synthesizer 
{
    func synthesize()
    {
        Source.generate(file: self.output)
        {
            Source.text(from: "gyb", "synthesizer", "common.swift.part")
            
            """
            // placeholders to make inert library compile 
            func <- <T, Function>(method:@escaping (T) -> Function, symbol:String) 
                -> Godot.NativeScriptInterface<T>.Method
                where T:Godot.NativeScript
            {
                Function.self
            }
            
            @_cdecl("\(Interface.entrypoint)") 
            public 
            func \(Interface.entrypoint)() -> UnsafeMutableRawPointer
            {
                let interfaces:[\(Interface.Tuple.self)] = 
                    Godot.Library.interface.types.map 
                {
                    (
                        type:       .init(reflecting: $0.type), 
                        classes:    $0.symbols, 
                        properties: $0.properties,
                        methods:    $0.methods,
                        signals:    $0.signals
                    )
                }
                return Unmanaged<AnyObject>
                    .passRetained(interfaces as AnyObject)
                    .toOpaque()
            }
            """
        }
    }
}

#else 

extension Main.Synthesizer 
{    
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
            
            func with<R, Next>(context:Next, _ body:(Delegate<Next>) throws -> R) 
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
        
        init(_ type:Grammar.SwiftType, prefix:String, start:Int = 0, 
            diagnostics:Diagnostics.Delegate<(typename:String, signature:Grammar.SwiftType, component:String)>) 
        {
            var counter:Int = start 
            self.init(type, prefix: prefix, counter: &counter, diagnostics: diagnostics)
        }
        init(_ type:Grammar.SwiftType, prefix:String, counter:inout Int, 
                diagnostics:Diagnostics.Delegate<(typename:String, signature:Grammar.SwiftType, component:String)>) 
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
                for type:Grammar.SwiftType in types.map(\.type)  
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
    
    struct FunctionParameterization:Hashable
    {
        private 
        let exclude:String
        private 
        let domain:[Form.Parameter], 
            range:Form 
        
        // `exclude` specifies a leading (unparameterized) type to append to 
        //  the parameters tuple
        init(function:Grammar.FunctionType, exclude:String, 
            prefix:(domain:String, range:String), 
            diagnostics:Diagnostics.Delegate<(typename:String, signature:Grammar.SwiftType)>)   
        {
            var domain:[Form.Parameter] = [], 
                counter:Int             = 0
            for (i, parameter):(Int, Grammar.FunctionParameter) in 
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
extension Main.Synthesizer.Form 
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
    
    var variantType:String 
    {
        switch self 
        {
        case .scalar(type: let type):
            return "\(type).variantType"
        case .void: 
            return ".void"
        case .tuple:
            return ".list"
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
            return Source.inline(list: elements.map(Self.tree(_:)))
        }
    }
    
    func structure(nodes list:String, from variable:String) -> String 
    {
        switch self 
        {
        case .void, .scalar(type: _):
            return Source.fragment
            {
                "Godot.Unmanaged.Variant.pass(retaining: \(variable))" 
            }
        case .tuple(let elements):
            return Source.fragment
            {
                "Godot.Unmanaged.Variant.pass(retaining: \(list).init(moving: "
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
            return 
                """
                \(variable.base).\(list)\(variable.path).\(list)\
                .assign(retaining: \(variable.base)\(variable.path).\(position), at: \(position))
                """
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
                if let value:Void = \(list.root).take(unretained: Void.self, at: \(position))
                {
                    \(variable.base)\(variable.path).\(position) = value 
                }
                else 
                {
                    Godot.print(error: .invalidArgument(\(list.root)[\(position)], expected: Void.self), 
                        function: symbol)
                    return Godot.Unmanaged.Variant.pass(retaining: ())
                }
                """
            }
        case .scalar(type: let type):
            return Source.fragment
            {
                """
                if let value:\(type) = \(list.root).take(unretained: \(type).self, at: \(position))
                {
                    \(variable.base)\(variable.path).\(position) = value 
                }
                else 
                {
                    Godot.print(error: .invalidArgument(\(list.root)[\(position)], expected: \(type).self), 
                        function: symbol)
                    return Godot.Unmanaged.Variant.pass(retaining: ())
                }
                """
            }
        case .tuple(let elements):
            return Source.fragment
            {
                """
                if let \(list.root):\(list.type) = \(list.root).take(unretained: \(list.type).self, at: \(position))
                """
                Source.block
                {
                    """
                    guard \(list.root).count == \(elements.count)
                    else 
                    {
                        Godot.print(error: .invalidArgumentTuple(\(list.root).count, expected: \(Self.tree(self)).self))
                        return Godot.Unmanaged.Variant.pass(retaining: ())
                    }
                    """
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
                else 
                {
                    Godot.print(error: .invalidArgument(\(list.root)[\(position)], expected: \(list.type).self), 
                        function: symbol)
                    return Godot.Unmanaged.Variant.pass(retaining: ())
                }
                """
            }
        }
    }
}
extension Main.Synthesizer.Form.Parameter 
{
    static 
    func tree(_ domain:[Self], nodes list:(label:String, type:String)) -> String? 
    {
        func lists(root:Main.Synthesizer.Form) -> String 
        {
            switch root 
            {
            case .void, .scalar(type: _): 
                return "Void"
            case .tuple(let elements):
                return "(\(elements.map{ lists(root: $0) }.joined(separator: ", ")), \(list.label):\(list.type))"
            }
        }
        
        let body:String = domain.map{      Main.Synthesizer.Form.tree($0.type) }.joined(separator: ", ")
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
extension Main.Synthesizer.FunctionParameterization
{
    var signature:String 
    {
        let domain:[String] = [self.exclude] + self.domain.map 
        {
            "\($0.inout ? "inout " : "")\(Main.Synthesizer.Form.tree($0.type))"
        }
        let range:String = Main.Synthesizer.Form.tree(self.range)
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
        
        return Source.fragment
        {
            """
            func <- <\(generics.map(\.parameter).joined(separator: ", "))>
                (method:@escaping \(signature), symbol:String) 
                -> Godot.NativeScriptInterface<T>.Method
                where \(generics.map 
                    {
                        "\($0.parameter)\($0.constraint)"
                    }.joined(separator: ",\n        "))
            """
            Source.block
            {
                Source.block(delimiters: ("(", ")"))
                {
                    """
                    symbol:         symbol, 
                    annotations: 
                    """
                    Source.block(delimiters: ("[", "], "))
                    {
                        for type:Main.Synthesizer.Form in self.domain.map(\.type)
                        {
                            """
                            Godot.Annotations.Argument.init(label: "", type: \(type.variantType)), 
                            """
                        }
                    }
                    "witness: "
                    Source.block
                    {
                        """
                        (self:T, delegate:\(self.exclude), arguments:Godot.VariadicArguments) 
                            -> Godot.Unmanaged.Variant in
                        
                        guard arguments.count == \(self.domain.count) 
                        else 
                        {
                            Godot.print(error: .invalidArgumentCount(arguments.count, expected: \(self.domain.count)), 
                                function: symbol)
                            return Godot.Unmanaged.Variant.pass(retaining: ())
                        }
                        """
                        
                        if let domain:String = 
                            Main.Synthesizer.Form.Parameter.tree(self.domain, nodes: ("list", "Godot.List"))
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
                        for (position, parameter):(Int, Main.Synthesizer.Form.Parameter) in 
                            self.domain.enumerated() 
                        {
                            parameter.type.destructure(nodes: ("arguments", "list", "Godot.List"), 
                                into: ("inputs", ""), at: position, mutable: parameter.inout)
                        }
                        
                        """
                        
                        let output:\(Main.Synthesizer.Form.tree(self.range)) = \(self.call("method", with: ("delegate", "inputs")))
                        
                        """
                        
                        for (position, parameter):(Int, Main.Synthesizer.Form.Parameter) in 
                            self.domain.enumerated() 
                            where parameter.inout 
                        {
                            parameter.type.update(nodes: "list", in: ("inputs", ""), at: position)
                        }
                        """
                        return \(self.range.structure(nodes: "Godot.List", from: "output"))
                        """
                    }
                }
                
            }
        }
    }
}
extension Main.Synthesizer 
{
    func synthesize(interfaces:[Interface])
    {
        let diagnostics:Diagnostics = .init()
        // diagnose repeated signal types within the same nativescript 
        for interface:Interface in interfaces 
        {
            let multiplicity:[String: [String]] = .init(grouping: interface.signals){ $0 }
            for (signal, count):(String, Int) in multiplicity.mapValues(\.count) 
            {
                if count != 1 
                {
                    diagnostics.with(context: (typename: interface.type, signal: signal))
                    {
                        $0.error 
                        {
                            """
                            invalid redeclaration of signal type '\($0.signal)'
                            """
                        }
                        $0.note 
                        {
                            "in interface definition for type '\($0.typename)'"
                        }
                    }
                }
            }
        }
        
        let parameterizations:Set<FunctionParameterization> = 
            .init(interfaces.flatMap
        {
            (interface:Interface) -> [FunctionParameterization] in 
            
            interface.methods.compactMap  
            {
                (signature:String) in 
                
                guard let type:Grammar.SwiftType = .init(parsing: signature)
                else 
                {
                    print("error: failed to parse signature '\(signature)'")
                    return nil 
                }
                
                return diagnostics.with(context: (typename: interface.type, signature: type))
                {
                    (diagnostics:Diagnostics.Delegate<(typename:String, signature:Grammar.SwiftType)>) 
                        -> FunctionParameterization? in 
                    
                    guard case .function(let function) = type 
                    else 
                    {
                        diagnostics.error 
                        {
                            """
                            function bound by operator '<-' must return a function type (return type is '\($0.signature)')
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
                            (swift cannot receive variadic arguments dynamically)
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
        
        Source.generate(file: self.output) 
        {
            """
            // generated by '\(#file)'
            """
            diagnostics.plant()
            
            Source.text(from: "gyb", "synthesizer", "common.swift.part")
            
            // sort by function signatures, to provide some stability in the 
            // generated code. precompute the signatures to prevent O(n log n) 
            // signature computations 
            let _ = print("synthesizing variadic templates (\(parameterizations.count) signatures)")
            for (i, parameterization):(Int, FunctionParameterization) in (parameterizations
                .map{ (function: $0, signature: $0.signature) }
                .sorted{ $0.signature < $1.signature }
                .map(\.function))
                .enumerated()
            {
                let _ = print("[\(i)]: \(parameterization.signature)")
                parameterization.generateBindingOperatorOverload()
            }
            let _ = print("synthesizing Godot.NativeScript conformances (\(interfaces.count) types)")
            for (i, interface):(Int, Interface) in interfaces.enumerated() 
            {
                let type:String = interface.type 
                
                let _ = print("[\(i)]: \(type)")
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
                extension \(type)
                {
                    static 
                    func register(as symbols:[String], with api:Godot.Library) 
                    {
                        let initializer:Godot.Library.Initializer = 
                        {
                            (
                                delegate:UnsafeMutableRawPointer?, 
                                metadata:UnsafeMutableRawPointer?
                            ) -> UnsafeMutableRawPointer? in 
                            
                            \(type).Interface.initialize(delegate: delegate, metadata: metadata)
                        }
                        let deinitializer:Godot.Library.Deinitializer =
                        {
                            (
                                delegate:UnsafeMutableRawPointer?, 
                                metadata:UnsafeMutableRawPointer?, 
                                instance:UnsafeMutableRawPointer?
                            ) in
                            
                            \(type).Interface.deinitialize(instance: instance, metadata: metadata)
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
                            
                            \(type).interface.call(
                                method:    .init(bitPattern: metadata), 
                                instance:   instance, 
                                delegate:   delegate, 
                                arguments: (arguments, .init(count)))
                        }
                        let getter:Godot.Library.Getter = 
                        {
                            (
                                delegate:UnsafeMutableRawPointer?, 
                                metadata:UnsafeMutableRawPointer?, 
                                instance:UnsafeMutableRawPointer? 
                            ) -> godot_variant in 
                            
                            \(type).interface.get(
                                property:  .init(bitPattern: metadata), 
                                instance:   instance) 
                        } 
                        let setter:Godot.Library.Setter = 
                        {
                            (
                                delegate:UnsafeMutableRawPointer?, 
                                metadata:UnsafeMutableRawPointer?, 
                                instance:UnsafeMutableRawPointer?, 
                                value:UnsafeMutablePointer<godot_variant>?
                            ) in 
                            
                            \(type).interface.set(
                                property:  .init(bitPattern: metadata), 
                                instance:   instance, 
                                value:      value?.pointee)
                        } 
                        
                        let unregister:Godot.Library.WitnessDeinitializer = 
                        {
                            (metadata:UnsafeMutableRawPointer?) in 
                            
                            guard let metadata:UnsafeMutableRawPointer = metadata 
                            else 
                            {
                                fatalError("(swift) \(type).sanitizer received nil metadata pointer")
                            }
                            
                            Unmanaged<Godot.NativeScriptMetadata>.fromOpaque(metadata).release()
                        }
                        
                    #if ENABLE_ARC_SANITIZER
                        let tracker:Godot.RetainTracker = 
                            .init(type: \(type).self, symbols: symbols)
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
                                
                                api.register(method: method, in: symbol,
                                    as:             Self.interface[method: index].symbol, 
                                    annotations:    Self.interface[method: index].annotations) 
                            }
                            
                            // register properties 
                            for index:Int in Self.interface.properties.indices 
                            {
                                let get:godot_property_get_func = .init(
                                    get_func:       getter, 
                                    method_data:    .init(bitPattern: index), 
                                    free_func:      nil)
                                let set:godot_property_set_func = .init(
                                    set_func:       setter, 
                                    method_data:    .init(bitPattern: index), 
                                    free_func:      nil)
                                
                                api.register(property: (get, set), in: symbol, 
                                    as:             Self.interface[property: index].symbol, 
                                    annotations:    Self.interface[property: index].annotations) 
                            } 
                            
                            // register signals 
                            for signal:Interface.Signal in Self.interface.signals 
                            {
                                api.register(signal: signal.type, in: symbol, 
                                    as:             signal.symbol, 
                                    annotations:    signal.annotations)
                            }
                        }
                    }
                }
                """
            }
        }
    }
}

// diagnostic helpers 
extension Grammar.SwiftType 
{
    func match(vector arity:Int) -> String? 
    {
        if  case .named(let identifiers)            = self,
            let head:Grammar.TypeIdentifier         = identifiers.first, 
            identifiers.dropFirst().isEmpty, 
            head.identifier == "Vector", 
            let storage:Grammar.SwiftType           = head.generics.first, 
            let _:Grammar.SwiftType                 = head.generics.dropFirst().first, 
            head.generics.dropFirst(2).isEmpty, 
            
            case .named(let storageIdentifiers)     = storage, 
            let storageHead:Grammar.TypeIdentifier  = storageIdentifiers.first, 
            storageIdentifiers.dropFirst().isEmpty, 
            storageHead.identifier == "SIMD\(arity)", 
            let scalar:Grammar.SwiftType            = storageHead.generics.first, 
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

#endif
