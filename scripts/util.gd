extends RefCounted
## Small helpers for building blocky meshes and solid bodies from code.

static var _materials := {}


static func mat(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.85
		if color.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_materials[color] = m
	return _materials[color]


static func mesh_box(parent: Node, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(color)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func mesh_cylinder(parent: Node, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(color)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func add_box_shape(body: Node, size: Vector3, pos := Vector3.ZERO) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	body.add_child(cs)


static func solid_box(parent: Node, size: Vector3, xform: Transform3D, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.transform = xform
	parent.add_child(body)
	mesh_box(body, size, Vector3.ZERO, color)
	add_box_shape(body, size)
	return body


static func block(parent: Node, size: Vector3, pos: Vector3, color: Color) -> StaticBody3D:
	return solid_box(parent, size, Transform3D(Basis.IDENTITY, pos), color)


static func solid_cylinder(parent: Node, radius: float, height: float, pos: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	parent.add_child(body)
	mesh_cylinder(body, radius, height, Vector3.ZERO, color)
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	return body


## A sloped box whose top face runs exactly from `from` to `to`.
static func ramp(parent: Node, from: Vector3, to: Vector3, width: float, color: Color, thickness := 0.3) -> StaticBody3D:
	var dir := to - from
	var basis := Basis.looking_at(dir, Vector3.UP)
	var center := (from + to) * 0.5 - basis.y * thickness * 0.5
	return solid_box(parent, Vector3(width, thickness, dir.length()), Transform3D(basis, center), color)


## Low walls along both sides of a ramp so little players do not fall off.
static func ramp_walls(parent: Node, from: Vector3, to: Vector3, width: float, color: Color, wall_height := 0.6) -> void:
	var dir := to - from
	var basis := Basis.looking_at(dir, Vector3.UP)
	var center := (from + to) * 0.5 + basis.y * wall_height * 0.5
	for side: float in [-1.0, 1.0]:
		var pos := center + basis.x * side * (width * 0.5 + 0.08)
		solid_box(parent, Vector3(0.16, wall_height, dir.length()), Transform3D(basis, pos), color)
