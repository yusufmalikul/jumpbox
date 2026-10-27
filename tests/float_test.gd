extends SceneTree
## In the water park: land on a duck float to sit in it, paddle it, then jump to get out.
## Run: godot --headless --path . -s tests/float_test.gd

var _fails := 0

func _check(ok: bool, what: String) -> void:
	if not ok: _fails += 1
	print("%s: %s" % [what, "OK" if ok else "FAIL"])

func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame

func _initialize():
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._enter_course("water")
	await _wait(5)
	var water = main._courses["water"]
	var player = main._player
	var duck: Node3D = water.floaters[water.floaters.size() - 1]
	var ui = main._ui
	# Drop onto the duck from above.
	player.teleport(duck.global_position + Vector3.UP * 2.0)
	await _wait(60)
	_check(player._float == duck, "landed on the duck and sat in it")
	var start: Vector3 = duck.global_position
	ui.move_vector = Vector2(0, -1)
	await _wait(60)
	ui.move_vector = Vector2.ZERO
	_check(duck.global_position.distance_to(start) > 1.0, "paddled the duck (moved %.1f m)" % duck.global_position.distance_to(start))
	_check(player.global_position.distance_to(duck.global_position) < 1.0, "player moved with the duck")
	ui.jump_down = true
	await _wait(2)
	ui.jump_down = false
	_check(player._float == null and not duck.ridden, "jump got out of the duck")
	await _wait(90)
	_check(player._float == null, "did not fall right back in")
	print("RESULT: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(0 if _fails == 0 else 1)
