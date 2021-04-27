extends Spatial

const TestSemantics = preload("res://lib/swift-library/TestSemantics.gdns")
const ARCManaged = preload("res://lib/swift-library/ARCManaged.gdns")

func _ready():
    var test = TestSemantics.new()
    
    var a:Array = [
        ARCManaged.new(), 
        ARCManaged.new(), 
        [ARCManaged.new(), ARCManaged.new()], 
        [ARCManaged.new(), ARCManaged.new()], 
        ARCManaged.new(), 
    ]
    
    print('a: ', a)
    print(test.return_inout_list(a))
    print('a: ', a)
    test.clear_list_elements(a) 
    print('a: ', a)
    
    var b:Array = ['hello', 'world']
    
    $SoftBody.pass_zero_arguments()
    
    print(test.int_value)
    var x = 6
    test.int_value = x 
    print(x)
    print($SoftBody.int_value)
    
    test.pass_zero_arguments()
    # test.pass_null_argument() # expected-fail
    if false:
        test.pass_null_argument(null)
        
        test.pass_one_argument(127)
        
        var object = Resource.new()
        test.pass_object_argument(object)
        
        print(b)
        test.pass_tuple_argument(b)
        print(b)
        test.pass_inout_tuple_argument(b)
        print(b)
        
        var s1:String = 'string 1'
        var s2:String = 'string 2'
        print('s1: ', s1, ', s2: ', s2)
        test.pass_inout_argument(s1)
        print('s1: ', s1, ', s2: ', s2)
        test.pass_two_inout_arguments(s1, s2)
        print('s1: ', s1, ', s2: ', s2)
        
        print(test.concatenate_strings('head', 'tail'))
        print(test.return_string())
        print('s2: ', s2)
        print(test.return_inout_string(s2))
        print('s2: ', s2)
        print(test.return_tuple())
        
        print('finished semantics tests')
    
    test.queue_free()
