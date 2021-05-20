extends Node

const SwiftUnmanaged    = preload("res://libraries/godot-swift-examples/SwiftUnmanaged.gdns")
const SwiftManaged      = preload("res://libraries/godot-swift-examples/SwiftManaged.gdns")

func _ready():
    var unmanaged:Node = SwiftUnmanaged.new()
    
    unmanaged.queue_free()
    
    var managed_instances:Array = [
        SwiftManaged.new(),
        SwiftManaged.new(),
        SwiftManaged.new(),
    ]
    
    print(managed_instances)
    
    managed_instances = []
