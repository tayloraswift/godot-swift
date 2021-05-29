extension Godot
{
    @Source.Code 
    static 
    var swift:String
    {
        let tree:Class.Tree = .load(api: (3, 3, 0))
        // `withExtendedLifetime` is important because properties hold `unowned`
        //  references to upstream nodes 
        let classes:
        [
            (
                node:Class.Node, 
                functions:String?, 
                definition:String
            )
        ] 
        = 
        withExtendedLifetime(tree.root)
        {
            tree.root.preorder.compactMap
            {
                ($0, $0.functions, $0.definition)
            }
            .sorted 
            {
                // keeps the generated code stable
                $0.node.name < $1.node.name
            }
        }
        
        Source.text(from: "fragments",  "external.swift.part")
        Source.text(from: "fragments",  "runtime.swift.part")
        Source.text(from: "fragments",  "variant.swift.part")
        Source.text(from: "fragments",  "aggregate.swift.part")
        
        Source.section(name:            "variant-raw.swift.part")
        {
            VariantRaw.swift
        }
        Source.section(name:            "variant-vector.swift.part")
        {
            VariantVector.swift
        }
        Source.section(name:            "variant-rectangle.swift.part")
        {
            VariantRectangle.swift
        }
        Source.text(from: "fragments",  "variant-string.swift.part")
        Source.section(name:            "variant-array.swift.part")
        {
            VariantArray.swift
        }
        Source.section(name:            "passable.swift.part")
        {
            Passable.swift
        }
        Source.section(name:            "convention.swift.part")
        {
            // determine longest required icall template 
            Convention.swift(arity: tree.root.preorder
                .flatMap{ $0.methods.values.map(\.parameters.count) }
                .max() ?? 0)
        }
        Source.section(name:            "delegates.swift.part")
        {
            "extension Godot"
            Source.block 
            {
                """
                enum Singleton 
                {
                }
                
                // type metadata table
                static 
                let DelegateTypes:[AnyDelegate.Type] =
                """
                Source.block(delimiters: ("[", "]"))
                {
                    for node:Class.Node in classes.map(\.node)
                    {
                        "\(node.namespace).\(node.name).self,"
                    }
                }
            }
        }
        
        Source.section(name:            "functions.swift.part")
        {
            // cannot override static properties, so we need to store the 
            // method bindings out-of-line
            """
            extension Godot
            {
                fileprivate 
                enum Functions 
                {
                }
            }
            extension Godot.Functions
            """
            Source.block 
            {
                for (node, functions, _):(Class.Node, String?, String) in classes
                {
                    if let functions:String = functions 
                    {
                        """
                        enum \(node.name)
                        """
                        Source.block 
                        {
                            functions
                        }
                    }
                }
            }
        }
        
        """
        /// enum Godot.Unmanaged 
        ///     A namespace for Godot types that are not memory-managed by the 
        ///     Godot engine.
        /// #   (godot-namespaces)
        
        /// enum Godot.Singleton 
        ///     A namespace for Godot singleton classes.
        /// #   (godot-namespaces)
        
        """
        Source.section(name:            "global.swift.part")
        {
            Self.constants(tree.constants)
        }
        for (node, _, definition):(Class.Node, String?, String) in classes
        {
            Source.section(name: "classes", "\(node.name).swift.part")
            {
                definition 
            }
        }
    }
    
    private static 
    func constants(_ constants:[String: Int]) -> String
    {
        var constants:[String: Int] = constants
        
        let enumerations:
        [
            (name:String, prefix:String?, include:[(constant:String, as:String)])
        ] 
        =
        [
            ("Margin",              "MARGIN",           []),
            ("Corner",              "CORNER",           []),
            ("Orientation",         nil,                
            [
                ("VERTICAL",            "VERTICAL"), 
                ("HORIZONTAL",          "HORIZONTAL")
            ]),
            ("HorizontalAlignment", "HALIGN",           []),
            ("VerticalAlignment",   "VALIGN",           []),
            // KEY_MASK is a colliding prefix, so it must come first
            ("KeyMask",             "KEY_MASK",         
            [
                ("KEY_CODE_MASK",       "CODE_MASK"), 
                ("KEY_MODIFIER_MASK",   "MODIFIER_MASK")
            ]),
            ("Key",                 "KEY",              []),
            ("Mouse",               "BUTTON",           []),
            ("Joystick",            "JOY",              []),
            ("MidiMessage",         "MIDI_MESSAGE",     []),
            ("PropertyHint",        "PROPERTY_HINT",    []),
            ("PropertyUsage",       "PROPERTY_USAGE",   []),
            ("MethodFlags",         "METHOD_FLAG",      
            [
                ("METHOD_FLAGS_DEFAULT", "DEFAULT")
            ]),
            
            ("VariantOperator",     "OP",               []),
            ("Error",               "ERR",              []),
        ]
        
        // remove some constants we want to ignore 
        constants["ERR_PRINTER_ON_FIRE"]    = nil
        constants["TYPE_MAX"]               = nil
        constants["OP_MAX"]                 = nil
        constants["SPKEY"]                  = nil
        
        var groups:[String: [(name:Words, value:Int)]] = [:]
        for (name, prefix, include):
            (
                String, 
                String?, 
                [(constant:String, as:String)]
            ) 
            in enumerations
        {
            var group:[(name:String, value:Int)] = []
            for include:(constant:String, as:String) in include 
            {
                guard let value:Int = constants.removeValue(forKey: include.constant)
                else 
                {
                    fatalError("missing constant '\(include.constant)'")
                }
                group.append((include.as, value))
            }
            if let prefix:String = (prefix.map{ "\($0)_" }) 
            {
                for (constant, value):(String, Int) in constants 
                {
                    guard constant.starts(with: prefix) 
                    else 
                    {
                        continue 
                    }
                    
                    let name:String 
                    switch String.init(constant.dropFirst(prefix.count))
                    {
                    case "0": name = "ZERO"
                    case "1": name = "ONE"
                    case "2": name = "TWO"
                    case "3": name = "THREE"
                    case "4": name = "FOUR"
                    case "5": name = "FIVE"
                    case "6": name = "SIX"
                    case "7": name = "SEVEN"
                    case "8": name = "EIGHT"
                    case "9": name = "NINE"
                    case let suffix: name = suffix
                    }
                    group.append((name, value))
                    // remove the constant from the dictionary, so it won’t 
                    // get picked up again
                    constants[constant] = nil 
                }
            }
            groups[name] = group
            .map 
            {
                (
                    Words.split(snake: $0.name)
                        .normalized(patterns: Words.Normalization.constants), 
                    $0.value
                )
            }
            .sorted 
            {
                $0.name < $1.name
            }
        }
        
        // can use `!` because keys "Error", "VariantOperator" are written in `enumerations`
        let errors:[(name:Words, value:Int)]        = groups.removeValue(forKey: "Error")!
        .sorted 
        {
            $0 < $1
        }
        let operators:[(name:String, value:Int)]    = groups.removeValue(forKey: "VariantOperator")!
        .map 
        {
            ($0.name.camelcased, $0.value)
        }
        let variants:[(name:String, value:Int)]     = constants.compactMap 
        {
            let name:String
            switch $0.key 
            {
            case "TYPE_NIL":            name = "void"
            case "TYPE_BOOL":           name = "bool"
            case "TYPE_INT":            name = "int"
            case "TYPE_REAL":           name = "float"
            case "TYPE_VECTOR2":        name = "vector2"
            case "TYPE_VECTOR3":        name = "vector3"
            case "TYPE_COLOR":          name = "vector4"
            case "TYPE_QUAT":           name = "quaternion"
            case "TYPE_PLANE":          name = "plane3"
            case "TYPE_RECT2":          name = "rectangle2"
            case "TYPE_AABB":           name = "rectangle3"
            case "TYPE_TRANSFORM2D":    name = "affine2"
            case "TYPE_TRANSFORM":      name = "affine3"
            case "TYPE_BASIS":          name = "linear3"
            case "TYPE_STRING":         name = "string"
            case "TYPE_RID":            name = "resourceIdentifier"
            case "TYPE_NODE_PATH":      name = "nodePath"
            case "TYPE_ARRAY":          name = "list"
            case "TYPE_DICTIONARY":     name = "map"
            case "TYPE_OBJECT":         name = "delegate"
            case "TYPE_RAW_ARRAY":      name = "uint8Array"
            case "TYPE_INT_ARRAY":      name = "int32Array"
            case "TYPE_REAL_ARRAY":     name = "float32Array"
            case "TYPE_VECTOR2_ARRAY":  name = "vector2Array"
            case "TYPE_VECTOR3_ARRAY":  name = "vector3Array"
            case "TYPE_COLOR_ARRAY":    name = "vector4Array"
            case "TYPE_STRING_ARRAY":   name = "stringArray"
            default: return nil
            }
            return (name, $0.value)
        }
        .sorted 
        {
            $0.value < $1.value
        }
        
        return Source.fragment 
        {
            """
            /// struct Godot.VariantType
            /// :   Hashable 
            ///     The [`Godot::Variant::Type`](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-variant-type) enumeration.
            /// #   (10:godot-variant-usage)
            
            /// struct Godot.VariantOperator
            /// :   Hashable 
            ///     The [`Godot::Variant::Operator`](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-variant-operator) enumeration.
            /// #   (10:godot-variant-usage)
            
            extension Godot
            """
            Source.block 
            {
                for (name, constants):(String, [(name:String, value:Int)]) in 
                [
                    ("VariantType",     variants),
                    ("VariantOperator", operators),
                ]
                {
                    """
                    struct \(name):Hashable
                    """
                    Source.block 
                    {
                        """
                        /// let Godot.\(name).value:Int 
                        ///     The numeric code for this enumeration case.
                        let value:Int
                        """
                        for constant:(name:String, value:Int) in constants 
                        {
                            """
                            /// static let Godot.\(name).\(constant.name):Self 
                            static 
                            let \(constant.name):Self = .init(value: \(constant.value))
                            """
                        }
                    }
                }
                
                for (name, constants):(String, [(name:Words, value:Int)]) in 
                    (groups.sorted{ $0.key < $1.key })
                {
                    """
                    /// enum Godot.\(name)
                    /// #   (godot-global-constants)
                    enum \(name)
                    """
                    Source.block 
                    {
                        for constant:(name:Words, value:Int) in constants 
                        {
                            """
                            /// static let Godot.\(name).\(constant.name.camelcased):Int 
                            static 
                            let \(constant.name.camelcased):Int = \(constant.value)
                            """
                        }
                    }
                }
                
                """
                /// enum Godot.Error
                /// :   Swift.Error 
                ///     An engine error.
                enum Error:Swift.Error
                """
                Source.block 
                {
                    """
                    /// case Godot.Error.unknown(code:)
                    ///     A game engine error whose code is unrecognized by Godot Swift.
                    /// - code  :Int 
                    ///     The error code.
                    case unknown(code:Int)
                    
                    """
                    for name:Words in errors.map(\.name)
                    {
                        """
                        /// case Godot.Error.\(name.camelcased)
                        case \(name.camelcased)
                        """
                    }
                }
            }
            "extension Godot.Error"
            Source.block 
            {
                """
                /// init Godot.Error.init(value:)
                ///     Creates an engine error with the given numeric error code.
                /// - value:Int 
                init(value:Int)
                """
                Source.block 
                {
                    """
                    switch value
                    {
                    """
                    for (name, code):(Words, Int) in errors 
                    {
                        """
                        case \(code): self = .\(name.camelcased)
                        """
                    }
                    """
                    case let unknown: self = .unknown(code: unknown)
                    }
                    """
                }
                
                """
                /// var Godot.Error.value:Int { get }
                ///     The numeric code for this engine error.
                var value:Int
                """
                Source.block 
                {
                    """
                    switch self 
                    {
                    """
                    for (name, code):(Words, Int) in errors 
                    {
                        """
                        case .\(name.camelcased): return \(code)
                        """
                    }
                    """
                    case .unknown(code: let code): return code
                    }
                    """
                }
            }
        }
    }
}

extension Godot.Class.Node 
{
    var url:String 
    {
        "https://docs.godotengine.org/en/stable/classes/class_\(self.symbol.lowercased()).html"
    }
    
    var functions:String?
    {
        guard !self.methods.isEmpty
        else 
        {
            return nil 
        }
        // sort to keep the generated code stable
        let methods:[(key:Method.Key, value:Method)] = self.methods
        .sorted 
        {
            $0.key.name < $1.key.name
        }
        return 
            """
            static 
            let \(methods.map 
            {
                """
                \($0.key.name.camelcased):Godot.Function = 
                        Godot.Function.bind(method: "\($0.key.symbol)", from: \(self.namespace).\(self.name).self)
                """
            }.joined(separator: ",\n    "))
            """
    }
    var definition:String
    {
        // sort to keep the generated code stable
        let constants:[(key:Constant.Key, value:Constant)] = self.constants
        .sorted 
        {
            $0.value.name < $1.value.name
        }
        let properties:[(key:Property.Key, value:Property)] = self.properties
        .sorted 
        {
            $0.key.name < $1.key.name
        }
        let methods:[(key:Method.Key, value:Method)]        = self.methods
        .sorted 
        {
            $0.key.name < $1.key.name
        }
        
        return Source.fragment
        {
            "extension \(self.namespace)"
            Source.block 
            {
                // doccomment 
                """
                /// class \(self.namespace).\(self.name)
                """
                if let parent:Godot.Class.Node = self.parent 
                {
                    """
                    /// :   \(parent.namespace).\(parent.name)
                    """
                }
                if self.children.isEmpty 
                {
                    """
                    /// final 
                    """
                }
                """
                ///     The [`Godot::\(self.symbol)`](\(self.url)) class.
                """
                
                if let parent:Godot.Class.Node = self.parent 
                {
                    if self.children.isEmpty 
                    {
                    "final" 
                    }
                    "class \(self.name):\(parent.namespace).\(parent.name)"
                }
                else 
                {
                    "class \(self.name)"
                }
                Source.block 
                {
                    """
                    \(self.parent == nil ? "" : "override ")class 
                    var symbol:Swift.String { "\(self.symbol)" }
                    """
                    
                    if      self.namespace  == .root, 
                            self.name       == .split(pascal: "AnyDelegate")
                    {
                        // Godot.AnyDelegate has special behavior:
                        """
                        final 
                        let core:UnsafeMutableRawPointer 
                        // non-failable init assumes instance has been type-checked!
                        required
                        init(retained core:UnsafeMutableRawPointer) 
                        {
                            self.core = core
                        }
                        required
                        init(unretained core:UnsafeMutableRawPointer) 
                        {
                            self.core = core
                        }
                        
                        /// func \(self.namespace).\(self.name).emit<Signal>(signal:as:)
                        /// final 
                        /// where Signal:Godot.Signal
                        ///     Emits a value as the specified signal type.
                        /// - value :   Signal.Value 
                        ///     A signal value.
                        /// - _     :   Signal.Type 
                        ///     The signal type to emit the given `value` as.
                        final 
                        func emit<Signal>(signal value:Signal.Value, as _:Signal.Type)
                            where Signal:Godot.Signal 
                        {
                            var variants:[Godot.Unmanaged.Variant] = 
                                [.pass(retaining: Signal.name)]
                                +
                                Signal.interface.arguments.map
                                {
                                    $0.witness(value)
                                }
                            defer 
                            {
                                for i:Int in variants.indices 
                                {
                                    variants[i].release()
                                }
                            }
                            
                            Godot.Functions.AnyDelegate.emitSignal(delegate: self, variants: variants)
                        }
                        """
                    }
                    else if self.namespace  == .root, 
                            self.name       == .split(pascal: "AnyObject")
                    {
                        // Godot.AnyObject has special behavior:
                        """
                        required
                        init(retained core:UnsafeMutableRawPointer) 
                        {
                            super.init(retained: core)
                        }
                        required 
                        init(unretained core:UnsafeMutableRawPointer) 
                        {
                            super.init(unretained: core)
                            guard self.retain()
                            else 
                            {
                                fatalError(
                                    \"""
                                    could not retain delegate of type \\
                                    '\\(Swift.String.init(reflecting: Self.self))' at <\\(self.core)>
                                    \""")
                            }
                        }
                        deinit
                        { 
                            self.release()
                        }
                        
                        /// func \(self.namespace).\(self.name).retain()
                        /// final 
                        /// @   discardableResult
                        ///     Performs an unbalanced retain.
                        /// - ->    : Bool 
                        ///     This method should always return `true`.
                        @discardableResult
                        final
                        func retain() -> Bool 
                        {
                            Godot.Functions.AnyObject.reference(self: self) 
                        }
                        /// func \(self.namespace).\(self.name).release()
                        /// final 
                        /// @   discardableResult
                        ///     Performs an unbalanced release.
                        /// - ->    : Bool 
                        ///     `true` if `self` was uniquely-referenced before performing 
                        ///     the release, `false` otherwise.
                        @discardableResult
                        final
                        func release() -> Bool 
                        {
                            Godot.Functions.AnyObject.unreference(self: self) 
                        }
                        """
                    } 
                    """
                    
                    """
                    for (key, constant):(Constant.Key, Constant) in constants 
                    {
                        """
                        /// static let \(self.namespace).\(self.name).\(constant.name.camelcased):Int
                        ///     The [`\(key.symbol)`](\(self.url)#constants) constant. 
                        /// 
                        ///     The raw value of this constant is `\(constant.value)`.
                        static 
                        let \(constant.name.camelcased):Int = \(constant.value)
                        """
                    }
                    for enumeration:Enumeration in self.enumerations 
                    {
                        """
                        /// struct \(self.namespace).\(self.name).\(enumeration.name)
                        /// :   Swift.Hashable
                        ///     The [`\(enumeration.symbol)`](\(self.url)#enumerations)
                        ///     enumeration.
                        struct \(enumeration.name):Hashable  
                        """
                        Source.block 
                        {
                            """
                            /// let \(self.namespace).\(self.name).\(enumeration.name).value:Swift.Int 
                            ///     The raw value of this enumeration case.
                            let value:Int
                            
                            """
                            for (name, value):(Words, Int) in enumeration.cases 
                            {
                                """
                                /// static let \(self.namespace).\(self.name).\(enumeration.name).\(name.camelcased):Self 
                                static 
                                let \(name.camelcased):Self = .init(value: \(value))
                                """
                            }
                        }
                    }
                    """
                    
                    """
                    for (key, property):(Property.Key, Property) in properties
                    {
                        property.define(as: key.name.camelcased, originally: key.symbol, in: self)
                    } 
                    
                    for (key, method):(Method.Key, Method) in methods 
                        where !method.is.hidden
                    {
                        method.define(as: key.name.camelcased, originally: key.symbol, in: self)
                    } 
                }
            }
        } 
    }
}
extension Godot.Class.Node.Property 
{
    func define(as name:String, originally symbol:String, in host:Godot.Class.Node) 
        -> String 
    {
        let function:Godot.Function = .init(domain: [], range: self.type)
        let getter:String           = 
            """
            Godot.Functions.\(self.get.node.name).\
            \(self.get.node.methods[self.get.index].key.name.camelcased)
            """
        let setter:String?          = self.set.map 
        {
            """
            Godot.Functions.\($0.node.name).\
            \($0.node.methods[$0.index].key.name.camelcased)
            """
        }
        
        let modifiers:String? 
        switch (self.is.final, self.is.override)
        {
        case (true , false):    modifiers = "final"
        case (true , true ):    modifiers = "final override"
        case (false, true ):    modifiers = "override"
        case (false, false):    modifiers = nil 
        }
        
        let expressions:[String] = ["self: self"] + (self.index.map{ ["\($0)"] } ?? [])
        let body:(get:String, set:String?) 
        body.get = Source.block 
        {
            """
            let result:\(function.range.inner) = \(getter)\(Source.inline(list: expressions))
            return \(function.range.outer(expression: "result"))
            """
        }
        body.set = setter.map 
        {
            (setter:String) -> String in 
            Source.block 
            {
                """
                \(setter)\(Source.inline(list: 
                    expressions + [function.range.inner(expression: "value")]))
                """
            }
        }
        return Source.fragment 
        {
            // create doccomment tag for this accessor group. we need to replace 
            // underscores with "-" hyphens
            let tag:String = .init("class-\(host.symbol)-\(symbol)-accessor".map 
            {
                $0 == "_" ? "-" : $0
            })
            // emit doccomment 
            """
            /// var \(host.namespace).\(host.name).\(name):\(function.range.canonical) \
            { \(body.set == nil ? "get" : "get set") }
            """
            if let modifiers:String = modifiers 
            {
                """
                /// \(modifiers)
                """
            }
            """
            ///     The [`\(symbol)`](\(host.url)#properties) instance property.
            /// #   [See also](\(tag))
            /// #   (\(tag))
            """
            
            if let modifiers:String = modifiers 
            {
                modifiers
            }
            """
            var \(name):\(function.range.canonical)
            """
            if function.parameters.isEmpty // no generics 
            {
                if let set:String = body.set 
                {
                    Source.block 
                    {
                        "get" 
                        body.get 
                        "set(value)"
                        set
                    }
                }
                else 
                {
                    body.get 
                }
            }
            else 
            {
                if let _:String = body.set 
                {
                    Source.block 
                    {
                        """
                        get 
                        {
                            self.\(name)(as: \(function.range.canonical).self)
                        }
                        set(value) 
                        {
                            self.set(\(name): value)
                        }
                        """
                    }
                }
                else 
                {
                    Source.block 
                    {
                        "self.\(name)(as: \(function.range.canonical).self)"
                    }
                } 
                
                // emit generic accessors 
                """
                /// func \(host.namespace).\(host.name).\(name)\(Source.inline(angled: function.parameters))(as:)
                """
                if let modifiers:String = modifiers 
                {
                    """
                    /// \(modifiers)
                    """
                }
                // constraints need to fit on one line for entrapta doccomment
                """
                /// where \(function.constraints.joined(separator: ", "))
                ///     Loads this delegate’s [`\(name)`] property as the specified type.
                /// - type  :\(function.range.outer).Type
                /// - ->    :\(function.range.outer)
                /// #   [See also](\(tag))
                /// #   (\(tag))
                """
                
                if let modifiers:String = modifiers 
                {
                    modifiers
                }
                """
                func \(name)\(Source.inline(angled: function.parameters))\
                (as _:\(function.range.outer).Type) -> \(function.range.outer) \
                \(Source.constraints(function.constraints))
                """
                body.get
                if let set:String = body.set
                {
                    """
                    /// func \(host.namespace).\(host.name).set\(Source.inline(angled: function.parameters))(\(name):)
                    """
                    if let modifiers:String = modifiers 
                    {
                        """
                        /// \(modifiers)
                        """
                    }
                    """
                    /// where \(function.constraints.joined(separator: ", "))
                    ///     Sets this delegate’s [`\(name)`] property to the given value. 
                    /// - value :\(function.range.outer)
                    /// #   [See also](\(tag))
                    /// #   (\(tag))
                    """
                    if let modifiers:String = modifiers 
                    {
                        modifiers
                    }
                    """
                    func set\(Source.inline(angled: function.parameters))\
                    (\(name != "value" ? "\(name) " : "")value:\(function.range.outer)) \
                    \(Source.constraints(function.constraints))
                    """
                    set
                }
            }
        }
    } 
}
extension Godot.Class.Node.Method 
{
    func define(as name:String, originally symbol:String, in host:Godot.Class.Node) -> String 
    {
        let function:Godot.Function 
        switch self.result 
        {
        case .thrown:
            function = .init(domain: self.parameters.map(\.type), range: .void)
        case .returned(let type):
            function = .init(domain: self.parameters.map(\.type), range: type)
        }
        
        let arguments:[(label:String, name:String?, type:Godot.Function.Scalar)] = 
            zip(self.parameters.map
            {
                (label: $0.label, name: $0.label == $0.name ? nil : $0.name)
            }, function.domain)
            .map
            {
                (element:(argument:(label:String, name:String?), type:Godot.Function.Scalar)) in
                (
                    label:  element.argument.label, 
                    name:   element.argument.name, 
                    type:   element.type 
                )
            }
        
        let expressions:[String] = ["self: self"] + arguments.map 
        {
            $0.type.inner(expression: $0.name ?? $0.label)
        }
        let signature:(generics:String, domain:String) = 
        (
            Source.inline(angled: function.parameters, else: ""), 
            Source.inline(list: arguments.map
            { 
                "\($0.label)\($0.name.map{ " \($0)" } ?? ""):\($0.type.outer)" 
            }
            +
            (function.metatype.map 
            {
                ["as _:\($0).Type"]
            } ?? []))
        )
        let modifiers:String? 
        switch (self.is.final, self.is.override)
        {
        case (true , false):    modifiers = "final"
        case (true , true ):    modifiers = "final override"
        case (false, true ):    modifiers = "override"
        case (false, false):    modifiers = nil 
        }
        return Source.fragment 
        {
            // emit doccomment 
            """
            /// func \(host.namespace).\(host.name).\(name)\(signature.generics)\
            (\((arguments.map
            { 
                "\($0.label):" 
            }
            + 
            (function.metatype == nil ? [] : ["as:"]))
            .joined())) \(self.result == .thrown ? "throws" : "")
            """
            if let modifiers:String = modifiers 
            {
                """
                /// \(modifiers)
                """
            }
            if !function.constraints.isEmpty
            {
                """
                /// where \(function.constraints.joined(separator: ", "))
                """
            }
            """
            ///     The [`\(symbol)`](\(host.url)#class-\(host.symbol.lowercased())-method-\(String.init(symbol.map 
            {
                $0 == "_" ? "-" : $0
            }))) instance method.
            """
            for (label, name, type):(String, String?, Godot.Function.Scalar) in arguments
            {
                """
                /// - \(name ?? label):\(type.outer)
                """
            }
            if let metatype:String = function.metatype 
            {
                """
                /// - _:\(metatype).Type
                """
            }
            if case .concrete(type: "Void") = function.range 
            {
            }
            else 
            {
                """
                /// - ->:\(function.range.outer)
                """
            }
            
            if let modifiers:String = modifiers 
            {
                modifiers
            }
            switch (self.result, function.range)
            {
            case (.thrown, _):
                """
                func \(name)\(signature.generics)\(signature.domain) throws \
                \(Source.constraints(function.constraints))
                {
                    let status:Int64 = Godot.Functions.\(host.name).\(name)\(Source.inline(list: expressions))
                    guard status == 0 
                    else 
                    {
                        throw Godot.Error.init(value: Int.init(status))
                    }
                }
                """
            case (_, .concrete(type: "Void")):
                """
                func \(name)\(signature.generics)\(signature.domain) \
                \(Source.constraints(function.constraints))
                {
                    Godot.Functions.\(host.name).\(name)\(Source.inline(list: expressions))
                }
                """
            case (_, let range):
                """
                func \(name)\(signature.generics)\(signature.domain) -> \(range.outer) \
                \(Source.constraints(function.constraints))
                {
                    let result:\(range.inner) = Godot.Functions.\(host.name).\(name)\(Source.inline(list: expressions))
                    return \(range.outer(expression: "result"))
                }
                """
            }
        }
    } 
}

extension Godot 
{
    enum KnownType:Hashable 
    {
        case void 
        case bool 
        case int 
        case float 
        case vector2
        case vector3
        case vector4
        
        case quaternion 
        case plane3
        case rectangle2 
        case rectangle3
        case affine2 
        case affine3
        case linear3
        case resourceIdentifier
        
        case list 
        case map 
        case nodePath
        case string 
        
        case uint8Array
        case int32Array
        case float32Array
        case stringArray
        case vector2Array
        case vector3Array
        case vector4Array
        
        case object(String)
        case enumeration(String)
        
        case variant
    }
    
    struct Function
    {
        enum Convention 
        {
            case variant 
            case enumeration(String)
            case concrete   (String)
            case generic    (String, as:String, (String) -> String, constraints:(String) -> String)
        }
        
        enum Scalar 
        {
            case variant 
            case enumeration(type:String)
            case concrete   (type:String)
            case generic    (type:String, as:String)
        }
        
        let domain:[Scalar]
        let range:Scalar
        let metatype:String?
        
        let parameters:[String]
        let constraints:[String]
    }
}
extension Godot.Function.Convention
{
    init(_ type:Godot.KnownType)
    {
        switch type 
        {
        case .void:
            self =  .concrete("Void")
        case .bool:
            self =  .concrete("Bool")
        case .int:
            self =  .generic("T", as: "Int64"){ $0 } 
            constraints:    { "\($0):FixedWidthInteger" }
        case .float:
            self =  .generic("T", as: "Float64"){ $0 }
            constraints:    { "\($0):BinaryFloatingPoint" }
        case .vector2:
            self =  .generic("T", as: "Float32"){ "Vector2<\($0)>" }
            constraints:    { "\($0):BinaryFloatingPoint & SIMDScalar" }
        case .vector3:
            self =  .generic("T", as: "Float32"){ "Vector3<\($0)>" }
            constraints:    { "\($0):BinaryFloatingPoint & SIMDScalar" }
        case .vector4:
            self =  .generic("T", as: "Float32"){ "Vector4<\($0)>" }
            constraints:    { "\($0):BinaryFloatingPoint & SIMDScalar" }
        
        case .rectangle2:
            self =  .generic("T", as: "Float32"){ "Vector2<\($0)>.Rectangle" }
            constraints:    { "\($0):BinaryFloatingPoint & SIMDScalar" }
        case .rectangle3:
            self =  .generic("T", as: "Float32"){ "Vector3<\($0)>.Rectangle" }
            constraints:    { "\($0):BinaryFloatingPoint & SIMDScalar" }
        
        case .quaternion:
            self =  .generic("T", as: "Float32"){ "Quaternion<\($0)>" }
            constraints:    { "\($0):BinaryFloatingPoint & Numerics.Real & SIMDScalar" }
        case .plane3:
            self =  .generic("T", as: "Float32"){ "Godot.Plane3<\($0)>" }
            constraints:    { "\($0):BinaryFloatingPoint & SIMDScalar" }

        case .affine2:
            self =  .generic("T", as: "Float32"){ "Godot.Transform2<\($0)>.Affine" }
            constraints:    { "\($0):BinaryFloatingPoint & SIMDScalar" }
        case .affine3:
            self =  .generic("T", as: "Float32"){ "Godot.Transform3<\($0)>.Affine" }
            constraints:    { "\($0):BinaryFloatingPoint & SIMDScalar" }
        case .linear3:
            self =  .generic("T", as: "Float32"){ "Godot.Transform3<\($0)>.Linear" }
            constraints:    { "\($0):BinaryFloatingPoint & SIMDScalar" }
        case .resourceIdentifier:   
            self =  .concrete("Godot.ResourceIdentifier")
        
        case .list:
            self =  .concrete("Godot.List")
        case .map:
            self =  .concrete("Godot.Map")
        case .nodePath:
            self =  .concrete("Godot.NodePath")
        case .string:               
            self =  .generic("S", as: "Godot.String") { $0 }
            constraints:    { "\($0):Godot.StringRepresentable" }
        
        case .uint8Array:
            self =  .generic("S", as: "Godot.Array<UInt8>"){ $0 }
            constraints:    { "\($0):Godot.ArrayRepresentable, \($0).Element == UInt8" }
        case .int32Array:
            self =  .generic("S", as: "Godot.Array<Int32>"){ $0 }
            constraints:    { "\($0):Godot.ArrayRepresentable, \($0).Element == Int32" }
        case .float32Array:
            self =  .generic("S", as: "Godot.Array<Float32>"){ $0 }
            constraints:    { "\($0):Godot.ArrayRepresentable, \($0).Element == Float32" }
        case .stringArray:
            self =  .generic("S", as: "Godot.Array<Swift.String>"){ $0 }
            constraints:    { "\($0):Godot.ArrayRepresentable, \($0).Element == Swift.String" }
        case .vector2Array:
            self =  .generic("S", as: "Godot.Array<Vector2<Float32>>"){ $0 }
            constraints:    { "\($0):Godot.ArrayRepresentable, \($0).Element == Vector2<Float32>" }
        case .vector3Array:
            self =  .generic("S", as: "Godot.Array<Vector3<Float32>>"){ $0 }
            constraints:    { "\($0):Godot.ArrayRepresentable, \($0).Element == Vector3<Float32>" }
        case .vector4Array:
            self =  .generic("S", as: "Godot.Array<Vector4<Float32>>"){ $0 }
            constraints:    { "\($0):Godot.ArrayRepresentable, \($0).Element == Vector4<Float32>" }
        case .object(let type): 
            self =  .concrete("\(type)?")
        case .enumeration(let type):
            self =  .enumeration(type)
        case .variant:
            self =  .variant
        }
    }
}
extension Godot.Function 
{
    init(domain:[Godot.KnownType], range:Godot.KnownType)
    {
        let conventions:[Convention]    = (domain + [range]).map(Convention.init(_:))
        // find out how many generics of each letter we are going to need 
        let multiplicity:[String: Int]  = .init(conventions.compactMap 
            {
                if case .generic(let prefix, as: _, _, constraints: _) = $0 
                {
                    return (prefix, 1)
                }
                else 
                {
                    return nil
                }
            }, 
            uniquingKeysWith: + )
        // initialize arrays and counters for any letters that appear more than once 
        var constraints:[String]    = [], 
            parameters:[String]     = [], 
            scalars:[Scalar]        = [], 
            counter:[String: Int]   = multiplicity.compactMapValues 
        {
            $0 > 1 ? 0 : nil
        }
        
        for convention:Convention in conventions
        {
            let scalar:Scalar 
            switch convention 
            {
            case .variant: 
                scalar = .variant 
            case .enumeration(let type):
                scalar = .enumeration(type: type)
            case .concrete(let type):
                scalar = .concrete(type: type)
            case .generic(let prefix, as: let argument, let type, constraints: let constraint):
                let parameter:String
                if let index:Dictionary<String, Int>.Index = counter.index(forKey: prefix)
                {
                    parameter               = "\(prefix)\(counter.values[index])"
                    counter.values[index]  += 1
                }
                else 
                {
                    parameter               = prefix 
                }
                
                constraints.append(constraint(parameter))
                parameters.append(parameter)
                
                scalar = .generic(type: type(parameter), as: type(argument))
            }
            scalars.append(scalar)
        }
        
        self.parameters     = parameters 
        self.constraints    = constraints 
        
        self.range          = scalars.removeLast() 
        self.domain         = scalars
        // if the return type is generic, *and none of the arguments* use that 
        // type, add an `as:` metatype argument 
        if  case .generic(type: let type, as: _) = self.range, 
            (self.domain.allSatisfy
            {
                switch $0 
                {
                case .generic(type: type, as: _):
                    return false 
                default: 
                    return true 
                }
            })
        {
            self.metatype = type 
        }
        else 
        {
            self.metatype = nil
        }
    }
}
extension Godot.Function.Scalar 
{
    var canonical:String
    {
        switch self 
        {
        case    .variant: 
            return "Godot.Variant?"
        case    .enumeration(type:        let type), 
                .concrete   (type:        let type),
                .generic    (type: _, as: let type):
            return type 
        } 
    } 
    var outer:String 
    {
        switch self 
        {
        case    .variant: 
            return "Godot.Variant?"
        case    .enumeration(type: let type), 
                .concrete   (type: let type),
                .generic    (type: let type, as: _):
            return type 
        }
    }
    var inner:String 
    {
        switch self 
        {
        case    .variant: 
            return "Godot.VariantExistential"
        case    .enumeration(type: _):
            return "Int64" 
        case    .concrete   (type:        let type),
                .generic    (type: _, as: let type):
            return type 
        }
    }
    func inner(expression:String) -> String 
    {
        switch self 
        {
        case .variant:
            return "Godot.VariantExistential.init(variant: \(expression))"
        case .enumeration:
            return                             "Int64.init(\(expression).value)"
        case .concrete: 
            return                                           expression
        case .generic(type: _, as: let type):
            return                           "\(type).init(\(expression))"
        }
    }
    func outer(expression:String) -> String 
    {
        switch self 
        {
        case .variant:
            return                               "\(expression).variant"
        case .enumeration   (type: let type):
            return  "\(type).init(value: Int.init(\(expression)))"
        case .concrete: 
            return                                  expression
        case .generic       (type: let type, as: _):
            return                  "\(type).init(\(expression))"
        }
    }
}
