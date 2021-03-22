extension Godot 
{
    @Interface 
    public static 
    var interface:Interface 
    {
        TestSemantics.self              <- "TestSemantics"
        TestSemantics.ARCManaged.self   <- "ARCManaged"
    }
} 

struct TestSemantics:Godot.NativeScript 
{
    final 
    class ARCManaged:Godot.NativeScript 
    {
        init(delegate _:Godot.AnyObject)
        {
            Godot.print("initialized instance of '\(Self.self)'")
        }
        deinit 
        {
            Godot.print("deinitialized instance of '\(Self.self)'")
        }
    }
    
    @Interface 
    static 
    var interface:Interface 
    {
        method(delegate:) <- "pass_zero_arguments"
        method(delegate:a:) <- "pass_one_argument"
        method(delegate:nil:) <- "pass_null_argument"
        method(delegate:tuple:) <- "pass_tuple_argument"
        method(delegate:mutatingTuple:) <- "pass_inout_tuple_argument"
        /* method(delegate:a:b:) <- "pass_two_arguments"
        methodTuple(delegate:tuple:) <- "pass_tuple_argument"
        methodTupleReturn(delegate:) <- "return_tuple_argument"
        
        clearTupleElement(delegate:tuple:) <- "clear_list_element"
        clearListElement(delegate:list:at:) <- "clear_list_element"
        
        methodReference(delegate:mutating:) <- "pass_reference"
        methodReferenceReturn(delegate:mutating:) <- "return_reference"
        
        methodInoutValue(delegate:mutating:) <- "pass_inout_value"
        methodInoutReference(delegate:mutating:) <- "pass_inout_reference" */
    }
    
    init(delegate:Godot.Unmanaged.MeshInstance)
    {
        Godot.print("initialized instance of '\(Self.self)'")
    }
    
    func method(delegate:Godot.Unmanaged.MeshInstance) 
    {
        Godot.print("hello from 0-argument method")
    }
    func method(delegate:Godot.Unmanaged.MeshInstance, nil:Void) 
    {
        Godot.print("hello from nil-argument method")
    }
    func method(delegate:Godot.Unmanaged.MeshInstance, a:Int8) 
    {
        Godot.print("hello from 1-argument method, recieved: \(a)")
    }
    func method(delegate:Godot.Unmanaged.MeshInstance, tuple:(String, String)) 
    {
        print("hello from tuple-argument method, recieved: \(tuple)")
    }
    func method(delegate:Godot.Unmanaged.MeshInstance, mutatingTuple tuple:inout (String, String)) 
    {
        print("hello from 1-argument inout method, recieved: \(tuple)")
        
        tuple.0 = "eternia"
        tuple.1 = "etheria"
    }
}
