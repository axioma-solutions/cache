extends CharacterBody3D

const ACCELERATION = 100.0
const AIR_ACCELERATION = 70.0
const AIR_RESISTANCE = 10.0
const FRICTION = 50.0
const MAX_SPEED = 3.0
const SPRINT_SPEED = 5.0
const MAX_AIR_SPEED = 3.0
const JUMP_VELOCITY = 3.5
const GRAVITY = 9.81
const MOUSE_SENSITIVITY = 0.002
const PICKUP_DISTANCE = 2.0
const HOLD_DISTANCE = 1.5

const CROUCH_SPEED = 7.0
const STANDUP_SPEED = 15.0
@export_range(0.1, 1.0, 0.05) var crouch_multiplier: float = 0.5
var is_crouching = false
var normal_height: float
var normal_camera_y: float

@onready var camera = $Camera3D
@onready var collision_shape = $CollisionShape3D

var held_object: RigidBody3D = null

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Store initial values
	normal_height = collision_shape.shape.height
	normal_camera_y = camera.position.y

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, -PI / 2, PI / 2)
	
	if event.is_action_pressed("interact"):
		if held_object:
			drop_object()
		else:
			try_pickup()

func _physics_process(delta):
	# Check crouch input
	is_crouching = Input.is_action_pressed("crouch")

	# Adjust height and camera
	var target_height = normal_height * crouch_multiplier if is_crouching else normal_height
	var target_camera_y = normal_camera_y * crouch_multiplier if is_crouching else normal_camera_y
	
	var speed = CROUCH_SPEED if is_crouching else STANDUP_SPEED
	collision_shape.shape.height = lerp(collision_shape.shape.height, target_height, speed * delta)
	camera.position.y = lerp(camera.position.y, target_camera_y, speed * delta)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if is_on_floor():
		var max_speed = SPRINT_SPEED if Input.is_action_pressed("sprint") else MAX_SPEED
		if direction:
			velocity.x += direction.x * ACCELERATION * delta
			velocity.z += direction.z * ACCELERATION * delta
			var horizontal_speed = Vector2(velocity.x, velocity.z).length()
			if horizontal_speed > max_speed:
				var scale = max_speed / horizontal_speed
				velocity.x *= scale
				velocity.z *= scale
		else:
			velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
			velocity.z = move_toward(velocity.z, 0, FRICTION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, AIR_RESISTANCE * delta)
		velocity.z = move_toward(velocity.z, 0, AIR_RESISTANCE * delta)
		if direction:
			velocity.x += direction.x * AIR_ACCELERATION * delta
			velocity.z += direction.z * AIR_ACCELERATION * delta
			var horizontal_speed = Vector2(velocity.x, velocity.z).length()
			if horizontal_speed > MAX_AIR_SPEED:
				var scale = MAX_AIR_SPEED / horizontal_speed
				velocity.x *= scale
				velocity.z *= scale

	move_and_slide()
	
	if held_object:
		var hold_position = camera.global_position + camera.global_transform.basis.z * -HOLD_DISTANCE
		held_object.global_position = held_object.global_position.lerp(hold_position, 10 * delta)

func try_pickup():
	var space_state = get_world_3d().direct_space_state
	var from = camera.global_position
	var to = from + camera.global_transform.basis.z * -PICKUP_DISTANCE
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result and result.collider is RigidBody3D:
		held_object = result.collider
		held_object.freeze = true

func drop_object():
	if held_object:
		held_object.freeze = false
		held_object = null
