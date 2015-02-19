extends Control

const LMB = 1

var name setget set_name, get_name
func get_name():
    return name
func set_name(value):
    name = value

var callback setget set_callback
func set_callback(value):
    callback = value

func _input_event(event):
    if event.type == InputEvent.MOUSE_BUTTON and event.is_pressed() and event.button_index == LMB:
        callback.call_func(self)