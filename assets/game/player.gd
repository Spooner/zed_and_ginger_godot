extends KinematicBody

const WALK_SPEED = 4
const JUMP_SPEED = 6
const EXPLODED_SPEED = 20
const UP = Vector3(0, 1, 0)
const GRAVITY = -9.81
const FOOTPRINT_DISTANCE = 0.3
const NUM_FOOTPRINTS = 12

class State:
    const ALIVE = 0
    const ON_BACK = 1
    const ELECTROCUTED = 2
    const FLATTENED = 3
    const BURNT = 4
    const EATEN = 5
    const EXPLODED = 6

var logger
var mesh
var audio
var floor_tile
var floor_ray
var footprints_color = null
var footprints_remaining
var distance_to_footprint
var on_floor = false
var velocity = Vector3(0, 0, 0)
var state = State.ALIVE
var object_data

func object_type():
    return "PLAYER"

func _ready():
    logger = get_node(@'/root/logger')
    mesh = get_node(@'MeshInstance')
    audio = get_node(@'SpatialSamplePlayer')
    floor_ray = get_node(@'FloorRay')

    mesh.animation = "walking"

    set_fixed_process(true)

    logger.info("Created player")

    object_data = get_node(@'/root/object_data')
    var layer = object_data.CollisionLayer
    set_layer_mask(layer.ITEMS_PLAYER + layer.TILES_PLAYER + layer.PLAYER_MOVING_ITEMS)

func move_direction():
    var dir = Vector3()

    if Input.is_action_pressed("move_up"):
        dir += Vector3(0, 0, -1)
    if Input.is_action_pressed("move_down"):
        dir += Vector3(0, 0, 1)

    if Input.is_action_pressed("move_left"):
        dir += Vector3(-1, 0, 0)
    if Input.is_action_pressed("move_right"):
        dir += Vector3(1, 0, 0)

    return dir.normalized()

func update_animation(velocity):
    var animation

    if on_floor:
        if velocity.x != 0 or velocity.z != 0:
            animation = "walking"
        else:
            animation = "sitting"
    else:
        if velocity.y > 0.7:
            animation = "jumping_up"
        elif velocity.y < -0.7:
            animation = "jumping_down"
        else:
            animation = "jumping_across"

    mesh.animation = animation

func _fixed_process(delta):
    velocity.y += GRAVITY * delta

    if state == State.ALIVE:
        if floor_ray.is_colliding():
            var collider = floor_ray.get_collider()
            if collider != null and collider.object_type() == "TILE":
                floor_tile = collider

        var walk_speed = WALK_SPEED
        
        if on_floor:
            var jump_pressed = Input.is_action_pressed("jump")
            if jump_pressed:
                if floor_tile.is_sticky:
                    pass # TODO: play sound?
                else:
                    velocity.y = JUMP_SPEED
                    on_floor = false

            walk_speed *= floor_tile.speed_multiplier

        var direction = move_direction()
        velocity.x = direction.x * walk_speed
        velocity.z = direction.z * walk_speed

    var motion = velocity * delta
    motion = move(motion)

    if state == State.ALIVE and on_floor:
        footprints(motion)

    if is_colliding():
        handle_collision(motion)

    if state == State.ALIVE:
        update_animation(velocity)

    if on_floor and floor_tile:
        move(floor_tile.push_speed * delta)

func handle_collision(motion):
    var collider = get_collider()
    var new_player_state = collider.player_state
    if state == State.ALIVE:
        if new_player_state == "alive":
            if collider.type == "rat":
                handle_rat_collision(collider)
                
        else:
            var safe = collider.get_node(@'MeshInstance').frame in collider.safe_frames
            if not safe:
                kill(new_player_state)

    var normal = get_collision_normal()

    if normal.dot(UP) > 0.7:
        on_floor = true

        motion = normal.slide(motion)
        velocity = normal.slide(velocity)
        move(motion)
    else:
        on_floor = false

func handle_rat_collision(rat):
    if get_translation().y > 0.3:
        rat.get_node(@'MeshInstance').animation = "dead"
        rat.set_layer_mask(0)
        rat.set_is_horizontal(true)
    else:
        rat.get_node(@'MeshInstance').animation = "running"
        rat.set_velocity(Vector3(-10, 0, 0))
        rat.set_layer_mask(object_data.CollisionLayer.TILES_MOVING_ITEMS)

func footprints(motion):
    if floor_tile.footprints_color.a > 0:
        if floor_tile.footprints_color != footprints_color:
            distance_to_footprint = FOOTPRINT_DISTANCE
        footprints_remaining = NUM_FOOTPRINTS
        footprints_color = floor_tile.footprints_color

    if footprints_color != null and floor_tile.accepts_footprints:
        distance_to_footprint -= motion.length()
        if distance_to_footprint <= 0:
            create_footprint()

            footprints_remaining -= 1
            if footprints_remaining == 0:
                footprints_color = null
            else:
                distance_to_footprint = FOOTPRINT_DISTANCE

func kill(new_state):
    velocity = Vector3()

    set_layer_mask(object_data.CollisionLayer.TILES_PLAYER)

    if new_state == "burnt":
        state = State.BURNT
    elif new_state == "electrocuted":
        state = State.ELECTROCUTED
    elif new_state == "flattened":
        state = State.FLATTENED
        var translation = get_translation()
        translation.y = 0
        set_translation(translation)
        set_is_horizontal(true)
    elif new_state == "on_back":
        state = State.ON_BACK
    elif new_state == "eaten":
        state = State.EATEN
    elif new_state == "exploded":
        state = State.EXPLODED
        velocity.y = EXPLODED_SPEED
    else:
        logger.error("Bad player state: %s", new_state)
        assert(false)

    mesh.animation = new_state

func create_footprint():
    var footprint = preload("res://prefabs/footprint.xscn").instance()
    get_node(@'..').add_child(footprint)
    footprint.set_translation(get_translation())
    footprint.set_color(footprints_color)

func on_in_area(area):
    if state == State.ALIVE:
        var new_player_state = area.player_state
        if new_player_state == "alive":
            pass
        else:
            var safe = area.get_node(@'MeshInstance').frame in area.safe_frames
            if not safe:
                kill(new_player_state)

var is_horizontal = false setget set_is_horizontal
func set_is_horizontal(value):
    if is_horizontal == value:
        return

    is_horizontal = value

    if is_horizontal:
        set_rotation(Vector3(PI / 2, 0, 0))
        set_translation(get_translation() + Vector3(0, 0, -0.5))
    else:
        set_translation(get_translation() - Vector3(0, 0, -0.5))
        set_rotation(Vector3(0, 0, 0))