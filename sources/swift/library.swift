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

enum E 
{
    struct TestStruct:Godot.NativeScript
    {
        @Interface
        static 
        var interface:Interface
        {
            \.y <- "y"
            
            foo(delegate:arg1:) <- "select_cell"
            bar(delegate:arg1:arg2:) <- "expand_array"
            
            baz(delegate:a:b:c:) <- "typed_func"
        }
        
        var y:Godot.Variant 
        {
            Godot.Void.init()
        }
        
        let x:Int
        init(delegate:Godot.MeshInstance)
        {
            Godot.print("init test struct")
            self.x = 5
        }
        
        func foo(delegate:Godot.MeshInstance, arg1:String) -> Godot.List 
        {
            Godot.print("hello from foo")
            print(arg1)
            return Godot.List.init(capacity: 5)
        }
        
        func bar(delegate:Godot.MeshInstance, arg1:Godot.List, arg2:UInt32?) -> Godot.Void
        {
            Godot.print("hello from bar", arg1, arg2)
            arg1[1] = Godot.Void.init()
            return Godot.Void.init()
        }
        
        func baz(delegate:Godot.MeshInstance, a:(Int, Int, (Int, Int)), b:Bool?, c:inout String) -> Double? 
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
            
            foo(delegate:) <- "foo_entry"
            bar(delegate:) <- "bar_entry"
        }
        
        init(delegate:Godot.MeshInstance)
        {
            Godot.print("init polyline")
            self.x = (15, 16, 17, 18, 19, 20)
        }
        
        func foo(delegate:Godot.MeshInstance) -> Godot.Void
        {
            print(self.x)
            return Godot.Void.init()
        }
        
        func bar(delegate:Godot.MeshInstance) -> Int?
        {
            print(self.x.0)
            return nil
        }
        
        var baz:Godot.Variant
        {
            Godot.Void.init()
        }
        
        deinit 
        {
            Godot.print("deinit polyline")
        } 
    }
}
