extends Node3D

@export var projectile_scene: PackedScene
@export var shoot_force: float = 100.0
@export var fire_rate: float = 0.2

var can_shoot: bool = true
var fire_timer: float = 0.0

@onready var muzzle = $Muzzle

func _process(delta):
	if fire_timer > 0:
		fire_timer -= delta
		if fire_timer <= 0:
			can_shoot = true

func shoot(direction: Vector3):
	if not can_shoot or not projectile_scene:
		return
	
	var spawn_pos = muzzle.global_position if muzzle else global_position
	
	var projectile = projectile_scene.instantiate()
	get_tree().root.add_child(projectile)
	projectile.global_position = spawn_pos
	projectile.linear_velocity = direction * shoot_force
	
	# Make projectile ignore this weapon
	projectile.add_collision_exception_with(self)
	
	can_shoot = false
	fire_timer = fire_rate
