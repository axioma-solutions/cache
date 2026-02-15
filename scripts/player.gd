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

@export_group("Object Interaction")
@export var throw_force: float = 10.0

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
@onready var weapon_holder = $Camera3D/WeaponHolder
@onready var crosshair = $UI/Crosshair

var held_object: RigidBody3D = null
var held_object_prev_position: Vector3 = Vector3.ZERO
var held_object_rotation_offset: Quaternion
var rotation_locked: bool = false
var equipped_weapon: Node3D = null

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	normal_height = collision_shape.shape.height
	normal_camera_y = camera.position.y
	if crosshair:
		crosshair.visible = false

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		var new_rotation_x = camera.rotation.x - event.relative.y * MOUSE_SENSITIVITY
		new_rotation_x = clamp(new_rotation_x, -PI / 2, PI / 2)
		camera.rotation.x = new_rotation_x
		if equipped_weapon and equipped_weapon.has_method("add_sway"):
			equipped_weapon.add_sway(event.relative)
	
	if event.is_action_pressed("interact"):
		if held_object:
			drop_object()
		else:
			try_pickup()
	
	if event.is_action_pressed("throw_weapon"):
		if equipped_weapon:
			throw_weapon()
	
	if held_object and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			throw_object()
	
	if equipped_weapon and not held_object and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			shoot_weapon()

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
		var hold_direction = camera.global_transform.basis.z * -1
		var desired_position = camera.global_position + hold_direction * HOLD_DISTANCE
		
		# Raycast further to account for object size (add 0.5m for barrel radius)
		var raycast_end = camera.global_position + hold_direction * (HOLD_DISTANCE + 0.5)
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(camera.global_position, raycast_end)
		query.exclude = [self, held_object]
		var result = space_state.intersect_ray(query)
		
		var final_position = desired_position
		if result:
			# Hit something, pull object back by its radius
			var hit_distance = camera.global_position.distance_to(result.position)
			var safe_distance = hit_distance - 0.5
			final_position = camera.global_position + hold_direction * safe_distance
		
		held_object_prev_position = held_object.global_position
		held_object.global_position = held_object.global_position.lerp(final_position, 10 * delta)
		
		# Lock rotation to camera when holding right click
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			if not rotation_locked:
				# Store rotation offset relative to camera when first pressed
				var camera_quat = camera.global_transform.basis.get_rotation_quaternion()
				var object_quat = held_object.global_transform.basis.get_rotation_quaternion()
				held_object_rotation_offset = camera_quat.inverse() * object_quat
				rotation_locked = true
			# Apply camera rotation + offset to keep same face visible
			var camera_quat = camera.global_transform.basis.get_rotation_quaternion()
			held_object.global_transform.basis = Basis(camera_quat * held_object_rotation_offset)
		else:
			rotation_locked = false

func try_pickup():
	var space_state = get_world_3d().direct_space_state
	var from = camera.global_position
	var to = from + camera.global_transform.basis.z * -PICKUP_DISTANCE
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result:
		print("Hit: ", result.collider.name, " - Is RigidBody3D: ", result.collider is RigidBody3D, " - In weapon group: ", result.collider.is_in_group("weapon"))
	
	if result and result.collider is RigidBody3D:
		# Check if it's a weapon
		if result.collider.is_in_group("weapon"):
			print("Picking up weapon!")
			pickup_weapon(result.collider)
			return
		
		# Don't pick up if standing on it
		if is_on_floor() and get_floor_normal().dot(Vector3.UP) > 0.7:
			var floor_collision = get_last_slide_collision()
			if floor_collision and floor_collision.get_collider() == result.collider:
				return
		
		# Holster weapon when picking up object
		if equipped_weapon:
			equipped_weapon.visible = false
			if crosshair:
				crosshair.visible = false
		
		held_object = result.collider
		held_object.freeze = true
		held_object.collision_layer = 0
		held_object.collision_mask = 0
	else:
		print("No hit detected")

func drop_object():
	if held_object:
		var throw_velocity = (held_object.global_position - held_object_prev_position) / get_physics_process_delta_time()
		
		held_object.freeze = false
		held_object.collision_layer = 1
		held_object.collision_mask = 1
		var damping = 5.0 / held_object.mass
		held_object.linear_velocity = throw_velocity * damping
		held_object = null
		
		# Show weapon again
		if equipped_weapon:
			equipped_weapon.visible = true
			if crosshair:
				crosshair.visible = true

func throw_object():
	if held_object:
		var throw_direction = camera.global_transform.basis.z * -1
		var player_velocity = Vector3(velocity.x, 0, velocity.z)
		
		held_object.freeze = false
		held_object.collision_layer = 1
		held_object.collision_mask = 1
		# Throw force inversely proportional to mass + player velocity
		held_object.linear_velocity = throw_direction * (throw_force / held_object.mass) + player_velocity
		held_object = null

func pickup_weapon(weapon: RigidBody3D):
	if equipped_weapon:
		return
	
	weapon.get_parent().remove_child(weapon)
	weapon_holder.add_child(weapon)
	weapon.position = Vector3.ZERO
	weapon.rotation = Vector3.ZERO
	weapon.freeze = true
	weapon.collision_layer = 0
	weapon.collision_mask = 0
	equipped_weapon = weapon.get_node("Pivot")
	if crosshair:
		crosshair.visible = true

func throw_weapon():
	if not equipped_weapon:
		return
	
	weapon_holder.remove_child(equipped_weapon)
	get_tree().root.add_child(equipped_weapon)
	equipped_weapon.global_position = camera.global_position + camera.global_transform.basis.z * -1
	equipped_weapon.freeze = false
	equipped_weapon.collision_layer = 1
	equipped_weapon.collision_mask = 1
	var throw_dir = camera.global_transform.basis.z * -1
	equipped_weapon.linear_velocity = throw_dir * 5.0 + Vector3(velocity.x, 0, velocity.z)
	equipped_weapon = null
	if crosshair:
		crosshair.visible = false

func shoot_weapon():
	if not equipped_weapon or not equipped_weapon.has_method("shoot"):
		return
	
	var shoot_from = camera.global_position
	var shoot_dir = camera.global_transform.basis.z * -1
	equipped_weapon.shoot(shoot_from, shoot_dir, self)
