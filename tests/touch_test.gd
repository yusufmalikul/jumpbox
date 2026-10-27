extends SceneTree
## Touches near, but outside, the yellow jump button should turn the camera, not jump.
## Run: godot --headless --path . -s tests/touch_test.gd
func _touch(ui, pos: Vector2, pressed: bool, index := 0) -> void:
	var e := InputEventScreenTouch.new()
	e.position = pos
	e.pressed = pressed
	e.index = index
	ui._input(e)

func _drag(ui, pos: Vector2, rel: Vector2, index := 0) -> void:
	var e := InputEventScreenDrag.new()
	e.position = pos
	e.relative = rel
	e.index = index
	ui._input(e)

func _initialize():
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var ui = main._ui
	var jc: Vector2 = ui._jump_center()
	var r: float = ui.JUMP_RADIUS
	var fails := 0
	# Points just outside the visible circle, in several directions.
	for angle in [0.0, 0.8, 1.6, 2.4, 3.2, 4.0, 4.8]:
		var p: Vector2 = jc + Vector2.from_angle(angle) * (r + 15)
		_touch(ui, p, true)
		_drag(ui, p + Vector2(40, 0), Vector2(40, 0))
		var look: Vector2 = ui.consume_look()
		var ok: bool = not ui.jump_down and look.x != 0
		if not ok: fails += 1
		print("touch %d px outside, angle %.1f: jump=%s camera turned=%s %s" % [15, angle, ui.jump_down, look.x != 0, "OK" if ok else "FAIL"])
		_touch(ui, p, false)
	# Inside the circle must still jump.
	_touch(ui, jc + Vector2(r - 10, 0), true)
	var inside_ok: bool = ui.jump_down
	if not inside_ok: fails += 1
	print("touch inside the circle: jump=%s %s" % [ui.jump_down, "OK" if inside_ok else "FAIL"])
	_touch(ui, jc, false)
	print("RESULT: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(0 if fails == 0 else 1)
