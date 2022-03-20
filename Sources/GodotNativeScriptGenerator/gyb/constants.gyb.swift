enum GlobalConstants 
{
    static 
    func url(_ symbol:String) -> String 
    {
        """
        https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#class-globalscope-constant-\
        \(String.init(symbol.lowercased().map 
        {
            $0 == "_" ? "-" : $0
        }))
        """
    }
    
    static 
    func swift(_ constants:[String: Int]) -> String
    {
        var constants:[String: Int] = constants
        
        let enumerations:
        [
            (name:String, prefix:String?, include:[(symbol:String, as:String)])
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
        
        var groups:[String: [(symbol:String, name:Words, value:Int)]] = [:]
        for (name, prefix, include):
            (
                String, 
                String?, 
                [(symbol:String, as:String)]
            ) 
            in enumerations
        {
            var group:[(symbol:String, name:String, value:Int)] = []
            for include:(symbol:String, as:String) in include 
            {
                guard let value:Int = constants.removeValue(forKey: include.symbol)
                else 
                {
                    fatalError("missing constant '\(include.symbol)'")
                }
                group.append((include.symbol, include.as, value))
            }
            if let prefix:String = (prefix.map{ "\($0)_" }) 
            {
                for (symbol, value):(String, Int) in constants 
                {
                    guard symbol.starts(with: prefix) 
                    else 
                    {
                        continue 
                    }
                    
                    let name:String 
                    switch String.init(symbol.dropFirst(prefix.count))
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
                    group.append((symbol, name, value))
                    // remove the constant from the dictionary, so it won’t 
                    // get picked up again
                    constants[symbol] = nil 
                }
            }
            groups[name] = group
            .map 
            {
                (
                    $0.symbol, 
                    Words.split(snake: $0.name)
                        .normalized(patterns: Words.Normalization.constants), 
                    $0.value
                )
            }
            .sorted 
            {
                ($0.name, $0.value) < ($1.name, $1.value)
            }
        }
        
        // can use `!` because keys "Error", "VariantOperator" are written in `enumerations`
        let errors:[(symbol:String, name:Words, value:Int)]        = groups.removeValue(forKey: "Error")!
        
        let operators:[(symbol:String, name:String, value:Int)]    = groups.removeValue(forKey: "VariantOperator")!
        .map 
        {
            ($0.symbol, $0.name.camelcased, $0.value)
        }
        // sorted by numeric code
        let variants:[(symbol:String, name:String, value:Int)]     = constants.compactMap 
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
            return ($0.key, name, $0.value)
        }
        .sorted 
        {
            $0.value < $1.value
        }
        
        return Source.fragment 
        {
            """
            extension Godot 
            """
            Source.block 
            {
                """
                /// enum Godot.Error
                /// :   Swift.Error 
                ///     An engine error.
                /// #   (godot-error)
                enum Error:Swift.Error
                """
                Source.block 
                {
                    """
                    /// case Godot.Error.unknown(code:)
                    ///     A game engine error whose numeric code is unrecognized by Godot Swift.
                    /// - code  :Int 
                    ///     The error code.
                    case unknown(code:Int)
                    
                    """
                    for (symbol, name, code):(String, Words, Int) in errors
                    {
                        """
                        /// case Godot.Error.\(name.camelcased)
                        ///     The [`\(symbol)`](\(Self.url(symbol))) error.
                        /// 
                        ///     The numeric code of this error is `\(code)`.
                        case \(name.camelcased)
                        """
                    }
                }
            }
            """
            extension Godot.Error
            """
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
                    for (_, name, code):(String, Words, Int) in errors 
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
                    for (_, name, code):(String, Words, Int) in errors 
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
            

            """
            /// struct Godot.VariantType
            /// :   Hashable 
            ///     A GDScript core type metatype identifier.
            /// 
            ///     This structure models the 
            ///     [`Godot::Variant::Type`](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-variant-type) 
            ///     enumeration. It is capable of representing variant metatypes 
            ///     that are not known to *Godot Swift*, which may occur in 
            ///     situations where Swift nativescripts are run by a different 
            ///     version of the Godot engine runtime than they were built for.
            /// #   (10:godot-variant-usage)
            
            /// struct Godot.VariantOperator
            /// :   Hashable 
            /// 
            ///     A GDScript variant operator.
            ///
            ///     This structure models the 
            ///     [`Godot::Variant::Operator`](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-variant-operator) 
            ///     enumeration.
            /// #   (10:godot-variant-usage)
            
            extension Godot
            """
            Source.block 
            {
                for (name, constants):(String, [(symbol:String, name:String, value:Int)]) in 
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
                        ///     The raw value of this enumeration case.
                        let value:Int
                        """
                        for constant:(symbol:String, name:String, value:Int) in constants 
                        {
                            """
                            /// static let Godot.\(name).\(constant.name):Self 
                            ///     The [`\(constant.symbol)`](\(Self.url(constant.symbol))) constant.
                            /// 
                            ///     The raw value of this constant is `\(constant.value)`.
                            static 
                            let \(constant.name):Self = .init(value: \(constant.value))
                            """
                        }
                    }
                }
                
                for (name, constants):(String, [(symbol:String, name:Words, value:Int)]) in 
                    (groups.sorted{ $0.key < $1.key })
                {
                    """
                    /// enum Godot.\(name)
                    /// #   (godot-global-constants)
                    enum \(name)
                    """
                    Source.block 
                    {
                        for constant:(symbol:String, name:Words, value:Int) in constants 
                        {
                            """
                            /// static let Godot.\(name).\(constant.name.camelcased):Int 
                            ///     The [`\(constant.symbol)`](\(Self.url(constant.symbol))) constant.
                            /// 
                            ///     The raw value of this constant is `\(constant.value)`.
                            static 
                            let \(constant.name.camelcased):Int = \(constant.value)
                            """
                        }
                    }
                }
            }
        }
    }
}
