extends Node3D

@export var object_scene: PackedScene
@export var respawn_delay: float = 3.0
@export var detection_radius: float = 1.0

var current_object: RigidBody3D = null
var respawn_timer: float = 0.0
var waiting_to_respawn: bool = false

func _ready():
	spawn_object()

func _process(delta):
	if waiting_to_respawn:
		respawn_timer -= delta
		if respawn_timer <= 0:
			spawn_object()
			waiting_to_respawn = false
	elif current_object and not is_instance_valid(current_object):
		start_respawn_timer()
	elif current_object:
		var distance = global_position.distance_to(current_object.global_position)
		if distance > detection_radius:
			start_respawn_timer()

func spawn_object():
	if object_scene:
		current_object = object_scene.instantiate()
		get_parent().add_child(current_object)
		current_object.global_position = global_position

func start_respawn_timer():
	current_object = null
	waiting_to_respawn = true
	respawn_timer = respawn_delay
