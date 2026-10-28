extends "res://scripts/place.gd"
## An indoor soft play, like the ones in a mall: a big frame with yellow nets.
## Climb the climbing wall (or walk up the padded stairs) to the first floor, find your way
## through the net tunnels, climb the second wall to the top, and ride the yellow slide down
## into the ball pit. On the floor there is also a rainbow tunnel to walk through.
## Push the joystick toward a climbing wall to climb it.

const Player := preload("res://scripts/player.gd")

## The hall: x from -HALL_X to HALL_X, z from HALL_Z0 to HALL_Z1.
const HALL_X := 22.0
const HALL_Z0 := -26.0
const HALL_Z1 := 18.0
const FLOOR1 := 3.0
const FLOOR2 := 6.0
## How tall the tunnels on the first floor are, up to their net roof.
const TUNNEL_H := 2.6
const CELL := 3.0
## The first floor seen from above, back row first. Each letter is a 3x3 m cell:
## "." tunnel, "#" closed, "T" under the top floor, "W" tunnel in front of the second
## climbing wall (no roof there, so you can climb out).
const MAP: Array[String] = [
	"TTT...#..",
	"TTT.#...#",
	".W..###..",
	".##...##.",
]
## Columns whose front edge has no net: the drop into the ball pit (0), the first
## climbing wall (3 to 5) and the top of the stairs (8).
const OPEN_FRONT := [0, 3, 4, 5, 8]
const MAP_X0 := -13.5
const MAP_Z0 := -22.0
## The ball pit: x from PIT_X0 to PIT_X1, z from PIT_Z0 to PIT_Z1.
const PIT_X0 := -19.0
const PIT_X1 := -7.0
const PIT_Z0 := -10.0
const PIT_Z1 := 1.0
const PIT_FLOOR := -0.9
const BALL_R := 0.22
const BALL_Y := -0.12

const FRAME := Color(0.2, 0.62, 0.25)
const PAD := Color(0.95, 0.3, 0.35)
const NET := Color(1.0, 0.85, 0.15)
const MAT := Color(0.55, 0.8, 0.95)
const WALL := Color(1.0, 0.95, 0.8)
const SLIDE := Color(1.0, 0.85, 0.15)

var spawn := Vector3(0, 0.1, 8)
## Where to stand to climb each climbing wall, and the floor it leads to (for tests).
var climb_spots: Array[Vector3] = []

var _nets: StaticBody3D
var _net_mat: StandardMaterial3D
var _balls: MultiMeshInstance3D
var _ball_cols := 0
var _ball_rows := 0
var _ball_rest: Array[Vector3] = []
## Balls pushed aside by the player, by index, so they can be put back.
var _pushed := {}
var _in_pit := false


func _ready() -> void:
	_nets = StaticBody3D.new()
	_nets.collision_layer = Player.NET_LAYER
	_nets.collision_mask = 0
	add_child(_nets)
	_net_mat = _make_net_material()
	_build_hall()
	_build_ball_pit()
	_build_frame()
	_build_tunnels()
	_build_top()
	_build_stairs()
	_build_slide()
	_build_tube(Vector3(6.5, 0, 4), 8.0)
	_home_door(Vector3(0, 0, 16), Basis.looking_at(Vector3.FORWARD, Vector3.UP))
	_edge_walls(HALL_X, Vector3(0, 0, (HALL_Z0 + HALL_Z1) * 0.5))


func _arrive() -> void:
	player.kill_y = global_position.y - 10.0
	player.fall_sound = "home"
	player.respawn_point = global_position + spawn
	player.teleport(global_position + spawn)
	player.look_toward(Vector3.FORWARD)
	sound.play("home")


func leave() -> void:
	super()
	player.move_scale = 1.0
	_in_pit = false


func _physics_process(_delta: float) -> void:
	if _in_pit:
		_push_balls(player.global_position - global_position)


# ---------- building ----------

## A see-through yellow net. It uses world coordinates for its pattern, so one material
## fits nets of every size.
func _make_net_material() -> StandardMaterial3D:
	var size := 32
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(NET, 0.08))
	for i in size:
		for w in 3:
			img.set_pixel(i, w, NET)
			img.set_pixel(w, i, NET)
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * 2.5
	return m


## A net panel: you cannot walk through it, but the camera sees (and moves) through it.
func _net(size: Vector3, pos: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _net_mat
	mi.position = pos
	add_child(mi)
	U.add_box_shape(_nets, size, pos)


func _build_hall() -> void:
	# The floor is four blocks around the hole for the ball pit.
	var h := 1.0
	var y := -h * 0.5
	var z_mid := (HALL_Z0 + HALL_Z1) * 0.5
	var depth := HALL_Z1 - HALL_Z0
	U.block(self, Vector3(PIT_X0 + HALL_X, h, depth), Vector3((PIT_X0 - HALL_X) * 0.5, y, z_mid), MAT)
	U.block(self, Vector3(HALL_X - PIT_X1, h, depth), Vector3((PIT_X1 + HALL_X) * 0.5, y, z_mid), MAT)
	U.block(self, Vector3(PIT_X1 - PIT_X0, h, PIT_Z0 - HALL_Z0), Vector3((PIT_X0 + PIT_X1) * 0.5, y, (HALL_Z0 + PIT_Z0) * 0.5), MAT)
	U.block(self, Vector3(PIT_X1 - PIT_X0, h, HALL_Z1 - PIT_Z1), Vector3((PIT_X0 + PIT_X1) * 0.5, y, (PIT_Z1 + HALL_Z1) * 0.5), MAT)
	# Colorful play mats.
	for i in 6:
		U.mesh_box(self, Vector3(3.6, 0.02, 3.6), Vector3(-1 + (i % 3) * 3.6, 0.01, 2 + (i / 3) * 3.6), COLORS[i])
	# Walls all around, with a rainbow band.
	var wall_h := 8.0
	for side: float in [-1.0, 1.0]:
		U.block(self, Vector3(0.5, wall_h, depth), Vector3(HALL_X * side, wall_h * 0.5, z_mid), WALL)
		var z := HALL_Z0 if side < 0 else HALL_Z1
		U.block(self, Vector3(HALL_X * 2, wall_h, 0.5), Vector3(0, wall_h * 0.5, z), WALL)
	for i in COLORS.size():
		var y_band := 1.5 + i * 0.3
		for side: float in [-1.0, 1.0]:
			U.mesh_box(self, Vector3(0.52, 0.3, depth), Vector3(HALL_X * side, y_band, z_mid), COLORS[i])
			U.mesh_box(self, Vector3(HALL_X * 2, 0.3, 0.52), Vector3(0, y_band, HALL_Z0 if side < 0 else HALL_Z1), COLORS[i])


## A sunken pit full of balls. The balls are one MultiMesh (cheap to draw); the ones near
## you move aside as you wade through.
func _build_ball_pit() -> void:
	var size := Vector3(PIT_X1 - PIT_X0, 0.5, PIT_Z1 - PIT_Z0)
	var center := Vector3((PIT_X0 + PIT_X1) * 0.5, PIT_FLOOR - 0.25, (PIT_Z0 + PIT_Z1) * 0.5)
	U.block(self, size, center, COLORS[5])
	# A colorful layer under the top balls, so the gaps do not look empty.
	U.mesh_box(self, Vector3(size.x, 0.02, size.z), Vector3(center.x, BALL_Y - 0.25, center.z), COLORS[0].lerp(COLORS[4], 0.5))
	# Soft red edges.
	for side: float in [-1.0, 1.0]:
		U.mesh_box(self, Vector3(size.x + 0.6, 0.3, 0.3), Vector3(center.x, 0.15, (PIT_Z0 if side < 0 else PIT_Z1) + 0.15 * side), PAD)
		U.mesh_box(self, Vector3(0.3, 0.3, size.z + 0.6), Vector3((PIT_X0 if side < 0 else PIT_X1) + 0.15 * side, 0.15, center.z), PAD)
	# A padded ramp to walk out.
	U.ramp(self, Vector3(PIT_X1 - 3.0, PIT_FLOOR, -4.5), Vector3(PIT_X1, 0.0, -4.5), 2.4, COLORS[3])

	var sphere := SphereMesh.new()
	sphere.radius = BALL_R
	sphere.height = BALL_R * 2
	sphere.radial_segments = 8
	sphere.rings = 4
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.5
	sphere.material = m
	var spacing := BALL_R * 1.9
	_ball_cols = int(size.x / spacing)
	_ball_rows = int(size.z / spacing)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = sphere
	mm.instance_count = _ball_cols * _ball_rows
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for r in _ball_rows:
		for c in _ball_cols:
			var i := r * _ball_cols + c
			var p := Vector3(PIT_X0 + (c + 0.5) * spacing + rng.randf_range(-0.05, 0.05), BALL_Y + rng.randf_range(-0.08, 0.04), PIT_Z0 + (r + 0.5) * spacing + rng.randf_range(-0.05, 0.05))
			_ball_rest.append(p)
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
			mm.set_instance_color(i, COLORS[rng.randi() % COLORS.size()])
	_balls = MultiMeshInstance3D.new()
	_balls.multimesh = mm
	add_child(_balls)

	# Inside the pit you walk a little slower, and jumping in throws balls up.
	var area := Area3D.new()
	U.add_box_shape(area, Vector3(size.x, 1.2, size.z), Vector3(center.x, PIT_FLOOR + 0.6, center.z))
	add_child(area)
	area.body_entered.connect(func(body: Node3D):
		if body == player:
			_in_pit = true
			player.move_scale = 0.7
			if body.velocity.y < -3.0 or body.velocity.length() > 6.0:
				_ball_burst(body.global_position)
				sound.play("boing", -4.0, 1.6), CONNECT_DEFERRED)
	area.body_exited.connect(func(body: Node3D):
		if body == player:
			_in_pit = false
			player.move_scale = 1.0
			_push_balls(Vector3(1000, 0, 1000)), CONNECT_DEFERRED)


## Moves the balls near `at` (local position) aside, and puts the others back.
func _push_balls(at: Vector3) -> void:
	var radius := 1.1
	var spacing := BALL_R * 1.9
	var mm := _balls.multimesh
	var near := {}
	var c0 := int((at.x - radius - PIT_X0) / spacing)
	var r0 := int((at.z - radius - PIT_Z0) / spacing)
	var span := int(radius * 2 / spacing) + 2
	for r in range(maxi(r0, 0), mini(r0 + span, _ball_rows)):
		for c in range(maxi(c0, 0), mini(c0 + span, _ball_cols)):
			var i := r * _ball_cols + c
			var rest := _ball_rest[i]
			var away := Vector3(rest.x - at.x, 0, rest.z - at.z)
			var d := away.length()
			if d >= radius:
				continue
			var push := radius - d
			var p := rest + away.normalized() * push * 0.5 + Vector3.UP * push * 0.35
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
			near[i] = true
	for i in _pushed:
		if not near.has(i):
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, _ball_rest[i]))
	_pushed = near


func _ball_burst(pos: Vector3) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = BALL_R
	sphere.height = BALL_R * 2
	sphere.radial_segments = 8
	sphere.rings = 4
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	sphere.material = m
	var c := CPUParticles3D.new()
	c.mesh = sphere
	c.amount = 24
	c.lifetime = 1.2
	c.one_shot = true
	c.explosiveness = 1.0
	c.direction = Vector3.UP
	c.spread = 50
	c.initial_velocity_min = 3
	c.initial_velocity_max = 6
	c.gravity = Vector3(0, -12, 0)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
	ramp.colors = PackedColorArray(COLORS.slice(0, 6))
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	c.color_initial_ramp = ramp
	c.top_level = true
	add_child(c)
	c.global_position = Vector3(pos.x, global_position.y + BALL_Y, pos.z)
	c.emitting = true
	get_tree().create_timer(1.6).timeout.connect(c.queue_free)


## The solid parts of the frame: the first floor block (with the first climbing wall on
## its front) and the top floor block (with the second climbing wall).
func _build_frame() -> void:
	var cols := MAP[0].length()
	var width := cols * CELL
	var x_mid := MAP_X0 + width * 0.5
	var z_front := MAP_Z0 + MAP.size() * CELL
	var depth := z_front - MAP_Z0
	U.block(self, Vector3(width, FLOOR1, depth - 0.3), Vector3(x_mid, FLOOR1 * 0.5, MAP_Z0 + (depth - 0.3) * 0.5), FRAME)
	# The front face, in three parts: padded, climbing wall, padded.
	var climb_x0 := MAP_X0 + 3 * CELL
	var climb_x1 := MAP_X0 + 6 * CELL
	var face_z := z_front - 0.15
	U.block(self, Vector3(climb_x0 - MAP_X0, FLOOR1, 0.3), Vector3((MAP_X0 + climb_x0) * 0.5, FLOOR1 * 0.5, face_z), PAD)
	U.block(self, Vector3(MAP_X0 + width - climb_x1, FLOOR1, 0.3), Vector3((climb_x1 + MAP_X0 + width) * 0.5, FLOOR1 * 0.5, face_z), PAD)
	_climbing_wall(Vector3(climb_x1 - climb_x0, FLOOR1, 0.3), Vector3((climb_x0 + climb_x1) * 0.5, FLOOR1 * 0.5, face_z))
	climb_spots.append(Vector3(0, 0.1, z_front + 1.0))

	# The top floor sits on the "T" cells.
	var t_x1 := MAP_X0 + 3 * CELL
	var t_z1 := MAP_Z0 + 2 * CELL
	var top_h := FLOOR2 - FLOOR1
	U.block(self, Vector3(t_x1 - MAP_X0, top_h, t_z1 - MAP_Z0 - 0.3), Vector3((MAP_X0 + t_x1) * 0.5, FLOOR1 + top_h * 0.5, (MAP_Z0 + t_z1 - 0.3) * 0.5), FRAME)
	var wx0 := MAP_X0 + CELL
	var wx1 := MAP_X0 + 2 * CELL
	var wz := t_z1 - 0.15
	U.block(self, Vector3(CELL, top_h, 0.3), Vector3(MAP_X0 + CELL * 0.5, FLOOR1 + top_h * 0.5, wz), PAD)
	U.block(self, Vector3(CELL, top_h, 0.3), Vector3(wx1 + CELL * 0.5, FLOOR1 + top_h * 0.5, wz), PAD)
	_climbing_wall(Vector3(wx1 - wx0, top_h, 0.3), Vector3((wx0 + wx1) * 0.5, FLOOR1 + top_h * 0.5, wz))
	climb_spots.append(Vector3((wx0 + wx1) * 0.5, FLOOR1 + 0.1, t_z1 + 1.0))


## A wall with colorful holds. Push into it to climb.
func _climbing_wall(size: Vector3, pos: Vector3) -> void:
	var wall := U.block(self, size, pos, COLORS[4])
	wall.set_meta("climb", true)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pos.x * 10 + pos.y * 100)
	var x := -size.x * 0.5 + 0.4
	while x < size.x * 0.5 - 0.2:
		var y := -size.y * 0.5 + 0.4 + rng.randf_range(0, 0.4)
		while y < size.y * 0.5 - 0.2:
			var hold := U.mesh_box(wall, Vector3(0.28, 0.22, 0.12), Vector3(x + rng.randf_range(-0.15, 0.15), y, size.z * 0.5 + 0.05), COLORS[rng.randi() % COLORS.size()])
			hold.rotation.z = rng.randf_range(-0.6, 0.6)
			y += rng.randf_range(0.55, 0.8)
		x += 0.7


func _cell(c: int, r: int) -> String:
	if r < 0 or r >= MAP.size() or c < 0 or c >= MAP[r].length():
		return ""
	return MAP[r][c]


func _is_tunnel(ch: String) -> bool:
	return ch == "." or ch == "W"


## Net walls between tunnel cells and everything else, net roofs on top, green posts at the
## corners, cushions in the closed cells and punching bags hanging in two tunnels.
func _build_tunnels() -> void:
	var wall_y := FLOOR1 + TUNNEL_H * 0.5
	for r in MAP.size():
		for c in MAP[r].length():
			var ch := _cell(c, r)
			var center := Vector3(MAP_X0 + (c + 0.5) * CELL, FLOOR1, MAP_Z0 + (r + 0.5) * CELL)
			if ch == "#":
				U.mesh_box(self, Vector3(CELL - 0.3, 0.6, CELL - 0.3), center + Vector3.UP * 0.3, COLORS[(c + r) % COLORS.size()])
				continue
			if not _is_tunnel(ch):
				continue
			if ch != "W":
				_net(Vector3(CELL, 0.1, CELL), center + Vector3.UP * (TUNNEL_H + 0.05))
			# Left, right, back, front.
			var sides := [[-1, 0], [1, 0], [0, -1], [0, 1]]
			for s in sides:
				var other := _cell(c + s[0], r + s[1])
				if _is_tunnel(other) or other == "T":
					continue
				if s[1] == 1 and r == MAP.size() - 1 and OPEN_FRONT.has(c):
					continue
				var edge := center + Vector3(s[0], 0, s[1]) * CELL * 0.5
				var size := Vector3(0.1, TUNNEL_H, CELL) if s[0] != 0 else Vector3(CELL, TUNNEL_H, 0.1)
				_net(size, Vector3(edge.x, wall_y, edge.z))
	# Green posts where nets meet.
	for r in MAP.size() + 1:
		for c in MAP[0].length() + 1:
			var around := [_cell(c - 1, r - 1), _cell(c, r - 1), _cell(c - 1, r), _cell(c, r)]
			if not around.any(_is_tunnel) or around.all(_is_tunnel):
				continue
			U.mesh_box(self, Vector3(0.22, TUNNEL_H, 0.22), Vector3(MAP_X0 + c * CELL, wall_y, MAP_Z0 + r * CELL), FRAME)
	for cell: Vector2i in [Vector2i(4, 0), Vector2i(6, 1)]:
		_punching_bag(Vector3(MAP_X0 + (cell.x + 0.5) * CELL, FLOOR1, MAP_Z0 + (cell.y + 0.5) * CELL))


## A soft bag hanging from the roof. It swings when you walk through it.
func _punching_bag(floor_pos: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.position = floor_pos + Vector3.UP * TUNNEL_H
	add_child(pivot)
	U.mesh_box(pivot, Vector3(0.05, 0.6, 0.05), Vector3(0, -0.3, 0), Color(0.3, 0.3, 0.3))
	for k in 3:
		U.mesh_cylinder(pivot, 0.35, 0.4, Vector3(0, -0.8 - k * 0.4, 0), COLORS[(k * 2) % COLORS.size()])
	var area := Area3D.new()
	U.add_box_shape(area, Vector3(1.0, 1.4, 1.0), Vector3(0, 1.0, 0))
	area.position = floor_pos
	add_child(area)
	area.body_entered.connect(func(body: Node3D):
		if body == player:
			sound.play("kick", -4.0)
			var dir := (floor_pos + global_position - body.global_position)
			var tw := create_tween()
			tw.tween_property(pivot, "rotation", Vector3(dir.z, 0, -dir.x).normalized() * 0.6, 0.25)
			tw.tween_property(pivot, "rotation", Vector3.ZERO, 1.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT), CONNECT_DEFERRED)


## The top floor: net rails, a cheer when you get there, and a little deck where the slide starts.
func _build_top() -> void:
	var t_x1 := MAP_X0 + 3 * CELL
	var t_z1 := MAP_Z0 + 2 * CELL
	var rail_h := 2.0
	var y := FLOOR2 + rail_h * 0.5
	# Back rail, and the front rail with a gap over the climbing wall.
	_net(Vector3(t_x1 - MAP_X0, rail_h, 0.1), Vector3((MAP_X0 + t_x1) * 0.5, y, MAP_Z0))
	_net(Vector3(CELL, rail_h, 0.1), Vector3(MAP_X0 + CELL * 0.5, y, t_z1))
	_net(Vector3(CELL, rail_h, 0.1), Vector3(MAP_X0 + CELL * 2.5, y, t_z1))
	_net(Vector3(0.1, rail_h, t_z1 - MAP_Z0), Vector3(t_x1, y, (MAP_Z0 + t_z1) * 0.5))
	# The left rail has a gap that leads to the slide deck.
	_net(Vector3(0.1, rail_h, 1.5), Vector3(MAP_X0, y, MAP_Z0 + 0.75))
	_net(Vector3(0.1, rail_h, 1.5), Vector3(MAP_X0, y, t_z1 - 0.75))
	for p: Vector3 in [Vector3(MAP_X0, 0, MAP_Z0), Vector3(t_x1, 0, MAP_Z0), Vector3(MAP_X0, 0, t_z1), Vector3(t_x1, 0, t_z1)]:
		U.mesh_box(self, Vector3(0.25, rail_h + 0.2, 0.25), p + Vector3.UP * (FLOOR2 + rail_h * 0.5 + 0.1), FRAME)
	# A flag on the back corner.
	U.mesh_box(self, Vector3(0.12, 3.0, 0.12), Vector3(t_x1, FLOOR2 + 2.5, MAP_Z0), Color(0.3, 0.3, 0.3))
	U.mesh_box(self, Vector3(1.2, 0.7, 0.05), Vector3(t_x1 - 0.6, FLOOR2 + 3.6, MAP_Z0), COLORS[0])

	# Reaching the top plays a fanfare with confetti.
	var goal := Area3D.new()
	U.add_box_shape(goal, Vector3(t_x1 - MAP_X0 - 1.0, 1.5, t_z1 - MAP_Z0 - 1.0), Vector3((MAP_X0 + t_x1) * 0.5, FLOOR2 + 0.75, (MAP_Z0 + t_z1) * 0.5))
	add_child(goal)
	goal.body_entered.connect(func(body: Node3D):
		if body == player:
			sound.play("fanfare")
			U.confetti(self, body.global_position + Vector3.UP, 30, COLORS), CONNECT_DEFERRED)


## Padded rainbow steps from the floor up to the right end of the first floor.
func _build_stairs() -> void:
	var x := MAP_X0 + 8.5 * CELL
	var z_front := MAP_Z0 + MAP.size() * CELL
	var bottom := Vector3(x, 0, z_front + 10.0)
	var top := Vector3(x, FLOOR1, z_front)
	var width := CELL - 0.2
	U.ramp(self, bottom, top, width, PAD)
	U.ramp_walls(self, bottom, top, width, FRAME, 1.0)
	var steps := 10
	for i in steps:
		var p := bottom.lerp(top, (i + 0.5) / steps)
		var roll := U.mesh_cylinder(self, 0.32, width, p + Vector3.UP * 0.05, COLORS[i % COLORS.size()])
		roll.rotation.z = PI * 0.5


## A little deck left of the top floor, and a big yellow slide from it down into the ball pit.
func _build_slide() -> void:
	var x := -16.5
	var deck_z0 := MAP_Z0 + 1.5
	var deck_z1 := MAP_Z0 + 4.5
	var deck_x0 := -18.0
	U.block(self, Vector3(MAP_X0 - deck_x0, 0.4, deck_z1 - deck_z0), Vector3((deck_x0 + MAP_X0) * 0.5, FLOOR2 - 0.2, (deck_z0 + deck_z1) * 0.5), FRAME)
	for p: Vector3 in [Vector3(deck_x0, 0, deck_z0), Vector3(deck_x0, 0, deck_z1)]:
		U.mesh_box(self, Vector3(0.3, FLOOR2, 0.3), p + Vector3(0.15, FLOOR2 * 0.5, 0), FRAME)
	var y := FLOOR2 + 0.6
	_net(Vector3(MAP_X0 - deck_x0, 1.2, 0.1), Vector3((deck_x0 + MAP_X0) * 0.5, y, deck_z0))
	_net(Vector3(0.1, 1.2, deck_z1 - deck_z0), Vector3(deck_x0, y, (deck_z0 + deck_z1) * 0.5))
	_net(Vector3(MAP_X0 - (x + 1.3), 1.2, 0.1), Vector3((x + 1.3 + MAP_X0) * 0.5, y, deck_z1))

	var top := Vector3(x, FLOOR2, deck_z1)
	var bottom := Vector3(x, BALL_Y + 0.2, -3.0)
	var slide := U.ramp(self, top, bottom, 2.4, SLIDE)
	slide.set_meta("slide", true)
	U.ramp_walls(self, top, bottom, 2.4, SLIDE.darkened(0.1), 0.8)
	for z: float in [-16.0, -11.0]:
		var t := (z - top.z) / (bottom.z - top.z)
		var h := lerpf(top.y, bottom.y, t)
		U.mesh_box(self, Vector3(0.25, h, 0.25), Vector3(x, h * 0.5, z), FRAME)


## A walk-through tunnel of rainbow hoops along x, centered at `center`.
func _build_tube(center: Vector3, length: float) -> void:
	var r := 1.5
	var hoops := int(length / 0.8)
	for i in hoops + 1:
		var x := center.x - length * 0.5 + i * length / hoops
		var color := COLORS[i % COLORS.size()]
		for k in 8:
			var a := TAU * k / 8.0 + PI / 8.0
			var piece := U.mesh_box(self, Vector3(0.3, 1.25, 0.3), Vector3(x, center.y + r * 0.95 + sin(a) * r, center.z + cos(a) * r), color)
			piece.rotation.x = -a
	# Walls and roof you cannot pass, but the camera can.
	for side: float in [-1.0, 1.0]:
		U.add_box_shape(_nets, Vector3(length, 2.6, 0.2), center + Vector3(0, 1.3, r * side))
	U.add_box_shape(_nets, Vector3(length, 0.2, r * 2), center + Vector3(0, 2.75, 0))
