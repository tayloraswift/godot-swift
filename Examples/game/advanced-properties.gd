extends Node

func _ready():
    print('radians: ', $delegate.radians)
    print('degrees: ', $delegate.degrees)
    $delegate.radians = 0.678 * PI
    print('radians: ', $delegate.radians)
    print('degrees: ', $delegate.degrees)
    
    print('element 0: ', $delegate.elements_0)
    print('element 1: ', $delegate.elements_1)
    print('element 2: ', $delegate.elements_2)
