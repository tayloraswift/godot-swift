extends Node


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
    pass # Replace with function body.


func receive_my_signal(foo, bar):
     print('recieved signal: ', foo, bar)
