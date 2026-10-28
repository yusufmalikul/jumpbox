extends SceneTree
## In the indoor playground: push into each climbing wall and you end up on the floor above.
## Then ride the yellow slide down into the ball pit.
## Run: godot --headless --path . -s tests/indoor_test.gd

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
	main._enter_course("indoor")
	await _wait(5)
	var place = main._courses["indoor"]
	var player = main._player
	var ui = main._ui
	var floors := [3.0, 6.0]
	for i in place.climb_spots.size():
		player.teleport(place.global_position + place.climb_spots[i])
		player._cam_yaw = 0.0  # camera looks toward -Z, at the wall
		await _wait(10)
		ui.move_vector = Vector2(0, -1)
		await _wait(150)
		ui.move_vector = Vector2.ZERO
		await _wait(30)
		var y: float = player.global_position.y - place.global_position.y
		_check(player.is_on_floor() and absf(y - floors[i]) < 0.2, "climbed wall %d (feet at %.2f, want %.1f)" % [i + 1, y, floors[i]])
	# The slide starts at the front of the little deck left of the top floor.
	player.teleport(place.global_position + Vector3(-16.5, 6.1, -18.0))
	player._cam_yaw = 0.0
	ui.move_vector = Vector2(0, 1)  # walk toward +Z, onto the slide
	await _wait(30)
	ui.move_vector = Vector2.ZERO
	await _wait(210)
	_check(place._in_pit and player.global_position.z - place.global_position.z > -10.0, "slid down into the ball pit")
	print("RESULT: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(0 if _fails == 0 else 1)
