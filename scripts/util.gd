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


## A rainbow arch with a glowing pad. Returns the Area3D that notices who walks in.
static func portal(parent: Node, pos: Vector3, facing: Basis, colors: Array[Color]) -> Area3D:
	var root := Node3D.new()
	root.transform = Transform3D(facing, pos)
	parent.add_child(root)
	for k in 5:
		var w := 2.8 - k * 0.3
		var h := 3.2 - k * 0.15
		var c := colors[k % colors.size()]
		for side: float in [-1.0, 1.0]:
			mesh_box(root, Vector3(0.15, h, 0.3), Vector3(side * w * 0.5, h * 0.5, 0), c)
		mesh_box(root, Vector3(w + 0.15, 0.15, 0.3), Vector3(0, h, 0), c)
	mesh_cylinder(root, 1.0, 0.06, Vector3(0, 0.03, 0), Color(0.75, 0.55, 1.0, 0.8))
	var area := Area3D.new()
	add_box_shape(area, Vector3(1.6, 2.0, 1.0), Vector3(0, 1.0, 0))
	root.add_child(area)
	return area


## A one-time burst of colorful paper squares.
static func confetti(parent: Node, pos: Vector3, amount: int, colors: Array[Color]) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.18, 0.18, 0.04)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = m
	var c := CPUParticles3D.new()
	c.mesh = mesh
	c.amount = amount
	c.lifetime = 2.0
	c.one_shot = true
	c.explosiveness = 0.95
	c.direction = Vector3.UP
	c.spread = 50
	c.initial_velocity_min = 5
	c.initial_velocity_max = 9
	c.gravity = Vector3(0, -7, 0)
	c.angular_velocity_min = -400
	c.angular_velocity_max = 400
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
	ramp.colors = PackedColorArray(colors.slice(0, 6))
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	c.color_initial_ramp = ramp
	c.top_level = true
	parent.add_child(c)
	c.global_position = pos + Vector3.UP * 0.5
	c.emitting = true
	c.get_tree().create_timer(3.0).timeout.connect(c.queue_free)


## A slide made of short straight pieces through `points` (top first), with a wall on each
## side. Pieces overlap a little, so there are no gaps where the slide curves.
static func slide_path(parent: Node, points: Array[Vector3], width: float, color: Color, wall_height := 1.0) -> void:
	for i in points.size() - 1:
		var dir := (points[i + 1] - points[i]).normalized()
		var from := points[i] - dir * 0.25
		var to := points[i + 1] + dir * 0.25
		var piece := ramp(parent, from, to, width, color)
		piece.set_meta("slide", true)
		ramp_walls(parent, from, to, width, color.lightened(0.35), wall_height)
