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
        
        // gdscript class name, flags
        let info:(symbol:String, is:Flags)?
        // swift type 
        let name:String
        private(set)
        var parent:String?
        
        private(set)
        var children:[Node]
        
        init(name:String) 
        {
            self.children   = []
            self.name       = name 
            self.info       = nil
            self.parent     = nil
        }
        
        init(class:GodotAPI.Class) 
        {
            self.children   = []
            if `class`.singleton.isEmpty 
            {
                self.parent = `class`.parent.isEmpty ? nil : Self.name(`class`.parent)
                self.name   =                                Self.name(`class`.name)
                self.info   = 
                (
                    `class`.name, 
                    (
                        instantiable:   `class`.instantiable,
                        singleton:      false, 
                        // https://github.com/godotengine/godot-cpp/issues/432
                        // api.json bug: 
                        //      `Godot::Reference` is not tagged as managed, but is actually managed
                        managed:        `class`.managed || `class`.name == "Reference"
                    )
                )
            }
            else 
            {
                self.parent = Self.name("Object") // Godot.AnyDelegate
                self.name   = `class`.singleton
                self.info   =
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
            }
        }
        
        func append(child:Node) 
        {
            self.children.append(child)
        }
        // reparents the node
        func move(child:Node) 
        {
            child.parent = self.name
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
                name = "Delegate"
            case "Reference":
                name = "Object"
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
            self.name 
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
    let root:(unmanaged:Class.Node, object:Class.Node) = 
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
        
        // construct tree 
        var nodes:[String: Class.Node] = 
            .init(uniqueKeysWithValues: classes.map 
        {
            let node:Class.Node = .init(class: $0)
            return (node.name, node)
        })
        // sort to provide some stability in generated code
        for node:Class.Node in nodes.values.sorted(by: { $0.name < $1.name }) 
        {
            if  let name:String         = node.parent, 
                let parent:Class.Node   = nodes[name]
            {
                parent.append(child: node)
            }
        }
        // perform tree rotation so all unmanaged/singleton classes have a 
        // single ancestor 
        guard   let object:Class.Node   = nodes["Object"], 
                let delegate:Class.Node = nodes["Delegate"]
        else 
        {
            fatalError("missing 'Godot.Object' and 'Godot.Delegate' classes")
        }
        let unmanaged:Class.Node        = .init(name: "Unmanaged")
        for node:Class.Node in delegate.children where node !== object
        {
            unmanaged.move(child: node)
        }
        return (unmanaged: unmanaged, object: object)
    }()
    
    @Source.Code 
    static 
    var swift:String 
    {
        """
        // delegate class ancestor hierarchy
        extension Godot 
        {
            enum Ancestor 
            {
            }
        }
        extension Godot.Ancestor
        """
        Source.block 
        {
            """
            typealias Delegate = Object & Unmanaged 
            """
            for root:Class.Node in [Self.root.object, Self.root.unmanaged] 
            {
                for node:Class.Node in root.preorder 
                {
                    if      node.children.isEmpty 
                    {
                        "typealias \(node.name) = _GodotAncestor\(node.name)"
                    }
                    else if node.children.count == 1 
                    {
                        "typealias \(node.name) = \(node.children[0].name)"
                    }
                    else 
                    {
                        """
                        
                        typealias \(node.name) = 
                                \(node.children.map(\.name).joined(separator: " \n    &   "))
                        """
                    }
                }
            }
        }
        for node:Class.Node in Self.root.object.leaves + Self.root.unmanaged.leaves
        {
            """
            protocol _GodotAncestor\(node.name) {}
            """
        }
        // generate class inheritance hierarchy. 
        // `Godot.AnyDelegate`, `Godot.AnyUnmanaged` and `Godot.AnyObject`
        // have special behavior, so we define them manually
        """
        
        // delegate class inheritance tree
        protocol _GodotAnyDelegate:Godot.VariantRepresentable 
        {
            // settable because class metadata has to be loaded at runtime
            static 
            var metaclass:Godot.Metaclass 
            {
                get
                set 
            }
            
            init?(unretained:UnsafeMutableRawPointer) 
            var core:UnsafeMutableRawPointer 
            {
                get 
            }
        }
        protocol _GodotAnyObject:Godot.AnyDelegate              
        {
            // non-failable init assumes instance has been type-checked, and does 
            // not perform any retains!
            init(retained:UnsafeMutableRawPointer) 
        }
        protocol _GodotAnyUnmanaged:Godot.AnyDelegate
        {
            // non-failable init assumes instance has been type-checked, and does 
            // not perform any retains!
            init(core:UnsafeMutableRawPointer)
        }
        """
        for root:Class.Node in Self.root.object.children + Self.root.unmanaged.children 
        {
            // skip leaf nodes (final classes) 
            for node:Class.Node in root.preorder where !node.children.isEmpty
            {
                // cannot use `guard` in result builder
                if let parent:String = node.parent 
                {
                    // TODO: will need to place virtual method declarations here
                    """
                    protocol _GodotAny\(node.name):Godot.Any\(parent) {}
                    """
                }
                else 
                {
                    let _ = fatalError("unreachable")
                }
            }
        }
        """
        extension Godot
        """
        Source.block 
        {
            """
            typealias AnyDelegate = _GodotAnyDelegate
            
            """
            for node:Class.Node in Self.root.object.preorder + Self.root.unmanaged.preorder 
                where !node.children.isEmpty
            {
                "typealias Any\(node.name) = _GodotAny\(node.name)"
            }
        }
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
        var namespace:(godot:[String], unmanaged:[String], singleton:[String]) = 
        (
            [], [], []
        )
        for root:Class.Node in [Self.root.object, Self.root.unmanaged] 
        {
            for node:Class.Node in root.preorder 
            {
                // `Godot.Unmanaged` and `Godot.Singleton` are pseudoclasses, 
                // which only exist in protocol form, so do not emit a 
                // definition in this case
                if let info:(symbol:String, is:Class.Node.Flags) = node.info 
                {
                    let definition:String = Source.fragment 
                    {
                        let kind:String = info.is.managed ? "final class" : "struct"
                        if let parent:String = node.parent, node.children.isEmpty
                        {
                            // final class, no existential of its own, conforms 
                            // to its parent’s existential 
                            "\(kind) \(node.name):Godot.Any\(parent), Godot.Ancestor.\(node.name)"
                        }
                        else 
                        {
                            // open class, conforms to its own existential 
                            "\(kind) \(node.name):Godot.Any\(node.name), Godot.Ancestor.\(node.name)"
                        }
                        Source.block 
                        {
                            """
                            static 
                            var metaclass:Godot.Metaclass = "\(info.symbol)"
                            let core:UnsafeMutableRawPointer
                            """
                            if info.is.managed 
                            {
                                // sanity check 
                                let _ = assert(root === Self.root.object, node.name)
                                """
                                init(retained core:UnsafeMutableRawPointer) { self.core = core }
                                deinit               { Godot.runtime.release( self.core )      }
                                """
                            }
                            else 
                            {
                                // sanity check 
                                let _ = assert(root === Self.root.unmanaged, node.name)
                                """
                                init(core:UnsafeMutableRawPointer)          { self.core = core }
                                """
                            }
                        }
                    }
                    
                    if      info.is.managed 
                    {
                        let _ = namespace.godot.append(definition)
                    }
                    else if info.is.singleton 
                    {
                        let _ = namespace.singleton.append(definition)
                    }
                    else 
                    {
                        let _ = namespace.unmanaged.append(definition)
                    }
                }
            }
        }
        
        for (definitions, namespace):([String], String) in 
        [
            (namespace.godot,       "Godot"), 
            (namespace.unmanaged,   "Godot.Unmanaged"),
            (namespace.singleton,   "Godot.Singleton"),
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
    }
}
