extends Node

func _ready():
    var logger = get_node("/root/logger")
    logger.level = logger.Level.DEBUG
    logger.filename = "user://log.txt"


func load_json(name):
    var json = File.new()
    assert(json.file_exists(name))
    json.open(name, File.READ)
    var data = {}
    var status = data.parse_json(json.get_as_text())
    json.close()
    assert(status == OK)

    return data


func save_json(name, data):
    var json = File.new()
    json.open(name, File.WRITE)
    json.store_string(data.to_json())
    json.close()
