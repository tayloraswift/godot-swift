extends Node

func _ready():
    pass 

func _on_delegate_my_signal(foo, bar):
    print('received signal: (foo: ', foo, ', bar: ', bar, ')')
