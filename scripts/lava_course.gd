extends "res://scripts/course.gd"
## Hop across stones over a sea of lava, up to a trophy on top of a volcano.
## Touch the lava and you come back at the last checkpoint. Stones are wide and close.

const LAVA_Y := -0.6

var _lava_mat: StandardMaterial3D
var _t := 0.0


func _init() -> void:
	kill_depth = 0.9  # a little way into the lava
	fall_sound = "lava"
	pad_color = Color(0.8, 0.78, 0.74)
	palette = [
		Color(0.45, 0.42, 0.4), Color(0.55, 0.45, 0.38), Color(0.4, 0.4, 0.46),
		Color(0.5, 0.48, 0.42), Color(0.47, 0.4, 0.44),
	]


func _layout() -> void:
	_stage(1)  # flat stones
	for i in 4:
		_plat(W, D, GAP, 0.0)
	_checkpoint()

	_stage(2)  # zig-zag
	for i in 5:
		_plat(W, D, GAP, 0.0, 1.2 if i % 2 == 0 else -1.2)
	_checkpoint()

	_turn(-90)
	_stage(3)  # round stones
	for i in 6:
		_stone(2.2, GAP, 0.0, 0.8 if i % 3 == 1 else (-0.8 if i % 3 == 2 else 0.0))
	_checkpoint()

	_stage(4)  # a slow raft across the lava
	_mover(5.0)
	_plat(W, D, 0.3, 0.0)
	_checkpoint()

	_stage(5)  # a bridge of planks with small gaps
	for i in 6:
		_plat(W, 1.8, 0.6, 0.0)
	_checkpoint()

	_turn(90)
	_stage(6)  # platforms sliding side to side
	_plat(W, D, GAP, 0.0)
	_side_mover(1.8)
	_side_mover(1.8)
	_plat(W, D, GAP, 0.0)
	_checkpoint()

	_stage(7)  # up and down
	for i in 6:
		_plat(W, D, GAP, 0.5 if i % 2 == 0 else -0.3)
	_checkpoint()

	_turn(-90)
	_stage(8)  # a curve of round stones
	for i in 7:
		_turn(20)
		_stone(2.2, GAP, 0.2, 0.0)
	_checkpoint()

	_stage(9)  # a trampoline over the lava
	_plat(W, D, GAP, 0.0)
	_bouncer(GAP)
	_plat(W + 1.0, W, 0.6, 2.5)
	_checkpoint()

	_stage(10)  # up the volcano
	for i in 8:
		_plat(W + 2.0, 1.4, 0.0, 0.5)
	_checkpoint(true)


func _build_floor() -> void:
	var box := _bounds(30)
	_lava_mat = StandardMaterial3D.new()
	_lava_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lava_mat.albedo_color = Color(1.0, 0.38, 0.05)
	var sea := PlaneMesh.new()
	sea.size = Vector2(box.size.x + 300, box.size.z + 300)
	var sea_mi := MeshInstance3D.new()
	sea_mi.mesh = sea
	sea_mi.material_override = _lava_mat
	sea_mi.position = Vector3(box.get_center().x, LAVA_Y, box.get_center().z)
	add_child(sea_mi)

	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var glow := Color(1.0, 0.8, 0.2)
	glow.a = 0.99  # see-through material is unshaded, so the spots glow
	for i in 60:
		var p := Vector3(rng.randf_range(box.position.x, box.end.x), LAVA_Y + 0.01, rng.randf_range(box.position.z, box.end.z))
		U.mesh_cylinder(self, rng.randf_range(0.3, 1.2), 0.02, p, glow)
	# Dark rocks around the edge, for scenery.
	for i in 30:
		var a := TAU * i / 30.0
		var r := maxf(box.size.x, box.size.z) * 0.5 + rng.randf_range(10, 25)
		var p := Vector3(box.get_center().x + cos(a) * r, LAVA_Y, box.get_center().z + sin(a) * r)
		var h := rng.randf_range(3, 10)
		U.mesh_box(self, Vector3(rng.randf_range(4, 9), h, rng.randf_range(4, 9)), p + Vector3.UP * h * 0.5, Color(0.25, 0.22, 0.22))


func _process(delta: float) -> void:
	if _lava_mat:
		_t += delta
		_lava_mat.albedo_color = Color(1.0, 0.36 + 0.06 * sin(_t * 1.5), 0.05)
