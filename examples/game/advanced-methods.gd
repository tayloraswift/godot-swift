extends Node

func _ready():
    $delegate.void_argument(null)
    
    $delegate.optional_argument(10)
    $delegate.optional_argument(null)
    
    $delegate.multiple_arguments(true, 3, Vector2(0.5, 0.75))
    
    var strings:Array = [
        'element (0)', [
            'element (1, 0)', 
            'element (1, 1)'
        ]
    ]
    
    $delegate.tuple_argument(strings)
    $delegate.list_argument(strings)
    
    var x:int = 5 
    print('old value of `x`: ', x)
    $delegate.inout_argument(x)
    print('new value of `x`: ', x)
    
    print('old value of `strings`: ', strings)
    $delegate.inout_tuple_argument(strings)
    print('new value of `strings`: ', strings)
    
    print('non-negative: ', $delegate.optional_return( 1))
    print('non-negative: ', $delegate.optional_return(-1))

    print('returned tuple: ', $delegate.tuple_return())
