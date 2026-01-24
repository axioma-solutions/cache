extends Node3D

@export var terrain_scene: PackedScene
@export var grid_size: int = 5
@export var tile_size: float = 10.0

func _ready():
	if terrain_scene == null:
		return
	
	for x in range(grid_size):
		for z in range(grid_size):
			var instance = terrain_scene.instantiate()
			add_child(instance)
			instance.position = Vector3(x * tile_size, 0, z * tile_size)
