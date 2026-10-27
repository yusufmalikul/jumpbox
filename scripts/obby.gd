extends Node3D
## A course of easy jumps high in the sky, going up through 10 numbered checkpoints.
## You get here through the rainbow portal in the park. Fall into the clouds and you
## come back at the last checkpoint. Gaps are short and steps are low, made for small kids.

const U := preload("res://scripts/util.gd")
const Rides := preload("res://scripts/rides.gd")

const CHECKPOINTS := 10
## Platform width and depth, and the gap between platforms. Wide and close, for small kids.
const W := 5.0
const D := 4.0
const GAP := 0.8
const PAD := Color(0.85, 0.86, 0.9)
const COLORS: Array[Color] = [
	Color(0.95, 0.3, 0.3), Color(1.0, 0.6, 0.15), Color(1.0, 0.85, 0.2), Color(0.4, 0.8, 0.3),
	Color(0.25, 0.65, 0.95), Color(0.55, 0.4, 0.9), Color(0.95, 0.45, 0.75),
]

signal go_home

var player: Node
var sound: Node
var ui: Node

## Where you stand at each checkpoint. Index 0 is the start pad.
var spots: Array[Vector3] = []
## The top of every platform in order, with the checkpoint index it belongs to (for tests).
var path: Array = []
## The checkpoint you come back to.
var current := 0
var active := false

# Building state: the top-center of the last platform, which way the course goes,
# and how far the last platform reaches along that way.
var _p := Vector3.ZERO
var _dir := Vector3.FORWARD
var _half := 0.0
var _color := Color.WHITE


func _ready() -> void:
	_start()
	_stage(1)
	for i in 4:
		_plat(W, D, GAP, 0.4)
	_checkpoint()

	_stage(2)  # zig-zag
	for i in 5:
		_plat(W, D, GAP, 0.4, 1.2 if i % 2 == 0 else -1.2)
	_checkpoint()

	_turn(90)
	_stage(3)  # stairs, no gaps
	for i in 7:
		_plat(W + 1.0, 1.4, 0.0, 0.5)
	_checkpoint()

	_stage(4)  # a trampoline up to a high ledge
	_plat(W, D, GAP, 0.0)
	_bouncer(GAP)
	_plat(W + 1.0, W, 0.6, 3.0)
	_checkpoint()

	_turn(90)
	_stage(5)  # a platform that slowly carries you across
	_mover(5.0)
	_plat(W, D, 0.3, 0.0)
	_checkpoint()

	_stage(6)  # a wide bridge with a bump
	_plat(W, 6.0, GAP, 0.0)
	_plat(W, 2.0, 0.0, 0.5)
	_plat(W, 6.0, 0.0, 0.5)
	_checkpoint()

	_turn(-90)
	_stage(7)  # round stepping stones
	for i in 6:
		_stone(2.2, GAP, 0.3, 0.8 if i % 3 == 1 else (-0.8 if i % 3 == 2 else 0.0))
	_checkpoint()

	_stage(8)  # a gentle spiral up
	for i in 8:
		_turn(25)
		_plat(W, D, GAP, 0.5)
	_checkpoint()

	_turn(90)
	_stage(9)  # two trampolines
	_bouncer(GAP)
	_plat(W + 1.0, W, 0.6, 2.5)
	_bouncer(0.6)
	_plat(W + 1.0, W, 0.6, 2.5)
	_checkpoint()

	_stage(10)  # the big stairs to the top
	for i in 8:
		_plat(W + 2.0, 1.4, 0.0, 0.5)
	_checkpoint(true)
	_build_cloud_floor()


## Sends the player to the course, at the last checkpoint they reached.
func enter() -> void:
	active = true
	player.kill_y = global_position.y - 8.0
	_go_to(current)
	ui.show_stage = true
	ui.stage = current
	ui.queue_redraw()


func leave() -> void:
	active = false
	ui.show_stage = false
	ui.queue_redraw()


## Moves to another checkpoint (the < and > buttons).
func skip(step: int) -> void:
	if not active:
		return
	current = clampi(current + step, 0, CHECKPOINTS)
	_go_to(current)
	ui.stage = current
	ui.queue_redraw()


func _go_to(i: int) -> void:
	player.respawn_point = spots[i]
	player.teleport(spots[i])
	sound.play("home")


func _on_checkpoint(body: Node3D, i: int) -> void:
	if body != player or i <= current:
		return
	current = i
	player.respawn_point = spots[i]
	ui.stage = i
	ui.queue_redraw()
	_confetti(spots[i], 120 if i == CHECKPOINTS else 50)
	sound.play("fanfare" if i == CHECKPOINTS else "checkpoint")


# ---------- building ----------

func _stage(n: int) -> void:
	_color = COLORS[(n - 1) % COLORS.size()]


func _turn(degrees: float) -> void:
	_dir = _dir.rotated(Vector3.UP, deg_to_rad(degrees))


func _right() -> Vector3:
	return _dir.cross(Vector3.UP)


## Places a box platform after the last one: `gap` metres further along, `rise` metres higher,
## and `side` metres to the side. Its top is where you stand.
func _plat(width: float, depth: float, gap: float, rise: float, side := 0.0, color := Color.TRANSPARENT) -> StaticBody3D:
	var top := _p + _dir * (_half + gap + depth * 0.5) + _right() * side + Vector3.UP * rise
	var xform := Transform3D(Basis.looking_at(_dir, Vector3.UP), top + Vector3.DOWN * 0.3)
	var body := U.solid_box(self, Vector3(width, 0.6, depth), xform, _color if color == Color.TRANSPARENT else color)
	_p = top
	_half = depth * 0.5
	path.append([global_position + _p, spots.size()])
	return body


func _stone(radius: float, gap: float, rise: float, side: float) -> void:
	var top := _p + _dir * (_half + gap + radius) + _right() * side + Vector3.UP * rise
	U.solid_cylinder(self, radius, 0.6, top + Vector3.DOWN * 0.3, _color)
	_p = top
	_half = radius
	path.append([global_position + _p, spots.size()])


func _bouncer(gap: float) -> void:
	var radius := 2.4
	var top := _p + _dir * (_half + gap + radius)
	U.solid_cylinder(self, radius, 0.6, top + Vector3.DOWN * 0.4, Color(0.55, 0.4, 0.9))
	var pad := U.solid_cylinder(self, radius - 0.3, 0.1, top + Vector3.DOWN * 0.05, Color(0.15, 0.15, 0.2))
	pad.set_meta("bounce", 13.0)
	_p = top
	_half = radius
	path.append([global_position + _p, spots.size()])


## A platform that glides back and forth over `distance` metres.
func _mover(distance: float) -> void:
	var size := W
	var start := _p + _dir * (_half + 0.3 + size * 0.5)
	var mover := Rides.Mover.new()
	mover.start = start + Vector3.DOWN * 0.3
	mover.offset = _dir * distance
	mover.period = 9.0
	mover.basis = Basis.looking_at(_dir, Vector3.UP)
	U.mesh_box(mover, Vector3(size, 0.6, size), Vector3.ZERO, _color)
	U.add_box_shape(mover, Vector3(size, 0.6, size))
	add_child(mover)
	path.append([global_position + start, spots.size()])
	path.append([global_position + start + _dir * distance, spots.size()])
	_p = start + _dir * distance
	_half = size * 0.5


func _start() -> void:
	_p = Vector3.ZERO
	_half = 0.0
	U.block(self, Vector3(6, 0.6, 6), Vector3(0, -0.3, 0), PAD)
	U.mesh_box(self, Vector3(4, 0.04, 4), Vector3(0, 0.02, 0), Color.WHITE)
	_half = 3.0
	spots.append(global_position + Vector3(0, 0.1, 0))


func _checkpoint(final := false) -> void:
	var size := 8.0 if final else 6.0
	_plat(size, size, GAP, 0.3, 0.0, PAD)
	var i := spots.size()
	spots.append(global_position + _p + Vector3.UP * 0.1)
	U.mesh_box(self, Vector3(size - 1.4, 0.04, size - 1.4), _p + Vector3.UP * 0.02, Color.WHITE)

	var label := Label3D.new()
	label.text = str(i)
	label.font_size = 220
	label.pixel_size = 0.008
	label.modulate = Color(0.15, 0.15, 0.2)
	label.outline_size = 0
	label.double_sided = true
	label.basis = Basis.looking_at(_dir, Vector3.UP) * Basis(Vector3.RIGHT, -PI * 0.5)
	label.position = _p + Vector3.UP * 0.05 - _dir * 0.8
	add_child(label)

	# A flag at the far left corner.
	var corner := _p + _dir * (size * 0.5 - 0.4) - _right() * (size * 0.5 - 0.4)
	U.mesh_box(self, Vector3(0.12, 2.4, 0.12), corner + Vector3.UP * 1.2, Color(0.3, 0.3, 0.3))
	U.mesh_box(self, Vector3(0.05, 0.6, 1.0), corner + Vector3.UP * 2.1 - _dir * 0.5, _color)

	var area := Area3D.new()
	area.position = _p + Vector3.UP * 1.0
	U.add_box_shape(area, Vector3(size, 2.0, size))
	add_child(area)
	area.body_entered.connect(_on_checkpoint.bind(i), CONNECT_DEFERRED)

	if final:
		_build_trophy()


func _build_trophy() -> void:
	var gold := Color(1.0, 0.8, 0.15)
	var base := _p + _dir * 1.8
	U.block(self, Vector3(1.4, 0.8, 1.4), base + Vector3.UP * 0.4, Color(0.3, 0.3, 0.35))
	U.mesh_box(self, Vector3(0.4, 0.8, 0.4), base + Vector3.UP * 1.2, gold)
	U.mesh_box(self, Vector3(1.3, 1.1, 1.3), base + Vector3.UP * 2.1, gold)
	for s: float in [-1.0, 1.0]:
		U.mesh_box(self, Vector3(0.2, 0.7, 0.2), base + Vector3.UP * 2.2 + _right() * 0.8 * s, gold)

	# A rainbow portal next to the trophy takes you home.
	var spot := _p - _right() * 2.2
	var portal := U.portal(self, spot, Basis.looking_at(_right(), Vector3.UP), COLORS)
	portal.body_entered.connect(func(body: Node3D):
		if body == player:
			go_home.emit(), CONNECT_DEFERRED)


func _build_cloud_floor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for s in spots:
		lo = lo.min(s - global_position)
		hi = hi.max(s - global_position)
	lo -= Vector3(25, 0, 25)
	hi += Vector3(25, 0, 25)
	# A sea of clouds. A plane only shows its top side, so from the park it is invisible.
	var sea := PlaneMesh.new()
	sea.size = Vector2(hi.x - lo.x + 300, hi.z - lo.z + 300)
	var sea_mi := MeshInstance3D.new()
	sea_mi.mesh = sea
	sea_mi.material_override = U.mat(Color(0.9, 0.94, 1.0))
	sea_mi.position = Vector3((lo.x + hi.x) * 0.5, -13, (lo.z + hi.z) * 0.5)
	add_child(sea_mi)
	for i in 50:
		var p := Vector3(rng.randf_range(lo.x, hi.x), rng.randf_range(-14, -11), rng.randf_range(lo.z, hi.z))
		U.mesh_box(self, Vector3(rng.randf_range(8, 16), rng.randf_range(1.5, 3), rng.randf_range(6, 12)), p, Color(1, 1, 1))


func _confetti(pos: Vector3, amount: int) -> void:
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
	ramp.colors = PackedColorArray(COLORS.slice(0, 6))
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	c.color_initial_ramp = ramp
	c.top_level = true
	add_child(c)
	c.global_position = pos + Vector3.UP * 0.5
	c.emitting = true
	get_tree().create_timer(3.0).timeout.connect(c.queue_free)
