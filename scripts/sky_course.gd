extends "res://scripts/course.gd"
## Easy jumps high above the clouds, up to a golden trophy. Fall into the clouds and you
## come back at the last checkpoint.


func _layout() -> void:
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


func _build_floor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var box := _bounds(25)
	# A sea of clouds. A plane only shows its top side, so it never covers the sky from below.
	var sea := PlaneMesh.new()
	sea.size = Vector2(box.size.x + 300, box.size.z + 300)
	var sea_mi := MeshInstance3D.new()
	sea_mi.mesh = sea
	sea_mi.material_override = U.mat(Color(0.9, 0.94, 1.0))
	sea_mi.position = Vector3(box.get_center().x, -13, box.get_center().z)
	add_child(sea_mi)
	for i in 50:
		var p := Vector3(rng.randf_range(box.position.x, box.end.x), rng.randf_range(-14, -11), rng.randf_range(box.position.z, box.end.z))
		U.mesh_box(self, Vector3(rng.randf_range(8, 16), rng.randf_range(1.5, 3), rng.randf_range(6, 12)), p, Color(1, 1, 1))
