extends RigidBody3D

@export var lifetime: float = 5.0

var time_alive: float = 0.0
var trail: MeshInstance3D
var trail_points: Array = []

func _ready():
	contact_monitor = true
	max_contacts_reported = 4
	
	# Create trail mesh
	trail = MeshInstance3D.new()
	add_child(trail)
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.YELLOW
	material.emission_enabled = true
	material.emission = Color.YELLOW
	trail.material_override = material

func _process(delta):
	time_alive += delta
	if time_alive >= lifetime:
		queue_free()
	
	# Update trail
	trail_points.append(global_position)
	if trail_points.size() > 10:
		trail_points.pop_front()
	
	update_trail_mesh()

func update_trail_mesh():
	if trail_points.size() < 2:
		return
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices = PackedVector3Array()
	
	for point in trail_points:
		vertices.append(to_local(point))
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arrays)
	trail.mesh = mesh

func _on_body_entered(body):
	if body.has_method("hit"):
		body.hit()
	queue_free()
