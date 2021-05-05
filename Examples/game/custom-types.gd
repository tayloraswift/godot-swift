extends Node

func _ready():
    var mouse:InputEventMouseButton = InputEventMouseButton.new()
    var key:InputEventKey           = InputEventKey.new()
    
    $delegate.push_inputs([mouse, key])
    # $delegate.push_inputs([mouse])
    
    var zero:int = 0 
    var one:int  = 1
    $delegate.x = zero
    $delegate.x = one
    $delegate.x = 0.75 
    # $delegate.x = 1.5
    
    $delegate.x = 1.0 
    print(typeof($delegate.x) == TYPE_INT)
