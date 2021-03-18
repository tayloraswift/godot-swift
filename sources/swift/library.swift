extension Godot 
{
    @Interface 
    public static 
    var interface:Interface 
    {
        E.Polyline.self <- "Polyline"
        E.Polyline.self <- "Polyline2"
        E.TestStruct.self <- "MapEditorInterface"
    }
} 

typealias Q = E.Polyline 

let toplevelFunction:@convention(swift) (E.TestStruct) -> (Int, Float, @escaping (Bool) throws -> ()) -> (UInt8, String) = { _ in fatalError() }
enum E 
{
    struct TestStruct:Godot.NativeScript
    {
        @Interface
        static 
        var interface:Interface
        {
            \.y <- "y"
            
            foo(delegate:_:) <- "select_cell"
            bar(delegate:_:) <- "expand_array"
            
            #if BUILD_STAGE_INERT
            baz(delegate:a:b:c:) <- "typed_func"
            toplevelFunction <- "attributed_func"
            #endif 
        }
        
        var y:Godot.Variant? 
        {
            nil
        }
        
        let x:Int
        init(delegate:Godot.MeshInstance)
        {
            Godot.print("init test struct")
            self.x = 5
        }
        
        func foo(delegate:Godot.MeshInstance, _ arguments:[Godot.Variant?]) -> Godot.Variant?
        {
            Godot.print("hello from foo")
            print(arguments)
            return Godot.List.init(capacity: 5)
        }
        
        func bar(delegate:Godot.MeshInstance, _ arguments:[Godot.Variant?]) -> Godot.Variant?
        {
            Godot.print("hello from bar")
            for argument:Godot.Variant? in arguments 
            {
                switch argument 
                {
                case let list as Godot.List:
                    list[1] = Godot.Void.init()
                default:
                    break 
                }
            }
            return nil
        }
        
        func baz(delegate:Godot.MeshInstance, a:(Int, Int, (Int, Int)), b:Bool?, c:String) -> Double? 
        {
            Godot.print("bar: \(c) \(a)")
            switch b 
            {
            case nil:
                return nil 
            case true?:
                return 1.1 
            case false?:
                return 2.2
            }
        }
    }
    
    final 
    class Polyline:Godot.NativeScript
    {
        let x:(Int, Int, Int, Int, Int, Int)
        
        @Interface
        static 
        var interface:Interface
        {
            \.baz <- "baz"
            
            foo(delegate:_:) <- "foo_entry"
            bar(delegate:_:) <- "bar_entry"
        }
        
        init(delegate:Godot.MeshInstance)
        {
            Godot.print("init polyline")
            self.x = (15, 16, 17, 18, 19, 20)
        }
        
        func foo(delegate:Godot.MeshInstance, _ arguments:[Godot.Variant?]) -> Godot.Variant?
        {
            print(self.x)
            return nil
        }
        
        func bar(delegate:Godot.MeshInstance, _ arguments:[Godot.Variant?]) -> Godot.Variant?
        {
            print(self.x.0)
            return nil
        }
        
        var baz:Godot.Variant? 
        {
            nil
        }
        
        deinit 
        {
            Godot.print("deinit polyline")
        } 
    }
}
