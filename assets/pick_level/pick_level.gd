extends Node

var scene_manager
var button_prefab = preload("res://prefabs/my_button.xscn")
var utilities
var callback

func set_callback(value):
    callback = value

func _ready():
    scene_manager = get_node(@'/root/Root/SceneManager')
    utilities = get_node(@"/root/utilities")
    var file = File.new()

    for i in range(1, 100):
        var filename = "res://levels/%d.json" % i
        if not file.file_exists(filename):
           break

        var level_data = utilities.load_json(filename)

        var button = button_prefab.instance()
        button.set_text("%d: %s" % [i, level_data["name"]])
        button.connect("pressed", self, "_on_level_selected", [filename, level_data])
        get_node("Levels").add_child(button)

func _on_level_selected(filename, level_data):
    callback.call_func(filename, level_data)

func _on_CancelButton_pressed():
    scene_manager.close_dialog()
