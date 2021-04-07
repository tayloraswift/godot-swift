import struct TSCBasic.ByteString
import struct TSCBasic.AbsolutePath
import var TSCBasic.localFileSystem

//import struct Foundation.Data 
import class Foundation.JSONDecoder

enum GodotAPI 
{
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
extension GodotAPI.Class 
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
            name:String
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
        
        init(class:GodotAPI.Class) 
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
                    name:       Self.name(`class`.name)
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
                self.identifier = (namespace: .singleton, name: `class`.singleton)
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
        
        private static 
        func name(_ original:String) -> String
        {
            let name:String 
            switch original
            {
            case "Object":
                name = "AnyDelegate"
            case "Reference":
                name = "AnyObject"
            // fix problematic names 
            case "NativeScript":
                name = "NativeScriptDelegate"
            case let original:
                name = original
            }
            return name
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
extension GodotAPI.Class.Node 
{
    @Source.Code
    var existential:String 
    {
        ""
    }
}
extension GodotAPI
{
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
        
        // construct tree. include original parent keys in the dictionary 
        let nodes:[String: (parent:String?, node:Class.Node)] = 
            .init(uniqueKeysWithValues: classes.map 
        {
            return ($0.name, ($0.parent.isEmpty ? nil : $0.parent, Class.Node.init(class: $0)))
        })
        // sort to provide some stability in generated code
        for (parent, node):(String?, Class.Node) in 
            nodes.values.sorted(by: { $0.node.identifier.name < $1.node.identifier.name }) 
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
            where   node.identifier != (.unmanaged, "AnyDelegate") &&
                    node.identifier != (.root,      "AnyObject"  )
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
