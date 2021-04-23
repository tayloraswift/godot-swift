extension Godot.Library 
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
            print("initialized instance of '\(Self.self)'")
        }
        deinit 
        {
            print("deinitialized instance of '\(Self.self)'")
        }
    }
    enum MySignal:Godot.Signal 
    {
        typealias Value = (foo:Int, bar:Double)
        
        @Interface 
        static 
        var interface:Interface 
        {
            \.foo <- "foo"
            \.bar <- "bar"
        }
        static 
        var name:String 
        {
            "my_signal"
        }
    } 
    enum MyOtherSignal:Godot.Signal 
    {
        typealias Value = Bool
        
        @Interface 
        static 
        var interface:Interface 
        {
            \.self <- "value"
        }
        static 
        var name:String 
        {
            "my_other_signal"
        }
    }
    
    @Interface 
    static 
    var interface:Interface 
    {
        Interface.signals 
        {
            MySignal.self 
            MyOtherSignal.self
        }
        
        Interface.methods 
        {
            method(delegate:)                   <- "pass_zero_arguments"
            method(delegate:a:)                 <- "pass_one_argument"
            method(delegate:o:)                 <- "pass_object_argument"
            method(delegate:nil:)               <- "pass_null_argument"
            method(delegate:tuple:)             <- "pass_tuple_argument"
            method(delegate:mutatingTuple:)     <- "pass_inout_tuple_argument"
            
            method(delegate:mutating:)          <- "pass_inout_argument"
            method(delegate:mutating:mutating:) <- "pass_two_inout_arguments"
            
            clear(delegate:list:)               <- "clear_list_elements"
            
            concatenate(delegate:s1:s2:)        <- "concatenate_strings"
            returnString(delegate:)             <- "return_string"
            returnInoutString(delegate:s:)      <- "return_inout_string"
            returnInoutList(delegate:list:)     <- "return_inout_list"
            returnTuple(delegate:)              <- "return_tuple"
            
            returnVectors(delegate:)            <- "return_vectors"  
        }
        
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
        
        // math tests 
        let M:Vector3<Double>.Matrix    = ((1, 2, 3)*, (2, 3, 4)*, (3, 4, 5)*)
        let M_1:Vector3<Double>.Matrix  = Vector3.inverse(M)
        print(M >< M_1)
        print(M_1 >< M)
    }
    
    func method(delegate:Godot.Unmanaged.MeshInstance) 
    {
        Godot.print("hello from 0-argument method")
        
        delegate.emit(signal: (5, 4.20), as: MySignal.self)
    }
    func method(delegate:Godot.Unmanaged.MeshInstance, nil:Void) 
    {
        Godot.print("hello from nil-argument method")
    }
    func method(delegate:Godot.Unmanaged.MeshInstance, a:Int8) 
    {
        Godot.print("hello from 1-argument method, recieved: \(a)")
    }
    func method(delegate:Godot.Unmanaged.MeshInstance, o:Godot.AnyObject) 
    {
        Godot.print("hello from object-argument method, recieved: \(o)")
    }
    func method(delegate:Godot.Unmanaged.MeshInstance, tuple:(String, String)) 
    {
        Godot.print("hello from tuple-argument method, recieved: \(tuple)")
    }
    func method(delegate:Godot.Unmanaged.MeshInstance, mutatingTuple tuple:inout (String, String)) 
    {
        print("hello from tuple-argument inout method, recieved: \(tuple)")
        
        tuple.0 = "eternia"
        tuple.1 = "etheria"
    }
    
    func method(delegate:Godot.Unmanaged.MeshInstance, mutating a:inout String) 
    {
        print("hello from 1-argument inout method, recieved: \(a)")
        
        a = "mutated"
    }
    func method(delegate:Godot.Unmanaged.MeshInstance, mutating a:inout String, mutating b:inout String) 
    {
        print("hello from 2-argument inout method, recieved: \(a)")
        
        a = "mutated again"
        b = "mutated a third time"
    }
    func clear(delegate:Godot.Unmanaged.MeshInstance, list:Godot.List) 
    {
        print("hello from clear(delegate:list:), recieved: \(list)")
        
        for i:Int in list.indices 
        {
            print("removing element at index \(i)")
            list[i] = nil
        }
    }
    func concatenate(delegate:Godot.Unmanaged.MeshInstance, s1:String, s2:String) -> String 
    {
        print("hello from concatenate(delegate:s1:s2:), recieved: \(s1), \(s2)")
        return "\(s1)\(s2)"
    }
    func returnString(delegate:Godot.Unmanaged.MeshInstance) -> String 
    {
        print("hello from returnString(delegate:)")
        return "string created by returnString(delegate:)"
    }
    func returnInoutString(delegate:Godot.Unmanaged.MeshInstance, s:inout String) -> String 
    {
        print("hello from returnInoutString(delegate:s:), recieved: \(s)")
        s = "mutated by returnInoutString"
        return s
    }
    func returnInoutList(delegate:Godot.Unmanaged.MeshInstance, list:inout Godot.List) -> Godot.List 
    {
        print("hello from returnInoutList(delegate:list:), recieved: \(list)")
        // common pitfall! must be Optional<Godot.Variant>
        let a:Godot.Variant? = list[0]
        list[0] = list[1]
        list[1] = a
        
        let original:Godot.List = list 
        list = [original[2], original[3]]
        return original  
    }
    func returnTuple(delegate:Godot.Unmanaged.MeshInstance) -> (String, String) 
    {
        print("hello from returnTuple(delegate:)")
        return ("first", "second")
    }
    
    func returnVectors(delegate:Godot.Unmanaged.MeshInstance) -> (a:Vector3<Float>, b:Vector3<Float>, c:Vector3<Float>)
    {
        fatalError()
    }
}
