extends KinematicBody

const WALK_SPEED = 2
const JUMP_SPEED = 5
const EXPLODED_SPEED = 20
const UP = Vector3(0, 1, 0)
const GRAVITY = -9.81
const FOOTPRINT_DISTANCE = 0.3
const NUM_FOOTPRINTS = 12
const TRAIL_HEIGHT_WALKING = 0.8
const TRAIL_HEIGHT_SURFING = 1.8

class State:
    const OK = 0
    # Game over
    const FINISHED = 10
    const CAUGHT = 11
    # Dead.
    const ON_BACK = 20
    const ELECTROCUTED = 21
    const FLATTENED = 22
    const BURNT = 23
    const EATEN = 24
    const STRANGLED = 25
    const EXPLODED = 26

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
var state = State.OK
var object_data
var camera
var surfing_on
var speed_trail_prefab = preload("res://prefabs/speed_trail.xscn")
var speed_trail
var speed_remaining = 0
var achievements

func object_type():
    return "PLAYER"

func _ready():
    logger = get_node(@'/root/logger')
    achievements = get_node(@'/root/achievements')
    mesh = get_node(@'MeshInstance')
    audio = get_node(@'Audio')
    floor_ray = get_node(@'FloorRay')
    camera = get_node(@'../../Camera')

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
        dir += Vector3(0.5, 0, 0)

    return dir.normalized() + Vector3(1, 0, 0)

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

    if state == State.OK:
        if floor_ray.is_colliding():
            var collider = floor_ray.get_collider()
            if collider != null and collider.object_type() == "TILE":
                floor_tile = collider

        var walk_speed = WALK_SPEED
        
        if on_floor:
            var jump_pressed = Input.is_action_pressed("jump")
            if jump_pressed:
                if surfing_on != null or not floor_tile.is_sticky:
                    audio.play("player_jump")
                    if surfing_on != null:
                        remove_board()
                    velocity.y = JUMP_SPEED
                    on_floor = false
                    achievements.increment_stat("JUMPS")
                else:
                    audio.play("player_jump")
                    pass # TODO: play sound?
            elif surfing_on == null:
                walk_speed *= floor_tile.speed_multiplier

        if speed_remaining > 0:
            speed_remaining -= delta
            
            if speed_remaining <= 0:
                remove_trail()
            else:
                walk_speed *= 1.5

        var direction = move_direction()
        velocity.x = direction.x * walk_speed
        velocity.z = direction.z * walk_speed

    var motion = velocity * delta
    motion = move(motion)

    if surfing_on == null and state == State.OK and on_floor:
        footprints(motion)

    if is_colliding():
        handle_collision(motion)

    if state == State.OK and surfing_on == null:
        update_animation(velocity)

    if on_floor and floor_tile:
        move(floor_tile.push_speed * delta)

    update_camera_pos()

func update_camera_pos():
    var camera_pos = camera.get_translation()
    camera_pos.x = get_translation().x + 1.5
    camera.set_translation(camera_pos)

func handle_collision(motion):
    var collider = get_collider()
    var new_player_state = collider.player_state
    if state == State.OK:
        if new_player_state == "ok":
            if collider.type == "rat":
                handle_rat_collision(collider)
            elif collider.type == "hover_board":
                handle_hover_board_collision(collider)
            elif collider.type == "speed_pill":
                collider.queue_free()
                speed_trail = speed_trail_prefab.instance()
                if surfing_on == null:
                    speed_trail.height = TRAIL_HEIGHT_WALKING
                else:
                    speed_trail.height = TRAIL_HEIGHT_SURFING
                add_child(speed_trail)
                speed_remaining = 5
        else:
            var safe = collider.get_node(@'MeshInstance').frame in collider.safe_frames
            if not safe:
                kill(collider, new_player_state)

    var normal = get_collision_normal()
    if normal.dot(UP) > 0.7:
        on_floor = true
    else:
        on_floor = false

    motion = normal.slide(motion)
    velocity = normal.slide(velocity)
    move(motion)

    if is_colliding():
        handle_collision(motion)

func handle_rat_collision(rat):
    if get_translation().y > 0.3:
        rat.get_node(@'MeshInstance').animation = "dead"
        rat.set_layer_mask(0)
        rat.set_is_horizontal(true)
        audio.play("rat_squashed")
    else:
        rat.get_node(@'MeshInstance').animation = "running"
        rat.set_velocity(Vector3(-10, 0, 0))
        rat.set_layer_mask(object_data.CollisionLayer.TILES_MOVING_ITEMS)
        audio.play("rat_chased")

func handle_hover_board_collision(board):
    remove_board()
    if speed_trail != null:
        speed_trail.height = TRAIL_HEIGHT_SURFING

    logger.debug("Jumped onto board")
    surfing_on = board

    get_node("../Items").remove_child(surfing_on)
    add_child(surfing_on)

    surfing_on.set_translation(Vector3(0, 0.3, -0.4))
    surfing_on.set_layer_mask(0)

    mesh.animation = "surfing"

func remove_trail():
    if speed_trail == null:
        return

    speed_remaining = 0
    speed_trail.is_emitting = false
    speed_trail = null

func remove_board():
    if surfing_on == null:
        return

    if speed_trail != null:
        speed_trail.height = TRAIL_HEIGHT_WALKING

    logger.debug("Jumped off board")
    remove_child(surfing_on)
    get_node("../Items").add_child(surfing_on)

    surfing_on.set_translation(get_translation() + Vector3(-0.6, 0.2, 0))
    surfing_on.velocity = Vector3(-0.8, 0, 0)

    footprints_color = null
    footprints_remaining = null

    surfing_on = null
    state = State.OK

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

func kill(killer, new_state):
    velocity = Vector3()

    set_layer_mask(object_data.CollisionLayer.TILES_PLAYER)

    remove_board()
    remove_trail()

    var animation = new_state

    if new_state == "burnt":
        state = State.BURNT
        audio.play("player_died")
    elif new_state == "electrocuted":
        state = State.ELECTROCUTED
        audio.play("player_died")
    elif new_state == "flattened":
        state = State.FLATTENED
        var translation = get_translation()
        translation.y = 0
        set_translation(translation)
        set_is_horizontal(true)
        audio.play("player_died")
    elif new_state == "on_back":
        state = State.ON_BACK
        audio.play("player_died")
    elif new_state == "eaten":
        state = State.EATEN
        killer.set_is_horizontal(killer.is_horizontal_after_kill)
        killer.get_node("MeshInstance").stop_on_completion = true
        killer.get_node("MeshInstance").animation = "killed_player"
        audio.play("fly_trap_chew")
    elif new_state == "strangled":
        state = State.STRANGLED
        killer.set_is_horizontal(killer.is_horizontal_after_kill)
        killer.get_node("MeshInstance").stop_on_completion = true
        killer.get_node("MeshInstance").animation = "killed_player"
        audio.play("fly_trap_chew")
        animation = "eaten"
    elif new_state == "exploded":
        state = State.EXPLODED
        velocity.y = EXPLODED_SPEED
        audio.play("mine_explosion")
    else:
        logger.error("Bad player state: %s", new_state)
        assert(false)

    achievements.increment_stat("DEATHS")
    achievements.increment_stat(new_state.to_upper())
    achievements.save()

    mesh.animation = animation

func create_footprint():
    var footprint = preload("res://prefabs/footprint.xscn").instance()
    get_node(@'..').add_child(footprint)
    footprint.set_translation(get_translation())
    footprint.set_color(footprints_color)

func on_in_area(area):
    if state == State.OK:
        var new_player_state = area.player_state
        if new_player_state == "ok":
            pass
        else:
            var safe = area.get_node(@'MeshInstance').frame in area.safe_frames
            if not safe:
                kill(area, new_player_state)
                
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


func finish():
    if state != State.OK:
        return

    remove_board()
    remove_trail()

    mesh.animation = "dancing"
    state = State.FINISHED
    velocity.x = 0
    velocity.z = 0

func caught():
    if state != State.OK:
        return

    audio.play("fly_trap_chew")

    remove_board()
    remove_trail()

    mesh.animation = "crouching"
    state = State.CAUGHT
    velocity.x = 0
    velocity.z = 0