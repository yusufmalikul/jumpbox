extends Node3D
## Base for the jump courses: 10 numbered checkpoints from a start pad to a trophy.
## A course is built the first time you enter it, and hidden (and taken out of physics)
## while you are somewhere else. Fall too low and you come back at the last checkpoint.
## Subclasses lay out the platforms in _layout() and make the floor in _build_floor().

const U := preload("res://scripts/util.gd")
const Rides := preload("res://scripts/rides.gd")

const CHECKPOINTS := 10
## Platform width and depth, and the gap between platforms. Wide and close, for small kids.
const W := 5.0
const D := 4.0
const GAP := 0.8
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

## Falling this far below the start pad sends you back.
var kill_depth := 8.0
## The sound for falling off.
var fall_sound := "home"
## Colors for the stages, in turn, and for the checkpoint pads.
var palette: Array[Color] = COLORS
var pad_color := Color(0.85, 0.86, 0.9)

# Building state: the top-center of the last platform, which way the course goes,
# and how far the last platform reaches along that way.
var _p := Vector3.ZERO
var _dir := Vector3.FORWARD
var _half := 0.0
var _color := Color.WHITE


func _ready() -> void:
	_start()
	_layout()
	_build_floor()


func _layout() -> void:
	pass


func _build_floor() -> void:
	pass


## Sends the player to the course, at the last checkpoint they reached.
func enter() -> void:
	active = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	player.kill_y = global_position.y - kill_depth
	player.fall_sound = fall_sound
	_go_to(current)
	ui.show_stage = true
	ui.stage = current
	ui.queue_redraw()


func leave() -> void:
	active = false
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
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
	_color = palette[(n - 1) % palette.size()]


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


## A platform that slides side to side across the path, so you wait for it to come close.
func _side_mover(amplitude: float) -> void:
	var size := W
	var center := _p + _dir * (_half + GAP + size * 0.5)
	var mover := Rides.Mover.new()
	mover.start = center - _right() * amplitude + Vector3.DOWN * 0.3
	mover.offset = _right() * amplitude * 2.0
	mover.period = 8.0
	mover.basis = Basis.looking_at(_dir, Vector3.UP)
	U.mesh_box(mover, Vector3(size, 0.6, size), Vector3.ZERO, _color)
	U.add_box_shape(mover, Vector3(size, 0.6, size))
	add_child(mover)
	_p = center
	_half = size * 0.5
	path.append([global_position + _p, spots.size(), mover])


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
	# For the test bot: wait for the mover at its near end, ride it to the far end.
	path.append([global_position + start, spots.size(), mover])
	path.append([global_position + start + _dir * distance, spots.size(), mover])
	_p = start + _dir * distance
	_half = size * 0.5


func _start() -> void:
	_p = Vector3.ZERO
	_half = 0.0
	U.block(self, Vector3(6, 0.6, 6), Vector3(0, -0.3, 0), pad_color)
	U.mesh_box(self, Vector3(4, 0.04, 4), Vector3(0, 0.02, 0), Color.WHITE)
	_half = 3.0
	spots.append(global_position + Vector3(0, 0.1, 0))


func _checkpoint(final := false) -> void:
	var size := 8.0 if final else 6.0
	_plat(size, size, GAP, 0.3, 0.0, pad_color)
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


## The area the course covers (from the checkpoints), plus a margin. Used to size floors.
func _bounds(margin: float) -> AABB:
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for spot in spots:
		lo = lo.min(spot - global_position)
		hi = hi.max(spot - global_position)
	return AABB(lo - Vector3(margin, 0, margin), hi - lo + Vector3(margin * 2, 0, margin * 2))


func _confetti(pos: Vector3, amount: int) -> void:
	U.confetti(self, pos, amount, COLORS)
