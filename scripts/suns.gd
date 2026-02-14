extends Node3D

var time = 0.0
var sun_data = []

func _ready():
	for i in get_child_count():
		var child = get_child(i)
		if child is DirectionalLight3D:
			child.visible = true
			if child.light_energy == 0:
				child.light_energy = 1.0
			sun_data.append({
				"light": child,
				"speed": randf_range(0.02, 0.05),
				"radius_speed": randf_range(0.01, 0.03),
				"offset": randf_range(0, TAU),
				"base_radius": randf_range(0.3, 0.8),
				"noise_offset": randf_range(0, 100),
				"noise_scale": randf_range(0.1, 0.3)
			})

func _process(delta):
	time += delta
	
	for data in sun_data:
		var light = data.light
		var angle = time * data.speed + data.offset
		var radius = data.base_radius + sin(time * data.radius_speed) * 0.3
		
		var noise_x = sin(time * data.noise_scale + data.noise_offset) * 0.3
		var noise_z = cos(time * data.noise_scale * 1.3 + data.noise_offset) * 0.3
		var noise_y = sin(time * data.noise_scale * 0.7 + data.noise_offset) * 0.2
		
		var x = cos(angle) * radius + noise_x
		var z = sin(angle) * radius + noise_z
		var y = cos(angle * 0.5) * 0.5 + 0.5 + noise_y
		
		light.look_at_from_position(
			Vector3(x * 20, y * 15 + 10, z * 20),
			Vector3.ZERO,
			Vector3.UP
		)
