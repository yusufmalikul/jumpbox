extends SceneTree
## Walk up to a swing seat: you sit on it without jumping, with your hips on the seat
## (not floating above it). Jump gets you off, and you do not sit right back down.
## Run: godot --headless --path . -s tests/swing_test.gd

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
	var player = main._player
	var ui = main._ui
	var seat: Node3D = get_nodes_in_group("seats")[0]
	# Stand on the ground in front of the seat and walk toward it.
	var start: Vector3 = seat.global_position + Vector3(0, 0, -2.5)
	player.teleport(Vector3(start.x, 0.1, start.z))
	player.look_toward(Vector3.BACK)
	await _wait(10)
	ui.move_vector = Vector2(0, -1)
	for i in 120:
		await physics_frame
		if player._seat != null:
			break
	ui.move_vector = Vector2.ZERO
	_check(player._seat == seat, "sat down just by walking to the seat")
	await _wait(5)
	# The hips (top of the legs, 0.75 above the feet) should rest on the seat top.
	var hips: Vector3 = player.global_position + seat.global_basis.y * 0.75
	var seat_top: Vector3 = seat.global_position + seat.global_basis.y * 0.075
	var gap: float = hips.distance_to(seat_top)
	_check(gap < 0.12, "hips on the seat (gap %.2f m)" % gap)
	ui.jump_down = true
	await _wait(2)
	_check(player._seat == null, "jump got off the seat")
	await _wait(60)
	ui.jump_down = false
	await _wait(60)
	_check(player._seat == null, "did not sit right back down")
	print("RESULT: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(0 if _fails == 0 else 1)
