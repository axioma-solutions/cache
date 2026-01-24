extends CharacterBody3D

const ACCELERATION = 100.0
const AIR_ACCELERATION = 70.0
const AIR_RESISTANCE = 10.0
const FRICTION = 50.0
const MAX_SPEED = 3.0
const SPRINT_SPEED = 4.5
const MAX_AIR_SPEED = 3.0
const JUMP_VELOCITY = 4.0
const GRAVITY = 9.81
const MOUSE_SENSITIVITY = 0.002

@onready var camera = $Camera3D

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

func _physics_process(delta):
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
