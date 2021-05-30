import struct TSCBasic.AbsolutePath
import var TSCBasic.localFileSystem

extension Godot.Class 
{
    final 
    class Node 
    {        
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
        
        struct Constant 
        {
            struct Key:Hashable 
            {
                let symbol:String 
            }
            
            let name:Words 
            let value:Int
        }
        struct Property 
        {
            struct Key:Hashable 
            {
                let symbol:String 
                let name:Words 
                
                init(symbol:String, name:Words)
                {
                    self.symbol = symbol 
                    self.name   = name 
                }
                init(symbol:String)
                {
                    self.symbol = symbol 
                    self.name   = Words.split(snake: self.symbol)
                        .normalized(patterns: Words.Normalization.general) 
                }
            }
            
            struct Accessor 
            {
                unowned  
                let node:Node
                let index:Dictionary<Method.Key, Method>.Index
            }
            
            let get:Accessor,
                set:Accessor? 
            let index:Int?
            let type:Godot.KnownType 
            
            var `is`:(final:Bool, override:Bool)
        } 
        struct Method 
        {
            struct Key:Hashable 
            {
                let symbol:String 
                let name:Words 
                
                init(symbol:String, name:Words)
                {
                    self.symbol = symbol 
                    self.name   = name 
                }
                
                init(symbol:String)
                {
                    self.symbol = symbol 
                    self.name   = Words.split(snake: self.symbol)
                        .normalized(patterns: Words.Normalization.general) 
                }
            }
            enum Result:Equatable 
            {
                case returned(Godot.KnownType)
                case thrown
            }
            
            var parameters:[(label:String, name:String, type:Godot.KnownType)]
            let result:Result
             
            var `is`:(final:Bool, override:Bool, hidden:Bool)
        }
        
        struct Enumeration 
        {
            let symbol:String
            let name:Words 
            let cases:[(symbol:String, name:Words, rawValue:Int)]
        }
        
        let symbol:String 
        let name:Words, 
            namespace:Namespace 
        let `is`:(instantiable:Bool, singleton:Bool, managed:Bool)
        
        private(set) weak
        var parent:Node?
        private(set)
        var children:[Node]
        
        // members 
        let enumerations:[Enumeration]
        private(set)
        var constants:[Constant.Key: Constant], 
            properties:[Property.Key: Property], 
            methods:[Method.Key: Method]
        
        // member descriptors
        private 
        var unresolved:
        (
            constants:[String: Int],
            properties:[Godot.Class.Property],
            functions:[Godot.Class.Method]
        )
        
        init(descriptor:Godot.Class) 
        {    
            self.symbol     = descriptor.name
            self.parent     = nil 
            self.children   = []
            
            let namespace:Namespace, 
                name:Words 
            if descriptor.singleton.isEmpty 
            {
                self.is = 
                (
                    instantiable:   descriptor.instantiable,
                    singleton:      false, 
                    managed:        descriptor.managed 
                )
                namespace   = self.is.managed || descriptor.name == "Object" ? .root : .unmanaged
                name        = .name(class: descriptor.name)
            }
            else 
            {
                self.is =
                (
                    instantiable:   false,
                    singleton:      true,
                    managed:        false
                ) 
                namespace   = .singleton 
                name        = .name(class: descriptor.singleton)
            }
            
            // keep track of enum constants, to filter out duplicated class constants 
            var enumerationConstants:[String: Int] = [:]
            self.enumerations = descriptor.enumerations.map 
            {
                (enumeration:Godot.Class.Enumeration) in 
                
                enumerationConstants.merge(enumeration.cases){ (keep:Int, _:Int) in keep }
                
                let name:Words = .name(enumeration: enumeration.name, scope: name)
                let unfactored:[(symbol:String, name:Words, rawValue:Int)] = 
                    enumeration.cases.map 
                {
                    (
                        $0.key,
                        Words.split(snake: $0.key)
                            .normalized(patterns: Words.Normalization.general), 
                        $0.value
                    )
                }
                let cases:[(symbol:String, name:Words, rawValue:Int)]
                if name == ["Flags"]
                {
                    // special handling for enums called ‘Flags’
                    cases               = unfactored.map 
                    {
                        (
                            $0.symbol, 
                            $0.name == ["Flags", "Default"] ? ["Default"] : $0.name.factoring(out: ["Flag"]), 
                            $0.rawValue
                        )
                    }
                }
                else 
                {
                    let prefix:Words    = .greatestCommonPrefix(among: unfactored.map(\.name))
                    cases               = unfactored.map 
                    {
                        ($0.symbol, $0.name.factoring(out: prefix), $0.rawValue)
                    }
                }
                
                return .init(symbol: enumeration.name, name: name, cases: cases.sorted 
                {
                    // it is not enough to sort by raw value, since there are 
                    // multiple cases with the same raw value 
                    ($0.name, $0.rawValue) < ($1.name, $1.rawValue)
                })
            }
            
            self.namespace  = namespace 
            self.name       = name 
            self.constants  = [:]
            self.properties = [:]
            self.methods    = [:]
            self.unresolved = 
            (
                // ignore constants that have an enumeration case with the same value 
                constants:  descriptor.constants.filter 
                {
                    if let value:Int = enumerationConstants[$0.key], value == $0.value 
                    {
                        return false 
                    }
                    else 
                    {
                        return true 
                    }
                },
                properties: descriptor.properties, 
                functions:  descriptor.methods
            )
        }
    }
}
extension Godot.Class.Node 
{
    func append(child:Godot.Class.Node) 
    {
        child.parent = self
        self.children.append(child)
    }
    
    var preorder:[Godot.Class.Node] 
    {
        [self] + self.children.flatMap(\.preorder)
    }
    var leaves:[Godot.Class.Node] 
    {
        self.children.isEmpty ? [self] : self.children.flatMap(\.leaves)
    }
    
    private 
    func resolve() 
    {
        // build type database 
        var types:[String: Godot.KnownType] = 
        [
            "void"              :   .void,
            "bool"              :   .bool,
            "int"               :   .int,
            "float"             :   .float,
            "Vector2"           :   .vector2,
            "Vector3"           :   .vector3,
            "Color"             :   .vector4,
            
            "Quat"              :   .quaternion,
            "Plane"             :   .plane3,
            "Rect2"             :   .rectangle2,
            "AABB"              :   .rectangle3,
            "Transform2D"       :   .affine2,
            "Transform"         :   .affine3,
            "Basis"             :   .linear3,
            "RID"               :   .resourceIdentifier,
            
            "NodePath"          :   .nodePath,
            "String"            :   .string,
            "Array"             :   .list,
            "Dictionary"        :   .map,
            
            "PoolByteArray"     :   .uint8Array,
            "PoolIntArray"      :   .int32Array,
            "PoolRealArray"     :   .float32Array,
            "PoolStringArray"   :   .stringArray,
            "PoolVector2Array"  :   .vector2Array,
            "PoolVector3Array"  :   .vector3Array,
            "PoolColorArray"    :   .vector4Array,
            
            "Variant"           :   .variant,
            
            "enum.Error"                :   .enumeration("Godot.Error"),
            "enum.Variant::Type"        :   .enumeration("Godot.VariantType"),
            "enum.Variant::Operator"    :   .enumeration("Godot.VariantOperator"),
        ]
        
        for node:Godot.Class.Node in self.preorder
        {
            let symbol:String           = node.symbol, 
                type:Godot.KnownType    = .object("\(node.namespace).\(node.name)")
            guard types.updateValue(type, forKey: symbol) == nil 
            else 
            {
                fatalError("duplicate class 'Godot::\(symbol)'")
            }
            
            for enumeration:Enumeration in node.enumerations
            {
                let symbol:String           = "enum.\(symbol)::\(enumeration.symbol)", 
                    type:Godot.KnownType    = .enumeration(
                        "\(node.namespace).\(node.name).\(enumeration.name)")
                guard types.updateValue(type, forKey: symbol) == nil
                else 
                {
                    fatalError("duplicate enum '\(symbol)'")
                }
            }
        }
        
        self.resolve(types: types)
    }
    private 
    func resolve(types:[String: Godot.KnownType]) 
    {
        outer:
        for method:Godot.Class.Method in self.unresolved.functions
        {
            var description:String 
            {
                "method 'Godot::\(self.symbol)::\(method.name)'"
            }
            
            let key:Method.Key
            // quirk: 
            if  self.symbol == "Object", method.name == "tr"
            {
                key = .init(symbol: method.name, name: ["Translate"])
            }
            else 
            {
                key = .init(symbol: method.name)
            }
            
            var parameters:[(label:String, name:String, type:Godot.KnownType)]  = []
            var forbidden:Set<Words>                                            = []
            for argument:Godot.Class.Argument in method.arguments
            {
                guard let type:Godot.KnownType = types[argument.type]
                else 
                {
                    print("skipping \(description) (unknown parameter type: \(argument.type))")
                    continue outer 
                }
                
                // fix problematic labels 
                let label:Words, 
                    name:Words
                // quirks: 
                if      self.symbol     == "VisualServer", 
                        method.name     == "request_frame_drawn_callback", 
                        argument.name   == "where"
                {
                    label   = ["On"]
                    name    = ["Object"]
                }
                // set the label to '_', to avoid conflicting with TranslationServer.translate(message:)
                else if self.symbol     == "Object", 
                        method.name     == "tr", 
                        argument.name   == "message"
                {
                    label   = ["_"]
                    name    = ["Message"]
                }
                else if argument.name.prefix(3) == "arg", 
                        argument.name.dropFirst(3).allSatisfy(\.isNumber)
                {
                    label   = ["_"] 
                    name    = ["Argument\(argument.name.dropFirst(3))"]
                }
                else 
                {
                    label   = Words.split(snake: argument.name)
                        .normalized(patterns: Words.Normalization.general)
                        .factoring(out: key.name, forbidding: forbidden)
                    name    = Words.split(snake: argument.name)
                        .normalized(patterns: Words.Normalization.general)
                }
                parameters.append((label.camelcased, name.camelcased, type))
                
                // allow empty labels, but only on the first parameter 
                forbidden.insert(["_"])
                forbidden.insert(label)
            }
            
            let result:Method.Result 
            if  method.return == "enum.Error", 
                method.name   != "get_error",
                method.name   != "set_error"
            {
                result = .thrown
            }
            else if let type:Godot.KnownType = types[method.return] 
            {
                result = .returned(type)
            }
            else 
            {
                print("skipping \(description) (unknown return type: \(method.return))")
                continue outer 
            }
            
            var method:(key:Method.Key, value:Method) = 
            (
                key, 
                .init(parameters: parameters, result: result, 
                    is: (final: true, override: false, hidden: false))
            )
            // look for overridden methods 
            var current:Godot.Class.Node = self 
            while let superclass:Godot.Class.Node = current.parent 
            {
                if let overridden:Dictionary<Method.Key, Method>.Index = 
                    superclass.methods.index(forKey: method.key), 
                    !superclass.methods.values[overridden].is.hidden 
                {
                    // note: 
                    // -    the *return* type of an overriding method must be a 
                    //      *subclass* of the overridden return type.
                    // -    a *parameter* type of an overriding method must be a 
                    //      *superclass* of the overridden parameter type.
                    // we don’t have a good way of checking this right now, but 
                    // the swift compiler will enforce these rules when compiling 
                    // the generated code.
                    
                    // replace labels, since swift requires all overriding 
                    // methods to have the same argument labels
                    method.value.is.override  = true 
                    method.value.parameters   = superclass.methods.values[overridden].parameters 
                    
                    superclass.methods.values[overridden].is.final = false 
                    break 
                }
                current = superclass 
            }
            
            guard self.methods.updateValue(method.value, forKey: method.key) == nil 
            else 
            {
                fatalError("duplicate \(description)")
            }
        }
        
        // frame properties in Godot::AnimatedTexture seem to be specialized 
        // by index from 0 ... 255, ignore for now 
        outer:
        for property:Godot.Class.Property in self.unresolved.properties
            where !property.name.contains("/") 
        {
            var description:String
            {
                "property 'Godot::\(self.symbol)::\(property.name)'"
            }
            
            let index:Int? = property.index == -1 ? nil : property.index 
            let accessor:(get:Property.Accessor, set:Property.Accessor?)
            let getter:Method, 
                setter:Method?
            
            // find getter 
            if let get:Property.Accessor = self.lookup(method: .init(symbol: property.getter))
            {
                accessor.get    = get 
                getter          = get.node.methods.values[get.index]
                
                get.node.methods.values[get.index].is.hidden = true 
            }
            else 
            {
                print("skipping \(description) (could not find getter)")
                continue outer
            }
            // find setter 
            if  property.setter.isEmpty 
                
            {
                accessor.set    = nil 
                setter          = nil 
            }
            // quirk: Godot::StreamTexture::load_path uses the 
            // Godot::StreamTexture::load(path:) method as its setter. this 
            // isn’t a good model of its semantics, so we leave it as a get-only 
            // property.
            else if property.name == "load_path", self.symbol == "StreamTexture"
            {
                accessor.set    = nil 
                setter          = nil 
            }
            else if let set:Property.Accessor = self.lookup(method: .init(symbol: property.setter))
            {
                accessor.set    = set 
                setter          = set.node.methods.values[set.index]
                
                set.node.methods.values[set.index].is.hidden = true 
            }
            else 
            {
                print("skipping \(description) (could not find setter)")
                continue outer
            }
            
            guard case .returned(let type) = getter.result 
            else 
            {
                print("skipping \(description) (getter is throwing method)")
                continue outer
            }
            
            // sanity check 
            if let _:Int = index 
            {
                guard   case .int? = getter.parameters.first?.type, 
                        getter.parameters.count == 1
                else 
                {
                    fatalError("malformed getter for \(description)")
                }
            }
            else 
            {
                guard   getter.parameters.isEmpty 
                else 
                {
                    fatalError("malformed getter for \(description)")
                }
            }
            if let setter:Method = setter
            {
                guard let other:Godot.KnownType = setter.parameters.last?.type
                else 
                {
                    fatalError("malformed setter for \(description)")
                }
                if let _:Int = index 
                {
                    guard   case .int? = setter.parameters.first?.type,
                            setter.parameters.count == 2
                    else 
                    {
                        fatalError("malformed setter for \(description)")
                    }
                }
                else 
                {
                    guard   setter.parameters.count == 1
                    else 
                    {
                        fatalError("malformed setter for \(description)")
                    }
                }
                // some setters seem to have return values, skip them for now 
                guard case .returned(.void) = setter.result
                else 
                {
                    print("skipping \(description) (unsupported setter result type: \(setter.result))")
                    continue outer 
                }
                
                switch (type, other)
                {
                case (.enumeration, .int): 
                    break // okay 
                case (let get, let set):
                    guard get == set 
                    else 
                    {
                        fatalError("getter type (\(get)) for \(description) does not match setter type (\(set))")
                    }
                }
            }
            
            var property:(key:Property.Key, value:Property) = 
            (
                .init(symbol: property.name), 
                .init(get: accessor.get, set: accessor.set, index: index, 
                    type: type, is: (final: true, override: false))
            )
            // look for overridden properties 
            var current:Godot.Class.Node = self 
            while let superclass:Godot.Class.Node = current.parent 
            {
                if let overridden:Dictionary<Property.Key, Property>.Index = 
                    superclass.properties.index(forKey: property.key)
                {
                    // sanity check 
                    guard property.value.type == superclass.properties.values[overridden].type
                    else 
                    {
                        print("skipping \(description) (mismatched override signature)")
                        continue outer 
                    }
                    
                    property.value.is.override                          = true 
                    superclass.properties.values[overridden].is.final   = false 
                    break 
                }
                current = superclass 
            }
            
            guard self.properties.updateValue(property.value, forKey: property.key) == nil 
            else 
            {
                fatalError("duplicate \(description)")
            }
        } 
        
        // only include constants that do not override superclass constants 
        outer:
        for (symbol, value):(String, Int) in self.unresolved.constants
        {
            var description:String 
            {
                "constant 'Godot::\(self.symbol)::\(symbol)'"
            }
            
            // ignore `FLAG_MAX` constants, they are useless, and cause name collisions 
            switch symbol 
            {
            case "FLAG_MAX":    continue outer 
            default:            break 
            }
            
            let key:Constant.Key = .init(symbol: symbol)
            
            var current:Godot.Class.Node = self 
            while let superclass:Godot.Class.Node = current.parent  
            {
                if let overridden:Int = superclass.constants[key]?.value 
                {
                    guard overridden == value 
                    else 
                    {
                        fatalError("\(description) overrides superclass constant with different value")
                    }
                    
                    continue outer 
                }
                
                current = superclass
            }
            
            let name:Words = Words.split(snake: symbol)
                .normalized(patterns: Words.Normalization.general)
                .factoring(out: self.name)
            guard self.constants.updateValue(.init(name: name, value: value), forKey: key) == nil 
            else 
            {
                fatalError("duplicate \(description)")
            }
        } 
        
        // hide builtins 
        for symbol:(class:String, function:String) in 
        [
            ("Object",      "connect"),
            ("Object",      "disconnect"),
            ("Object",      "is_connected"),
            ("Object",      "emit_signal"),
            
            ("Reference",   "unreference"),
            ("Reference",   "reference"),
        ]
            where symbol.class == self.symbol 
        {
            guard let index:Dictionary<Method.Key, Method>.Index = 
                self.methods.index(forKey: .init(symbol: symbol.function))
            else 
            {
                fatalError("could not find builtin symbol 'Godot::\(symbol.class)::\(symbol.function)'")
            }
            
            self.methods.values[index].is.hidden = true 
        }
        
        // recurse over children 
        for child:Godot.Class.Node in self.children 
        {
            child.resolve(types: types)
        }
    }
    private 
    func lookup(method key:Method.Key) -> Property.Accessor?
    {
        var current:Godot.Class.Node = self
        while true 
        {
            if let index:Dictionary<Method.Key, Method>.Index = 
                current.methods.index(forKey: key)
            {
                return .init(node: current, index: index)
            }
            if let next:Godot.Class.Node = current.parent 
            {
                current = next
            }
            else 
            {
                return nil 
            }
        }
    } 
    
    fileprivate static 
    func tree(descriptors:[String: Godot.Class]) -> Godot.Class.Node  
    {
        // construct inheritance tree. 
        let nodes:[String: (node:Godot.Class.Node, parent:String?)] = descriptors.mapValues 
        {
            (.init(descriptor: $0), parent: $0.parent.isEmpty ? nil : $0.parent)
        }
        // sort to provide stability in generated code 
        for (node, parent):(Godot.Class.Node, String?) in nodes.values
            .sorted(by: { $0.node.name < $1.node.name }) 
        {
            // ignore disabled classes 
            // see: https://github.com/godotengine/godot-headers/issues/90
            switch node.symbol 
            {
            case "RootMotionView":      continue 
            default:                    break
            } 
            
            
            /* switch node.symbol 
            {
            case "Object", "Reference", "Node", "Spatial", "InputEventMouseButton", "InputEventKey", "InputEventMouse", "InputEventWithModifiers", "InputEvent", "Resource", "GlobalConstants":
                break 
            default: 
                continue 
            } */
            
            
            
            if let parent:String = parent
            {
                guard let parent:Godot.Class.Node = nodes[parent]?.node
                else 
                {
                    fatalError("missing class descriptor for class 'Godot::\(parent)'")
                }
                
                parent.append(child: node)
            }
        }
        
        guard let root:Godot.Class.Node = nodes["Object"]?.node
        else 
        {
            fatalError("missing class descriptor for class 'Godot::Object'")
        }
        
        root.resolve()
        
        return root
    }
}

extension Godot.Class 
{
    struct Tree
    {
        let root:Node 
        let constants:[String: Int]
        
        static 
        func load(api version:(major:Int, minor:Int, patch:Int)) -> Self 
        {
            let path:AbsolutePath = AbsolutePath.init(#filePath)
                .parentDirectory
                .parentDirectory
                .appending(components: "api", "\(version.major).\(version.minor).\(version.patch).json")
            
            guard let string:String = 
                try? TSCBasic.localFileSystem.readFileContents(path).description
            else 
            {
                fatalError("could not find or read 'godot-api.json' file")
            }
            
            guard   let json:JSON               =      .init(parsing: string),
                    let classes:[Godot.Class]   = try? .init(from: JSON.Decoder.init(json: json))
            else 
            {
                fatalError("could not parse 'godot-api.json' file")
            }
            
            let descriptors:[String: Godot.Class] = .init(uniqueKeysWithValues: classes.map 
            {
                ($0.name, $0)
            })
            
            guard let constants:[String: Int] = descriptors["GlobalConstants"]?.constants 
            else 
            {
                fatalError("missing class descriptor for class 'Godot::GlobalConstants'")
            }
            return .init(root: .tree(descriptors: descriptors), constants: constants)
        }
    }
}
