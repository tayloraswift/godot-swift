extends Spatial

const TestSemantics = preload("res://lib/swift-library/TestSemantics.gdns")
const ARCManaged = preload("res://lib/swift-library/ARCManaged.gdns")

func _ready():
    var a:Array = [
        ARCManaged.new(), 
        ARCManaged.new(), 
        [ARCManaged.new(), ARCManaged.new()], 
        [ARCManaged.new(), ARCManaged.new()]
    ]
    
    var b:Array = ['hello', 'world']
    
    print(a)
    var test = TestSemantics.new()
    
    test.pass_zero_arguments()
    # test.pass_null_argument() # expected-fail
    test.pass_null_argument(null)
    
    test.pass_one_argument(127)
    
    print(b)
    test.pass_tuple_argument(b)
    print(b)
    test.pass_inout_tuple_argument(b)
    print(b)
    
    test.queue_free()
