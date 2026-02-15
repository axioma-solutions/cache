extends Node3D

@export var fire_rate: float = 0.2
@export var max_range: float = 100.0
@export var damage: float = 10.0
@export var impact_force: float = 5.0
@export var muzzle_flash_textures: Array[Texture2D] = []
@export var bullet_hole_scene: PackedScene

var can_shoot: bool = true
var fire_timer: float = 0.0

@onready var muzzle = $Muzzle

func _process(delta):
	if fire_timer > 0:
		fire_timer -= delta
		if fire_timer <= 0:
			can_shoot = true

func shoot(from: Vector3, direction: Vector3, player):
	if not can_shoot:
		return
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, from + direction * max_range)
	query.exclude = [player]
	var result = space_state.intersect_ray(query)
	
	if result:
		if result.collider.has_method("hit"):
			result.collider.hit(damage)
		if result.collider is RigidBody3D:
			result.collider.apply_impulse(direction * impact_force, result.position - result.collider.global_position)
		create_impact_effect(result.position, result.normal, result.collider)
		create_bullet_hole(result.position, result.normal, result.collider)
	
	create_muzzle_flash()
	can_shoot = false
	fire_timer = fire_rate

func create_muzzle_flash():
	if not muzzle:
		return
	
	var quad = MeshInstance3D.new()
	muzzle.add_child(quad)
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.3, 0.3)
	quad.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	if muzzle_flash_textures.size() > 0:
		mat.albedo_texture = muzzle_flash_textures[randi() % muzzle_flash_textures.size()]
	else:
		mat.albedo_color = Color.ORANGE
		mat.emission_enabled = true
		mat.emission = Color(2, 1, 0)
		mat.emission_energy_multiplier = 3.0
	
	quad.material_override = mat
	
	await get_tree().create_timer(0.05).timeout
	quad.queue_free()

func create_impact_effect(pos: Vector3, normal: Vector3, collider):
	var base_texture: Texture2D = null
	var surface_color = Color(1, 0, 0)
	
	if collider is CSGBox3D:
		var mat = collider.material
		if mat is StandardMaterial3D:
			base_texture = mat.albedo_texture
			surface_color = mat.albedo_color
	elif collider is StaticBody3D or collider is RigidBody3D:
		var parent = collider.get_parent()
		if parent and parent is MeshInstance3D:
			var mat = parent.get_active_material(0)
			if mat is StandardMaterial3D:
				base_texture = mat.albedo_texture
				surface_color = mat.albedo_color
		else:
			var nodes_to_check = collider.get_children()
			while nodes_to_check.size() > 0:
				var node = nodes_to_check.pop_front()
				
				if node is MeshInstance3D:
					var mat = node.get_active_material(0)
					if mat is StandardMaterial3D:
						base_texture = mat.albedo_texture
						surface_color = mat.albedo_color
						break
				elif node is CSGBox3D or node is CSGMesh3D:
					var mat = node.material
					if mat is StandardMaterial3D:
						base_texture = mat.albedo_texture
						surface_color = mat.albedo_color
						break
				
				nodes_to_check.append_array(node.get_children())
	elif collider is MeshInstance3D:
		var mat = collider.get_active_material(0)
		if mat is StandardMaterial3D:
			base_texture = mat.albedo_texture
			surface_color = mat.albedo_color
	
	for i in range(8):
		var particle = MeshInstance3D.new()
		get_tree().root.add_child(particle)
		particle.global_position = pos
		particle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		
		var mesh = QuadMesh.new()
		mesh.size = Vector2(0.05, 0.05)
		particle.mesh = mesh
		
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.albedo_color = surface_color
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		particle.material_override = mat
		
		var velocity = (normal + Vector3(randf_range(-0.5, 0.5), randf_range(0, 0.3), randf_range(-0.5, 0.5))).normalized() * randf_range(2, 4)
		var max_lifetime = randf_range(0.3, 0.4)
		animate_particle_mesh(particle, velocity, max_lifetime)

func animate_particle_mesh(particle: MeshInstance3D, velocity: Vector3, max_lifetime: float):
	var lifetime = 0.0
	var vel = velocity
	
	while lifetime < max_lifetime:
		await get_tree().process_frame
		var delta = get_process_delta_time()
		lifetime += delta
		
		particle.global_position += vel * delta
		vel.y -= 9.8 * delta
		
		# Fade out
		var mat = particle.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color.a = 1.0 - (lifetime / max_lifetime)
	
	particle.queue_free()


func create_bullet_hole(pos: Vector3, normal: Vector3, collider):
	if not bullet_hole_scene:
		return
	
	var decal = bullet_hole_scene.instantiate()
	
	if collider is RigidBody3D:
		collider.add_child(decal)
	else:
		get_tree().root.add_child(decal)
	
	decal.global_position = pos
	
	var right = Vector3.RIGHT if abs(normal.dot(Vector3.RIGHT)) < 0.99 else Vector3.FORWARD
	var tangent = normal.cross(right).normalized()
	right = tangent.cross(normal).normalized()
	decal.global_transform.basis = Basis(right, -normal, tangent)
	decal.rotate_object_local(Vector3(0, 1, 0), randf() * TAU)
	
	fade_bullet_hole(decal)

func fade_bullet_hole(decal: Node3D):
	await get_tree().create_timer(5.0).timeout
	
	var fade_time = 2.0
	var elapsed = 0.0
	
	while elapsed < fade_time:
		await get_tree().process_frame
		var delta = get_process_delta_time()
		elapsed += delta
		decal.modulate.a = 1.0 - (elapsed / fade_time)
	
	decal.queue_free()
