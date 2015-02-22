extends Node

class ChangeTileAction:
    var _grid
    var _old_type
    var _new_type
    var _level
    var _is_floor

    func _init(grid, is_floor, old_type, new_type, level):
        _grid = grid
        _old_type = old_type
        _new_type = new_type
        _level = level
        _is_floor = is_floor

    func do_action():
        if _is_floor:
            _level.change_floor_tile(_new_type, _grid)
        else:
            _level.change_wall_tile(_new_type, _grid)
        
    func undo_action():
        if _is_floor:
            _level.change_floor_tile(_new_type, _grid)
        else:
            _level.change_wall_tile(_new_type, _grid)

class AddItemAction:
    var _grid
    var _type
    var _level

    func _init(grid, type, level):
        _grid = grid
        _type = type
        _level = level

    func do_action():
        _level.add_item(_grid, _type)

    func undo_action():
        _level.remove_item(_grid)

class RemoveItemAction:
    var _grid
    var _type
    var _level

    func _init(grid, type, level):
        _grid = grid
        _type = type
        _level = level

    func do_action():
        _level.remove_item(_grid)
        
    func undo_action():
        _level.add_item(_grid, _type)

class ChangeItemAction:
    var _grid
    var _old_type
    var _new_type
    var _level

    func _init(grid, old_type, new_type, level):
        _grid = grid
        _old_type = old_type
        _new_type = new_type
        _level = level

    func do_action():
        _level.remove_item(_grid)
        _level.add_item(_grid, _new_type)
        
    func undo_action():
        _level.remove_item(_grid)
        _level.add_item(_grid, _old_type)

const LMB = 1
const RMB = 2

const TILES_TAB = 0
const ITEMS_TAB = 1

var logger
var camera
var ray
var history
var save_button
var undo_button
var redo_button
var level
var current_tile_type
var left_mouse_down
var tabs
var current_item_type
var mesh_manager
var object_data
var current_item_picker
var current_tile_picker

func _ready():
    logger = get_node(@'/root/logger')

    camera = get_node(@'World/Viewport/Camera')
    level = get_node(@'World/Viewport/Level')
    ray = camera.get_node(@'RayCast')
    mesh_manager = get_node(@'/root/mesh_manager')
    object_data = get_node(@'/root/object_data')

    history = get_node(@'History')
    save_button = get_node(@'ButtonsPanel/Buttons/SaveButton')
    undo_button = get_node(@'ButtonsPanel/Buttons/UndoButton')
    redo_button = get_node(@'ButtonsPanel/Buttons/RedoButton')
    tabs = get_node(@'Tabs')

    logger.debug("Created 3d viewport")

func setup():
    var level_setup = level.setup(true)
    while level_setup.is_valid():
        level_setup.resume()
        yield()

    fill_item_picker()
    #yield()
    fill_tile_picker()
    #yield()
    update_history_buttons()

    var view_slider = get_node(@'ViewSlider')
    view_slider.set_max(level.get_length() - 1)
    view_slider.set_value(camera.get_translation().x + 0.5)

    set_process(true)

func _process(delta):
    if ray.is_enabled() and ray.is_colliding():
        var collider = ray.get_collider()
        if collider != null:
            var current_tab = tabs.get_current_tab()

            if current_tab == ITEMS_TAB:
                if collider.object_type() == "TILE":
                    if collider.is_floor:
                        click_in_item_mode(collider.grid)
                elif collider.object_type() == "ITEM":
                    click_in_item_mode(collider.grid)

            elif current_tab == TILES_TAB:
                if collider.object_type() == "TILE":
                    click_in_tile_mode(collider)
                elif collider.object_type() == "ITEM":
                    click_in_tile_mode(collider)

        ray.set_enabled(false)

func click_in_item_mode(grid):
    if left_mouse_down:
        var old_item = level.get_item_at(grid)

        if current_item_type == null:
            if old_item != null:
                var action = RemoveItemAction.new(grid, old_item.type, level)
                history.add(action)
        else:
            var action
            if old_item != null:
                action = ChangeItemAction.new(grid, old_item.type, current_item_type, level)
            else:
                action = AddItemAction.new(grid, current_item_type, level)
            history.add(action)

        update_history_buttons()
    else:
        current_item_type = level.get_item_at(grid)

func click_in_tile_mode(tile):
    if left_mouse_down:
        var action = ChangeTileAction.new(tile.grid, tile.is_floor, tile.type, current_tile_type, level)
        history.add(action)
        update_history_buttons()
    else:
        current_tile_type = tile.type

func _on_Tabs_tab_changed(tab):
    pass

func _on_EditorPanel_input_event(event):
    if event.type == InputEvent.MOUSE_BUTTON and event.is_pressed():
        if event.button_index == LMB:
            left_mouse_down = true # Paint.
            select_with_cursor(event.pos)
        elif event.button_index == RMB:
            left_mouse_down = false # Pick type.
            select_with_cursor(event.pos)

func select_with_cursor(mouse_pos, length=100):
    var dir = camera.project_ray_normal(mouse_pos) # Uses camera projection matrix to project mouse 2D coordinates to 3D vector in world space
   
    # Since the direction has to be in local space, we transform it by cameras inverse transformation matrix
    var transform = camera.get_camera_transform().basis.inverse()
    var local_dir = transform * dir
   
    ray.set_cast_to(local_dir * length)
    ray.set_enabled(true)

func _on_SaveButton_pressed():
    level.save()

func _on_UndoButton_pressed():
    history.undo()
    update_history_buttons()

func _on_RedoButton_pressed():
    history.redo()
    update_history_buttons()

func _on_BackButton_pressed():
    get_node(@'/root/Root/SceneManager').goto("res://main_menu/main_menu.xscn")

func update_history_buttons():
    undo_button.set_disabled(not history.get_can_undo())
    redo_button.set_disabled(not history.get_can_redo())
    
func _on_TilePicker_pressed(control):
    logger.info("Picked tile: %s" % control.name)
    current_tile_picker.is_selected = false
    current_tile_picker = control
    current_tile_picker.is_selected = true
    current_tile_type = control.name

func _on_ItemPicker_pressed(control):
    if control.name == null:
        logger.info("Picked to delete items")
    else:
        logger.info("Picked item: %s" % control.name)

    current_item_picker.is_selected = false
    current_item_picker = control
    current_item_picker.is_selected = true
    current_item_type = control.name

func fill_item_picker():
    var pickers = tabs.get_node(@'Items/ScrollArea/Pickers')
    pickers.add_child(create_delete_picker())

    for item in object_data.ITEM_ORDER_IN_EDITOR:
        pickers.add_child(create_item_picker(item))

func create_delete_picker():
    var picker = load("res://prefabs/item_picker.xscn").instance()
    picker.name = null
    picker.is_selected = true
    picker.set_tooltip("delete item")
    current_item_picker = picker
    picker.callback = funcref(self, "_on_ItemPicker_pressed")
    return picker

func create_item_picker(name):
    var item = mesh_manager.new_mesh_object(name)
    item.data = object_data.ITEM_TYPES[name]

    var picker = load("res://prefabs/item_picker.xscn").instance()
    picker.get_node(@'Viewport').add_child(item)
    picker.name = name
    picker.set_tooltip(name)
    picker.callback = funcref(self, "_on_ItemPicker_pressed")
    return picker

func fill_tile_picker():
    var pickers = tabs.get_node(@'Tiles/ScrollArea/Pickers')
    var animations = mesh_manager.get_animations("tile")
    var utilities = get_node(@'/root/utilities')

    var selected = false
    for tile in object_data.TILE_ORDER_IN_EDITOR:
        var frame = animations[tile][0]["tile"]
        var picker = create_tile_picker(frame, tile)
        if not selected:
            current_tile_picker = picker
            picker.is_selected = true
            current_tile_type = tile
            selected = true
        pickers.add_child(picker)

func create_tile_picker(frame, tile):
    var prefab = load("res://prefabs/tile_picker.xscn")
    var picker = prefab.instance()
    picker.get_node(@'Sprite').set_frame(frame)
    picker.name = tile
    picker.set_tooltip(tile)
    picker.callback = funcref(self, "_on_TilePicker_pressed")
    return picker

func _on_ViewSlider_value_changed(value):
    var translation = camera.get_translation()
    translation.x = value + 0.5
    camera.set_translation(translation)