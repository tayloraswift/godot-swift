extends Node

func _ready():
    print($delegate.foo)
    
    print($delegate.bar(2))
    
    $delegate.foo += 1
    
    print($delegate.foo)
    print($delegate.bar(3))
