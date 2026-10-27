extends Control
## On-screen controls: a joystick on the left, a big jump button on the right,
## and drag anywhere else to turn the camera. A home button sends you back to the start.

signal home_pressed
signal music_pressed
signal stage_prev_pressed
signal stage_next_pressed

const JOY_RADIUS := 120.0
const KNOB_RADIUS := 52.0
const JUMP_RADIUS := 100.0
const HOME_RADIUS := 48.0
const STAGE_ARROW_RADIUS := 40.0

var move_vector := Vector2.ZERO
var jump_down := false
## Only used to draw the music button; main.gd keeps it in sync.
var music_on := true
## The stage number at the top, shown only on the sky course.
var show_stage := false
var stage := 0

var _joy_touch := -1
var _joy_center := Vector2.ZERO
var _joy_knob := Vector2.ZERO
var _jump_touch := -1
var _look_touch := -1
var _look_last := Vector2.ZERO
var _look_accum := Vector2.ZERO


func _ready() -> void:
	resized.connect(queue_redraw)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func consume_look() -> Vector2:
	var v := _look_accum
	_look_accum = Vector2.ZERO
	return v


func _joy_home() -> Vector2:
	return Vector2(200, size.y - 190)


func _jump_center() -> Vector2:
	return Vector2(size.x - 180, size.y - 180)


func _home_center() -> Vector2:
	return Vector2(80, 80)


func _music_center() -> Vector2:
	return Vector2(size.x - 80, 80)


func _stage_center() -> Vector2:
	return Vector2(size.x * 0.5, 70)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
		queue_redraw()
	elif event is InputEventScreenDrag:
		_on_drag(event)


func _on_touch(event: InputEventScreenTouch) -> void:
	var p := event.position
	if event.pressed:
		# Each button reacts only inside the circle you can see. Touches next to a
		# button are for turning the camera.
		if p.distance_to(_home_center()) < HOME_RADIUS:
			home_pressed.emit()
		elif p.distance_to(_music_center()) < HOME_RADIUS:
			music_pressed.emit()
		elif show_stage and p.distance_to(_stage_center() + Vector2(-130, 0)) < STAGE_ARROW_RADIUS:
			stage_prev_pressed.emit()
		elif show_stage and p.distance_to(_stage_center() + Vector2(130, 0)) < STAGE_ARROW_RADIUS:
			stage_next_pressed.emit()
		elif _jump_touch == -1 and p.distance_to(_jump_center()) < JUMP_RADIUS:
			_jump_touch = event.index
			jump_down = true
		elif _joy_touch == -1 and p.x < size.x * 0.45:
			# The joystick appears wherever the finger lands on the left side.
			_joy_touch = event.index
			_joy_center = p
			_joy_knob = p
			move_vector = Vector2.ZERO
		elif _look_touch == -1:
			_look_touch = event.index
			_look_last = p
	elif event.index == _joy_touch:
		_joy_touch = -1
		move_vector = Vector2.ZERO
	elif event.index == _jump_touch:
		_jump_touch = -1
		jump_down = false
	elif event.index == _look_touch:
		_look_touch = -1


func _on_drag(event: InputEventScreenDrag) -> void:
	if event.index == _joy_touch:
		var offset := (event.position - _joy_center).limit_length(JOY_RADIUS)
		_joy_knob = _joy_center + offset
		move_vector = offset / JOY_RADIUS
		if move_vector.length() < 0.15:
			move_vector = Vector2.ZERO
		queue_redraw()
	elif event.index == _look_touch:
		_look_accum += event.position - _look_last
		_look_last = event.position


func _draw() -> void:
	var center := _joy_center if _joy_touch != -1 else _joy_home()
	var knob := _joy_knob if _joy_touch != -1 else center
	draw_circle(center, JOY_RADIUS, Color(1, 1, 1, 0.15))
	draw_arc(center, JOY_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.5), 5, true)
	draw_circle(knob, KNOB_RADIUS, Color(1, 1, 1, 0.65))

	var jc := _jump_center()
	draw_circle(jc, JUMP_RADIUS, Color(1, 0.72, 0.1, 0.9 if jump_down else 0.65))
	draw_arc(jc, JUMP_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.8), 5, true)
	var arrow := PackedVector2Array([
		jc + Vector2(0, -50), jc + Vector2(42, 0), jc + Vector2(16, 0),
		jc + Vector2(16, 40), jc + Vector2(-16, 40), jc + Vector2(-16, 0), jc + Vector2(-42, 0),
	])
	draw_colored_polygon(arrow, Color.WHITE)

	var hc := _home_center()
	draw_circle(hc, HOME_RADIUS, Color(0.3, 0.75, 1.0, 0.7))
	draw_colored_polygon(PackedVector2Array([hc + Vector2(0, -26), hc + Vector2(26, -2), hc + Vector2(-26, -2)]), Color.WHITE)
	draw_rect(Rect2(hc + Vector2(-17, -4), Vector2(34, 26)), Color.WHITE)

	# Music button: a musical note, crossed out when the music is off.
	var mc := _music_center()
	draw_circle(mc, HOME_RADIUS, Color(0.95, 0.45, 0.75, 0.7))
	draw_circle(mc + Vector2(-8, 14), 10, Color.WHITE)
	draw_line(mc + Vector2(1, 14), mc + Vector2(1, -22), Color.WHITE, 5)
	draw_line(mc + Vector2(1, -20), mc + Vector2(16, -10), Color.WHITE, 5)
	if not music_on:
		draw_line(mc + Vector2(-26, -26), mc + Vector2(26, 26), Color(0.9, 0.1, 0.1), 7)

	# Version number, small at the bottom, so we know which build is installed.
	var version := "v" + str(ProjectSettings.get_setting("application/config/version", "?"))
	draw_string(ThemeDB.fallback_font, Vector2(0, size.y - 14), version, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(1, 1, 1, 0.75))

	if show_stage:
		var sc := _stage_center()
		draw_circle(sc, 56, Color(1, 1, 1, 0.85))
		var font := ThemeDB.fallback_font
		var text := str(stage) if stage > 0 else "★"
		draw_string(font, sc + Vector2(-60, 26), text, HORIZONTAL_ALIGNMENT_CENTER, 120, 72, Color(0.2, 0.2, 0.3))
		for dir: float in [-1.0, 1.0]:
			var c := sc + Vector2(130 * dir, 0)
			draw_circle(c, STAGE_ARROW_RADIUS, Color(0.3, 0.75, 1.0, 0.75))
			draw_colored_polygon(PackedVector2Array([c + Vector2(18 * dir, 0), c + Vector2(-12 * dir, -20), c + Vector2(-12 * dir, 20)]), Color.WHITE)
