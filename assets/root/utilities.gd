extends Node


func load_json(name):
    var json = File.new()
    json.open(name, File.READ)
    var data = {}
    var status = data.parse_json(json.get_as_text())
    json.close()
    assert(status == OK)

    return data


func save_json(name, data):
    var json = File.new()
    json.open(name, File.WRITE)
    json.store_line(data.to_json())
    json.close()
