extends Node3D
## A giant spiral slide that winds around a tall tower, from the top all the way down.
## You arrive at the top. At the bottom, one door takes you up again and one takes you home.
## It has the same enter/leave/skip API as course.gd, so main.gd treats it like a course.

const U := preload("res://scripts/util.gd")

const HEIGHT := 40.0
const TURNS := 5.0
const RADIUS := 7.0
const WIDTH := 2.6
const SEGMENTS_PER_TURN := 32
const COLORS: Array[Color] = [
	Color(0.95, 0.3, 0.3), Color(1.0, 0.6, 0.15), Color(1.0, 0.85, 0.2), Color(0.4, 0.8, 0.3),
	Color(0.25, 0.65, 0.95), Color(0.55, 0.4, 0.9), Color(0.95, 0.45, 0.75),
]

signal go_home

var player: Node
var sound: Node
var ui: Node
var active := false

## Where you start at the top, and where the slide ends at the bottom.
var top_spot := Vector3.ZERO
var bottom_spot := Vector3.ZERO


func _ready() -> void:
	_build_ground()
	_build_tower()
	_build_slide()
	_build_bottom()


func enter() -> void:
	active = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	player.kill_y = global_position.y - 10.0
	player.fall_sound = "home"
	_go_up()
	ui.show_stage = false
	ui.queue_redraw()


func leave() -> void:
	active = false
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


func skip(_step: int) -> void:
	pass


func _go_up() -> void:
	player.respawn_point = top_spot
	player.teleport(top_spot)
	# Look toward the start of the slide.
	player.look_toward(global_position + _helix(0.02) - top_spot)
	sound.play("home")


## A point on the slide's center line. t goes from 0 at the top to 1 at the bottom.
func _helix(t: float) -> Vector3:
	var a := t * TURNS * TAU
	return Vector3(cos(a) * RADIUS, HEIGHT * (1.0 - t) + 0.3, sin(a) * RADIUS)


func _build_ground() -> void:
	U.block(self, Vector3(90, 1, 90), Vector3(0, -0.5, 0), Color(0.42, 0.78, 0.35))
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in 24:
		var a := TAU * i / 24.0 + rng.randf_range(-0.1, 0.1)
		var r := rng.randf_range(24, 40)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		var trunk_h := rng.randf_range(1.6, 2.6)
		U.block(self, Vector3(0.6, trunk_h, 0.6), p + Vector3(0, trunk_h * 0.5, 0), Color(0.6, 0.4, 0.22))
		U.mesh_box(self, Vector3(2.6, 1.6, 2.6), p + Vector3(0, trunk_h + 0.7, 0), Color(0.2, rng.randf_range(0.5, 0.7), 0.25))
	# Tall invisible walls around the edge.
	for side: float in [-1.0, 1.0]:
		var wall := StaticBody3D.new()
		add_child(wall)
		U.add_box_shape(wall, Vector3(1, 80, 90), Vector3(44 * side, 40, 0))
		U.add_box_shape(wall, Vector3(90, 80, 1), Vector3(0, 40, 44 * side))


func _build_tower() -> void:
	# The middle column, in rainbow rings.
	var ring_h := HEIGHT / COLORS.size()
	for i in COLORS.size():
		U.solid_cylinder(self, 3.0, ring_h, Vector3(0, ring_h * (i + 0.5), 0), COLORS[i])
	# The top deck: a round floor inside the spiral, with a low wall, open where the slide starts.
	var deck_y := HEIGHT + 0.3
	var deck_r := RADIUS - WIDTH * 0.5 - 0.2
	U.solid_cylinder(self, deck_r, 0.6, Vector3(0, deck_y - 0.3, 0), Color(0.9, 0.9, 0.95))
	var rail_r := deck_r - 0.15
	for i in 24:
		var a := TAU * i / 24.0
		# Leave a gap where the slide starts (angle 0, going toward +angle).
		if a < 0.6:
			continue
		var b := U.block(self, Vector3(0.25, 1.0, 1.6), Vector3(cos(a) * rail_r, deck_y + 0.5, sin(a) * rail_r), Color.WHITE)
		b.rotation.y = -a
	top_spot = global_position + Vector3(1.5, deck_y + 0.1, -1.5)
	# A flag on the very top.
	U.mesh_box(self, Vector3(0.15, 3.0, 0.15), Vector3(0, deck_y + 1.5, 0), Color(0.3, 0.3, 0.3))
	U.mesh_box(self, Vector3(1.4, 0.8, 0.06), Vector3(0.7, deck_y + 2.6, 0), COLORS[0])


## The slide is many short straight pieces along a spiral. Each piece is a little longer
## than needed, so the pieces overlap and there are no gaps on the curve.
func _build_slide() -> void:
	var count := int(TURNS * SEGMENTS_PER_TURN)
	for i in count:
		var t0 := float(i) / count
		var t1 := float(i + 1) / count
		var from := _helix(t0)
		var to := _helix(t1)
		var dir := (to - from).normalized()
		from -= dir * 0.25
		to += dir * 0.25
		var color := COLORS[int(t0 * TURNS * 2) % COLORS.size()]
		var piece := U.ramp(self, from, to, WIDTH, color)
		piece.set_meta("slide", true)
		# No inner wall at the very start, so you can step from the deck onto the slide.
		_walls(from, to, color, i >= SEGMENTS_PER_TURN / 6)
	# A flat run-out at the bottom, so you glide to a stop.
	var end := _helix(1.0)
	var out_dir := (_helix(1.0) - _helix(1.0 - 1.0 / count)).normalized()
	out_dir.y = 0
	out_dir = out_dir.normalized()
	var stop := end + out_dir * 10.0
	stop.y = 0.02
	U.ramp(self, end, stop, WIDTH + 1.0, Color(0.95, 0.85, 0.6))
	bottom_spot = global_position + Vector3(stop.x, 0.1, stop.z)


## Walls on both sides of a slide piece. The outer wall is taller, to catch you on the curves.
func _walls(from: Vector3, to: Vector3, color: Color, inner := true) -> void:
	var dir := to - from
	var b := Basis.looking_at(dir, Vector3.UP)
	var mid := (from + to) * 0.5
	var outward := Vector3(mid.x, 0, mid.z).normalized()
	for side: float in [-1.0, 1.0]:
		var offset := b.x * side * (WIDTH * 0.5 + 0.08)
		var is_outer := offset.dot(outward) > 0
		if not is_outer and not inner:
			continue
		var h := 1.4 if is_outer else 0.7
		var pos := mid + offset + b.y * h * 0.5
		U.solid_box(self, Vector3(0.16, h, dir.length()), Transform3D(b, pos), color.lightened(0.3))


func _build_bottom() -> void:
	var local := bottom_spot - global_position
	var away := Vector3(local.x, 0, local.z).normalized()
	var side := away.cross(Vector3.UP)
	var facing := Basis.looking_at(-away, Vector3.UP)

	# Go up again.
	var up_pos := local + away * 4.0 + side * 2.5
	var up_door := U.portal(self, up_pos, facing, COLORS)
	up_door.body_entered.connect(func(body: Node3D):
		if body == player:
			_go_up(), CONNECT_DEFERRED)
	var arrow := Node3D.new()
	arrow.position = up_pos + Vector3.UP * 4.3
	add_child(arrow)
	U.mesh_box(arrow, Vector3(0.35, 0.8, 0.3), Vector3(0, -0.2, 0), COLORS[3])
	for s: float in [-1.0, 1.0]:
		var wing := U.mesh_box(arrow, Vector3(0.3, 0.75, 0.3), Vector3(0.22 * s, 0.25, 0), COLORS[3])
		wing.rotation.z = 0.8 * s

	# Go home.
	var home_pos := local + away * 4.0 - side * 2.5
	var home_door := U.portal(self, home_pos, facing, COLORS)
	home_door.body_entered.connect(func(body: Node3D):
		if body == player:
			go_home.emit(), CONNECT_DEFERRED)
	var house := Node3D.new()
	house.position = home_pos + Vector3.UP * 4.2
	add_child(house)
	U.mesh_box(house, Vector3(0.8, 0.6, 0.4), Vector3.ZERO, Color.WHITE)
	var roof := U.mesh_box(house, Vector3(0.7, 0.7, 0.42), Vector3(0, 0.4, 0), COLORS[0])
	roof.rotation.z = PI * 0.25
