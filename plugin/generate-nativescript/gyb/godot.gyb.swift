import struct TSCBasic.ByteString
import struct TSCBasic.AbsolutePath
import var TSCBasic.localFileSystem

//import struct Foundation.Data 
import class Foundation.JSONDecoder

struct Words:Equatable, CustomStringConvertible
{
    private 
    var components:[String] 
    let original:String
    
    static 
    func split(pascal:String) -> Self 
    {
        var words:[String]  = []
        var word:String     = ""
        for character:Character in pascal 
        {
            if  character.isUppercase, 
                let last:Character = word.last, last.isLowercase 
            {
                words.append(word)
                word = ""
            }
            // remove internal underscores (keep leading underscores)
            if character == "_", !word.isEmpty
            {
                words.append(word)
                word = ""
            }
            else 
            {
                // if starting a new word, make sure it starts with an 
                // uppercase letter (needed for `Tracking_status`)
                if word.isEmpty, character.isLowercase 
                {
                    word.append(character.uppercased())
                }
                else 
                {
                    word.append(character)
                }
            }
        }
        
        if !word.isEmpty 
        {
            words.append(word)
        }
        return .init(components: words, original: pascal)
    }
    
    static 
    func split(snake:String, lowercasing:Bool = true) -> Self
    {
        .init(components: snake.split(separator: "_").map
        { 
            if let head:Character = $0.first 
            {
                return "\(head)\($0.dropFirst().lowercased())"
            }
            else 
            {
                // should never have empty subsequences 
                return .init($0)
            }
        }, original: snake)
    }
    
    // expands unswifty abbreviations, and fix some strange spellings 
    mutating 
    func normalize() 
    {
        for i:Int in self.components.indices.dropLast() 
        {
            if self.components[i ..< i + 2] == ["Counter", "Clockwise"] 
            {
                self.components[i    ] = "Counterclockwise"
                self.components[i + 1] = ""
            }
        }
        self.components = self.components.compactMap 
        {
            switch $0 
            {
            case "":        return  nil
            case "Func":    return "Function"
            case "Op":      return "Operator"
            case "Len":     return "Length"
            case "Interp":  return "Interpolation"
            case "Mult":    return "Multiplication"
            case "Param":   return "Parameter"
            case "Poly":    return "Polygon"
            case "Assign":  return "Assignment"
            case "Ref":     return "Reference"
            case "Lib":     return "Library"
            case "Mem":     return "Memory"
            case "Tex":     return "Texture"
            case "Subdiv":  return "Subdivision"
            case "Accel":   return "Acceleration"
            case "Anim":    return "Animation"
            case "Expo":    return "Exponential"
            case let word:  return word
            }
        }
    }
    // strips meaningless prefixes
    mutating 
    func factor(out other:Self) 
    {
        // most nested types have the form 
        // scope:   'Foo' 'Bar' 'Baz' 
        // nested:        'Bar' 'Baz' 'Qux'
        // 
        // we want to reduce it to just 'Qux'
        for i:Int in (0 ... min(self.components.count - 1, other.components.count)).reversed()
        {
            // do not factor if it would result in the identifier 'Type', or 
            // an identifier that would begin with a numeral 
            if  self.components.prefix(i)    == other.components.suffix(i), 
                self.components.dropFirst(i) != ["Type"]
            {
                if self.components.dropFirst(i).first?.first?.isNumber ?? true
                {
                    continue 
                }
                
                self.components.removeFirst(i)
                return 
            }
        }
    }
    
    static 
    func greatestCommonPrefix(among group:[Self]) -> Self 
    {
        var prefix:[String] = []
        for i:Int in 0 ..< (group.map(\.components.count).min() ?? 0)
        {
            let unique:Set<String> = .init(group.map(\.components[i]))
            if let first:String = unique.first, unique.count == 1 
            {
                prefix.append(first)
            }
            else 
            {
                break 
            }
        }
        return .init(components: prefix, original: "")
    }
    
    var description:String 
    {
        self.components.joined()
    }
    var camelcased:String 
    {
        if let head:String = self.components.first?.lowercased() 
        {
            let escaped:String 
            if self.components.dropFirst().isEmpty
            {
                // escape keywords 
                switch head 
                {
                case "in", "self", "continue", "default", "static":  
                    escaped = "`\(head)`"
                case let head: 
                    escaped = head 
                }
            }
            else 
            {
                escaped = head 
            }
            return "\(escaped)\(self.components.dropFirst().joined())"
        }
        else 
        {
            return self.description
        }
    }
}

enum Godot 
{
    // symbol name mappings 
    private static 
    func name(class original:String) -> Words
    {
        let reconciled:String 
        switch original
        {
        case "Object":          reconciled = "AnyDelegate"
        case "Reference":       reconciled = "AnyObject"
        // fix problematic names 
        case "NativeScript":    reconciled = "NativeScriptDelegate"
        case let original:      reconciled = original 
        }
        
        var words:Words = .split(pascal: reconciled)
        words.normalize()
        
        /* if "\(words)" != original 
        {
            print("'\(original)' -> '\(words)'")
        } */
        
        return words 
    }
    private static 
    func name(enumeration original:String, scope:Words) -> Words
    {
        let reconciled:String
        switch ("\(scope)", original)
        {
        // fix problematic names 
        case ("VisualShader", "Type"):  reconciled = "Shader"
        case ("IP", "Type"):            reconciled = "Version"
        case let (_, original):         reconciled = original
        }
        
        var words:Words = .split(pascal: reconciled)
        words.normalize()
        words.factor(out: scope)
        
        /* if "\(words)" != original 
        {
            print("'\(scope).\(original)' -> '\(scope).\(words)'")
        } */
        
        return words
    }
    
    struct Class:Codable 
    {
        enum API:String, Codable 
        {
            case core   = "core"
            case tools  = "tools"
        }
        
        struct Argument:Codable 
        {
            let name:String
            let type:String
            //let defaulted:Bool
            let `default`:String

            enum CodingKeys:String, CodingKey 
            {
                case name       = "name"
                case type       = "type"
                //case defaulted  = "has_default_value"
                case `default`  = "default_value"
            }
        }
        
        struct Signal:Codable 
        {
            let name:String
            let arguments:[Argument]
        }
        
        struct Property:Codable 
        {
            let name:String
            let type:String
            let getter:String
            let setter:String
            let index:Int
        }
        
        struct Method:Codable 
        {
            let name:String 
            let arguments:[Argument]
            let `return`:String
            
            let editor:Bool
            let noscript:Bool
            let nonmutating:Bool
            //let reverse:Bool
            let virtual:Bool 
            let variadic:Bool 
            //let fromScript:Bool

            enum CodingKeys:String, CodingKey 
            {
                case name           = "name"
                case arguments      = "arguments"
                case `return`       = "return_type"
                
                case editor         = "is_editor"
                case noscript       = "is_noscript"
                case nonmutating    = "is_const"
                //case reverse        = "is_reverse"
                case virtual        = "is_virtual"
                case variadic       = "has_varargs"
                // case fromScript     = "is_from_script"
            }
        }
        
        struct Enumeration:Codable 
        {
            let name:String
            let cases:[String: Int]
            
            enum CodingKeys:String, CodingKey 
            {
                case name   = "name"
                case cases  = "values"
            }
        }
        
        let name:String 
        let parent:String
        
        let api:API 
        
        //var singleton:Bool
        let singleton:String
        
        let instantiable:Bool 
        let managed:Bool
        
        let constants:[String: Int]
        
        let properties:[Property]
        let methods:[Method]
        let signals:[Signal]
        let enumerations:[Enumeration]

        enum CodingKeys:String, CodingKey 
        {
            case name           = "name"
            case parent         = "base_class"
            case api            = "api_type"
            case singleton      = "singleton_name"
            case instantiable   = "instanciable"
            case managed        = "is_reference"
            case constants      = "constants" 
            case properties     = "properties"
            case signals        = "signals"
            case methods        = "methods"
            case enumerations   = "enums"
        }
    }
}
extension Godot.Class 
{
    final 
    class Node 
    {
        typealias Flags = 
        (
            instantiable:Bool, 
            singleton:Bool, 
            managed:Bool
        )
        typealias Identifier = 
        (
            namespace:Namespace,
            name:Words
        )
        enum Namespace:String, CustomStringConvertible
        {
            case root       = "Godot"
            case unmanaged  = "Godot.Unmanaged"
            case singleton  = "Godot.Singleton"
            
            var description:String 
            {
                self.rawValue
            }
        }
        
        // gdscript class name, flags
        let info:(symbol:String, is:Flags)
        // swift type 
        let identifier:Identifier 
        
        private(set)
        var children:[Node],
            parent:Identifier?
        
        // members 
        let enumerations:[(name:Words, cases:[(name:Words, rawValue:Int)])]
        
        init(class:Godot.Class) 
        {
            self.children   = []
            self.parent     = nil 
            if `class`.singleton.isEmpty 
            {
                self.info       = 
                (
                    `class`.name, 
                    (
                        instantiable:  `class`.instantiable,
                        singleton:      false, 
                        // https://github.com/godotengine/godot-cpp/issues/432
                        // api.json bug: 
                        //      `Godot::Reference` is not tagged as managed, but is actually managed
                        managed:       `class`.managed || `class`.name == "Reference"
                    )
                )
                self.identifier = 
                (
                    namespace:  self.info.is.managed || `class`.name == "Object" ? .root : .unmanaged,
                    name:       Godot.name(class: `class`.name)
                )
            }
            else 
            {
                self.info       =
                (
                    `class`.name, 
                    (
                        instantiable:   false,
                        singleton:      true,
                        // https://github.com/godotengine/godot/pull/36506 
                        // api.json bug: 
                        //      `Godot::_Marshalls` is tagged as subclass of 
                        //      `Godot::Reference` (Godot.Object), but is actually a 
                        //      subclass of `Godot::Object` (Godot.Unmanaged). 
                        //      
                        //      however, this only affects singletons, which we import as 
                        //      unmanaged anyway.
                        managed:        false
                    )
                ) 
                self.identifier = (namespace: .singleton, name: Godot.name(class: `class`.singleton))
            }
            
            let scope:Words = self.identifier.name
            self.enumerations = `class`.enumerations.map 
            {
                (enumeration:Godot.Class.Enumeration) in 
                
                var cases:[(name:Words, rawValue:Int)] = 
                    enumeration.cases.sorted(by: {$0.value < $1.value}).map 
                {
                    var name:Words = .split(snake: $0.key)
                    name.normalize()
                    return (name, $0.value)
                }
                let scope:Words     = Godot.name(enumeration: enumeration.name, scope: scope)
                let prefix:Words    = .greatestCommonPrefix(among: cases.map(\.name))
                for i:Int in cases.indices 
                {
                    cases[i].name.factor(out: prefix)
                }
                return (scope, cases)
            }
        }
        
        func append(child:Node) 
        {
            child.parent = self.identifier
            self.children.append(child)
        }
        
        var preorder:[Node] 
        {
            [self] + self.children.flatMap(\.preorder)
        }
        var leaves:[Node] 
        {
            self.children.isEmpty ? [self] : self.children.flatMap(\.leaves)
        }
        
        @Source.Code
        var description:String 
        {
            "\(self.identifier.namespace).\(self.identifier.name)" 
            Source.fragment(indent: 1)
            {
                for child:Node in self.children 
                {
                    child.description
                }
            }
        }
    }
}
extension Godot.Class.Node 
{
    @Source.Code
    var existential:String 
    {
        ""
    }
}
extension Godot
{
    enum KnownType 
    {
        case void 
        case bool 
        case int 
        case float 
        case vector2
        case vector3
        
        case rectangle2 
        case rectangle3
        case affine2 
        case affine3
        case linear3
        
        case string 
        case list 
        case map 
        
        case object(String)
        case enumeration(String)
        
        case unsupported
    }
    
    static 
    var tree:Class.Node  
    {
        let path:AbsolutePath = AbsolutePath.init(#filePath)
            .parentDirectory.appending(component: "godot-api.json")
        
        guard let file:ByteString = try? TSCBasic.localFileSystem.readFileContents(path)
        else 
        {
            fatalError("could not find or read 'godot-api.json' file")
        }
        
        let classes:[Class]
        do 
        {
            classes = try JSONDecoder.init().decode([Class].self, from: .init(file.contents))
        }
        catch let error 
        {
            fatalError("could not parse 'godot-api.json' file (\(error))")
        }
        
        // construct symbol mappings. include original parent keys in the dictionary 
        let nodes:[String: (parent:String?, node:Class.Node)] = 
            .init(uniqueKeysWithValues: classes.map 
        {
            return ($0.name, ($0.parent.isEmpty ? nil : $0.parent, Class.Node.init(class: $0)))
        })
        
        // build type database 
        var types:[String: KnownType] = 
        [
            "void"              :   .void,
            "bool"              :   .bool,
            "int"               :   .int,
            "float"             :   .float,
            "Vector2"           :   .vector2,
            "Vector3"           :   .vector3,
            
            "Rect2"             :   .rectangle2,
            "AABB"              :   .rectangle3,
            "Transform2D"       :   .affine2,
            "Transform"         :   .affine3,
            "Basis"             :   .linear3,
            
            "String"            :   .string,
            "Array"             :   .list,
            "Dictionary"        :   .map,
            
            "RID"               :   .unsupported,
            "NodePath"          :   .unsupported,
            "Color"             :   .unsupported,
            "Plane"             :   .unsupported,
            "Quat"              :   .unsupported,
            
            "PoolByteArray"     :   .unsupported,
            "PoolIntArray"      :   .unsupported,
            "PoolRealArray"     :   .unsupported,
            "PoolStringArray"   :   .unsupported,
            "PoolVector2Array"  :   .unsupported,
            "PoolVector3Array"  :   .unsupported,
            "PoolColorArray"    :   .unsupported,
            
            "Variant"           :   .unsupported,
            // hacks
            "enum.Variant::Type"        :   .unsupported,
            "enum.Variant::Operator"    :   .unsupported,
            "enum.Error"                :   .unsupported,
        ]
        for (key, node):(String, Class.Node) in nodes.mapValues(\.node)
        {
            assert(types[key] == nil)
            let scope:String    = "\(node.identifier.namespace).\(node.identifier.name)"
            types[key]          = .object(scope)
            
            for enumeration:Words in node.enumerations.map(\.name) 
            {
                let key:String = "enum.\(key)::\(enumeration.original)"
                assert(types[key] == nil)
                types[key] = .enumeration("\(scope).\(enumeration)")
            }
        }
        
        for `class`:Class in classes 
        {
            for method:Class.Method in `class`.methods 
            {
                for type:String in method.arguments.map(\.type) + [method.return]
                {
                    if types[type] == nil
                    {
                        print("unknown type: \(type)")
                    }
                }
            }
        }
        //let _types:Set<String> = .init(classes.flatMap 
        //{
        //    $0.methods.flatMap 
        //    {
        //        $0.arguments.map(\.type) + [$0.return]
        //    }
        //})
        //print(_types.sorted())
        
        // construct tree. sort to provide some stability in generated code
        for (parent, node):(String?, Class.Node) in 
            nodes.values.sorted(by: { "\($0.node.identifier.name)" < "\($1.node.identifier.name)" }) 
        {
            if  let key:String          = parent, 
                let parent:Class.Node   = nodes[key]?.node
            {
                parent.append(child: node)
            }
        }
        
        guard let root:Class.Node = nodes["Object"]?.node
        else 
        {
            fatalError("missing 'Godot.AnyDelegate' root class")
        }
        return root
    }
    
    private static 
    func definitions(root:Class.Node) -> (godot:[String], unmanaged:[String], singleton:[String])
    {
        var definitions:(godot:[String], unmanaged:[String], singleton:[String]) = 
        (
            [], [], []
        )
        for node:Class.Node in root.preorder 
            // skip `AnyDelegate` and `AnyObject`, which have special behavior
            where   node.identifier != (.unmanaged, .split(pascal: "AnyDelegate")) &&
                    node.identifier != (.root,      .split(pascal: "AnyObject"  ))
        {
            guard let parent:Class.Node.Identifier = node.parent 
            else 
            {
                continue 
            }
            let definition:String = Source.fragment 
            {
                if node.children.isEmpty 
                {
                "final" 
                }
                "class \(node.identifier.name):\(parent.namespace).\(parent.name)"
                Source.block 
                {
                    """
                    override class var symbol:Swift.String { "\(node.info.symbol)" }
                    """
                    for (name, cases):(Words, [(name:Words, rawValue:Int)]) in 
                        node.enumerations 
                    {
                        """
                        
                        enum \(name):Int 
                        """
                        Source.block 
                        {
                            var seen:[Int: Words] = [:]
                            for (name, code):(Words, Int) in cases 
                            {
                                // handle colliding enum rawvalues 
                                if let canonical:Words = seen[code]
                                {
                                    """
                                    static 
                                    var  \(name.camelcased):Self { .\(canonical.camelcased) }
                                    """
                                }
                                else 
                                {
                                    "case \(name.camelcased) = \(code)"
                                    let _ = seen[code] = name
                                }
                            }
                        }
                    }
                }
            }
            switch node.identifier.namespace 
            {
            case .root:         definitions.godot.append(definition)
            case .unmanaged:    definitions.unmanaged.append(definition)
            case .singleton:    definitions.singleton.append(definition)
            }
        }
        return definitions
    }
    
    @Source.Code 
    static 
    var swift:String 
    {
        Source.fragment(filename: "external.swift.fragment")
        Source.fragment(filename: "runtime.swift.fragment")
        Source.fragment(filename: "variant.swift.fragment")
        Source.fragment(filename: "dsl.swift.fragment")
        
        for name:String in 
        [
            "node_path", "string", "array", "dictionary", 
            "pool_byte_array", 
            "pool_int_array",
            "pool_real_array",
            "pool_string_array",
            "pool_vector2_array",
            "pool_vector3_array",
            "pool_color_array",
        ]
        {
            """
            extension godot_\(name):Godot.RawReference
            {
                init(with initializer:(UnsafeMutablePointer<Self>) -> ()) 
                {
                    self.init()
                    initializer(&self)
                }
                mutating 
                func `deinit`()
                {
                    Godot.api.1.0.godot_\(name)_destroy(&self)
                }
            }
            """
        }
        
        // generate variant hooks for pool arrays 
        for (swift, godot, array, storage):(String, String?, String, String?) in 
        [
            ("UInt8",                   nil,                "pool_byte_array",      nil),
            ("Int32",                   nil,                "pool_int_array",       nil),
            ("Float32",                 nil,                "pool_real_array",      nil),
            ("String",                  "godot_string",     "pool_string_array",    nil),
            ("Vector<Self, Scalar>",    "godot_vector2",    "pool_vector2_array",   "SIMD2"),
            ("Vector<Self, Scalar>",    "godot_vector3",    "pool_vector3_array",   "SIMD3"),
            ("Vector<Self, Scalar>",    "godot_color",      "pool_color_array",     "SIMD4"),
        ]
        {
            let type:String = storage == nil ? "Self" : swift
            if let storage:String = storage 
            {
                "extension \(storage):Godot.ArrayElementStorage where Scalar == Float32"
            }
            else 
            {
                "extension \(swift):Godot.ArrayElement"
            }
            Source.block 
            {
                """
                typealias RawArrayReference = godot_\(array)
                
                static 
                func downcast(array value:Godot.Variant.Unmanaged) -> RawArrayReference?
                {
                    value.load(where: GODOT_VARIANT_TYPE_\(array.uppercased()), 
                        Godot.api.1.0.godot_variant_as_\(array))
                }
                static 
                func upcast(array value:RawArrayReference) -> Godot.Variant.Unmanaged
                {
                    withUnsafePointer(to: value) 
                    {
                        .init(value: $0, Godot.api.1.0.godot_variant_new_\(array))
                    }
                }
                static 
                func convert(array godot:RawArrayReference) -> [\(type)]
                """
                Source.block
                {
                    """
                    guard let lock:UnsafeMutablePointer<godot_\(array)_read_access> = 
                        withUnsafePointer(to: godot, Godot.api.1.0.godot_\(array)_read)
                    else 
                    {
                        fatalError("recieved nil pointer from `godot_\(array)_read(_:)`")
                    }
                    defer 
                    {
                        Godot.api.1.0.godot_\(array)_read_access_destroy(lock)
                    }
                    let count:Int = .init(
                        withUnsafePointer(to: godot, Godot.api.1.0.godot_\(array)_size))
                    return .init(unsafeUninitializedCapacity: count) 
                    """
                    Source.block
                    {
                        """
                        guard let source:UnsafePointer<\(godot ?? "Self")> = 
                            Godot.api.1.0.godot_\(array)_read_access_ptr(lock)
                        else 
                        {
                            fatalError("recieved nil pointer from `godot_\(array)_read_access_ptr(_:)`")
                        }
                        """
                        if let _:String = godot
                        {
                            """
                            if let base:UnsafeMutablePointer<\(type)> = $0.baseAddress 
                            {
                                for i:Int in 0 ..< count 
                                {
                                    (base + i).initialize(to: source[i].unpacked)
                                }
                            }
                            """
                        }
                        else 
                        {
                            """
                            $0.baseAddress?.initialize(from: source, count: count)
                            """
                        }
                        """
                        $1 = count 
                        """
                    }
                }
                """
                static 
                func convert(array swift:[\(type)]) -> RawArrayReference
                """
                Source.block 
                {
                    """
                    var array:godot_\(array) = .init(with: Godot.api.1.0.godot_\(array)_new)
                    Godot.api.1.0.godot_\(array)_resize(&array, .init(swift.count))
                    
                    guard let lock:UnsafeMutablePointer<godot_\(array)_write_access> = 
                        Godot.api.1.0.godot_\(array)_write(&array)
                    else 
                    {
                        fatalError("recieved nil pointer from `godot_\(array)_write(_:)`")
                    }
                    defer 
                    {
                        Godot.api.1.0.godot_\(array)_write_access_destroy(lock)
                    }
                    
                    guard let destination:UnsafeMutablePointer<\(godot ?? "Self")> = 
                        Godot.api.1.0.godot_\(array)_write_access_ptr(lock)
                    else 
                    {
                        fatalError("recieved nil pointer from `godot_\(array)_write_access_ptr(_:)`")
                    }
                    """
                    if let _:String = godot
                    {
                        "for (i, element):(Int, \(type)) in swift.enumerated()"
                        Source.block
                        {
                            if swift == "String" 
                            {
                                "destination[i].deinit() // is this needed?"
                            }
                            "destination[i] = .init(packing: element)"
                        }
                    }
                    else 
                    {
                        """
                        swift.withUnsafeBufferPointer 
                        {
                            guard let base:UnsafePointer<Self> = $0.baseAddress
                            else 
                            {
                                return 
                            }
                            destination.initialize(from: base, count: swift.count)
                        }
                        """
                    }
                    """
                    return array
                    """
                }
            }
        }
        
        let root:Class.Node = Self.tree
        """
        extension Godot 
        {
            enum Unmanaged 
            {
            }
            enum Singleton 
            {
            }
        }
        """
        let definitions:(godot:[String], unmanaged:[String], singleton:[String]) = 
            Self.definitions(root: root)
        
        for (definitions, namespace):([String], Class.Node.Namespace) in 
        [
            (definitions.godot,     .root), 
            (definitions.unmanaged, .unmanaged),
            (definitions.singleton, .singleton),
        ] 
        {
            """
            extension \(namespace) 
            """
            Source.block 
            {
                for definition:String in definitions 
                {
                    definition
                }
            }
        }
        """
        // table for setting global type tags 
        extension Godot
        """
        Source.block 
        {
            """
            // type metadata table
            static 
            let DelegateTypes:[AnyDelegate.Type] =
            """
            Source.block(delimiters: ("[", "]"))
            {
                for node:Class.Node in Self.tree.preorder 
                {
                    "\(node.identifier.namespace).\(node.identifier.name).self,"
                }
            }
        }
    }
}
