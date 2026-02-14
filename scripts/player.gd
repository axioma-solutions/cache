extends CharacterBody3D

@export_group("Movement")
@export var max_speed: float = 3.0
@export var sprint_speed: float = 5.0
@export var acceleration: float = 100.0
@export var friction: float = 50.0

@export_group("Air Movement")
@export var max_air_speed: float = 5.0
@export var air_acceleration: float = 70.0
@export var air_resistance: float = 10.0

@export_group("Jump")
@export var jump_velocity: float = 3.5

const GRAVITY = 9.81
const MOUSE_SENSITIVITY = 0.002
const PICKUP_DISTANCE = 2.0
const HOLD_DISTANCE = 1.5

const CROUCH_SPEED = 7.0
const STANDUP_SPEED = 15.0
@export_group("Crouch")
@export_range(0.1, 1.0, 0.05) var crouch_multiplier: float = 0.5
@export_range(0.1, 1.0, 0.05) var crouch_speed_multiplier: float = 0.5
var is_crouching = false
var normal_height: float
var normal_camera_y: float

var bob_time = 0.0
var bob_frequency = 4.0
var bob_amplitude = 0.01
var bob_horizontal_amplitude = 0.010

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
	handle_crouch(delta)
	apply_gravity(delta)
	handle_jump()
	handle_movement(delta)
	move_and_slide()
	apply_view_bobbing(delta)
	update_held_object(delta)

func handle_crouch(delta):
	is_crouching = Input.is_action_pressed("crouch")
	var target_height = normal_height * crouch_multiplier if is_crouching else normal_height
	
	if is_on_floor():
		# Smooth crouch on ground
		var speed = CROUCH_SPEED if is_crouching else STANDUP_SPEED
		collision_shape.shape.height = lerp(collision_shape.shape.height, target_height, speed * delta)
	else:
		# Instant crouch in air
		collision_shape.shape.height = target_height

func apply_gravity(delta):
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

func handle_jump():
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

func handle_movement(delta):
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if is_on_floor():
		handle_ground_movement(direction, delta)
	else:
		handle_air_movement(direction, delta)

func handle_ground_movement(direction: Vector3, delta: float):
	var max_spd = sprint_speed if Input.is_action_pressed("sprint") else max_speed
	if is_crouching:
		max_spd = max_speed * crouch_speed_multiplier
	
	if direction:
		velocity.x += direction.x * acceleration * delta
		velocity.z += direction.z * acceleration * delta
		var horizontal_speed = Vector2(velocity.x, velocity.z).length()
		if horizontal_speed > max_spd:
			var scale = max_spd / horizontal_speed
			velocity.x *= scale
			velocity.z *= scale
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)
		velocity.z = move_toward(velocity.z, 0, friction * delta)

func handle_air_movement(direction: Vector3, delta: float):
	# Get current horizontal speed
	var current_speed = Vector2(velocity.x, velocity.z).length()
	# Use current speed as max, but at least max_speed
	var effective_max_air_speed = max(current_speed, max_speed)
	
	velocity.x = move_toward(velocity.x, 0, air_resistance * delta)
	velocity.z = move_toward(velocity.z, 0, air_resistance * delta)
	if direction:
		velocity.x += direction.x * air_acceleration * delta
		velocity.z += direction.z * air_acceleration * delta
		var horizontal_speed = Vector2(velocity.x, velocity.z).length()
		if horizontal_speed > effective_max_air_speed:
			var scale = effective_max_air_speed / horizontal_speed
			velocity.x *= scale
			velocity.z *= scale

func apply_view_bobbing(delta):
	var horizontal_speed = Vector2(velocity.x, velocity.z).length()
	var bob_offset_y = 0.0
	var bob_offset_x = 0.0
	
	if is_on_floor() and horizontal_speed > 0.1:
		bob_time += delta * bob_frequency * horizontal_speed
		bob_offset_y = sin(bob_time) * bob_amplitude
		bob_offset_x = cos(bob_time * 0.5) * bob_horizontal_amplitude
	else:
		bob_time = 0.0
	
	var target_camera_y = normal_camera_y * crouch_multiplier if is_crouching else normal_camera_y
	
	if is_on_floor():
		# Smooth camera movement on ground
		var speed = CROUCH_SPEED if is_crouching else STANDUP_SPEED
		var base_camera_y = lerp(camera.position.y, target_camera_y, speed * delta)
		camera.position.y = base_camera_y + bob_offset_y
	else:
		# In air: smoothly move to target (crouch or normal)
		var base_camera_y = lerp(camera.position.y, target_camera_y, STANDUP_SPEED * delta)
		camera.position.y = base_camera_y + bob_offset_y
	
	camera.position.x = bob_offset_x
	camera.rotation.z = bob_offset_x * 0.2

func update_held_object(delta):
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
		# Don't pick up if standing on it
		if is_on_floor() and get_floor_normal().dot(Vector3.UP) > 0.7:
			var floor_collision = get_last_slide_collision()
			if floor_collision and floor_collision.get_collider() == result.collider:
				return
		
		held_object = result.collider
		held_object.freeze = true

func drop_object():
	if held_object:
		held_object.freeze = false
		held_object = null
