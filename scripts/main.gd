extends Node3D
## Builds the whole playground from code: sky, ground, rides, the player and the touch controls.
## Rainbow doors in the park lead to the jump courses. Only one place is shown at a time:
## the park, or the course you are in. Each course is built the first time you enter it.
## Run with `-- --shot=/path/to/file.png` to save a screenshot after a few seconds and quit.

const U := preload("res://scripts/util.gd")
const Rides := preload("res://scripts/rides.gd")
const PlayerScript := preload("res://scripts/player.gd")
const TouchUIScript := preload("res://scripts/touch_ui.gd")
const SoundScript := preload("res://scripts/sound.gd")
const Hats := preload("res://scripts/hats.gd")
## The jump courses: their script, where they are, and the icon over their door.
const COURSES := {
	"sky": {"script": preload("res://scripts/sky_course.gd"), "pos": Vector3(0, 40, -110), "door": Vector3(22, 0, 14)},
	"lava": {"script": preload("res://scripts/lava_course.gd"), "pos": Vector3(200, 0, 0), "door": Vector3(-22, 0, 14)},
	"slide": {"script": preload("res://scripts/slide_course.gd"), "pos": Vector3(-200, 0, 0), "door": Vector3(0, 0, 25)},
}

const SPAWN := Vector3(0, 0.1, 15)
const HALF_SIZE := 38.0

const GRASS := Color(0.42, 0.78, 0.35)
const SAND := Color(0.96, 0.86, 0.6)
const WOOD := Color(0.6, 0.4, 0.22)
const WHITE := Color(0.97, 0.97, 0.97)
const RAINBOW: Array[Color] = [
	Color(0.95, 0.3, 0.3), Color(1.0, 0.6, 0.15), Color(1.0, 0.85, 0.2), Color(0.4, 0.8, 0.3),
	Color(0.25, 0.65, 0.95), Color(0.55, 0.4, 0.9), Color(0.95, 0.45, 0.75),
]

var _clouds: Array[Node3D] = []
var _sound: Node
var _player: Node
var _ui: Node
## The park content, hidden while you are on a course.
var _park: Node3D
## Courses built so far, by name.
var _courses := {}
## The course you are on, or null in the park.
var _active: Node
var _icons: Array[Node3D] = []


func _ready() -> void:
	_sound = SoundScript.new()
	add_child(_sound)
	_build_environment()
	_park = Node3D.new()
	add_child(_park)
	_build_ground()
	_build_fence()
	_build_trampolines()
	_build_slide(Vector3(7, 0, -2), 2.6, RAINBOW[4])
	_build_slide(Vector3(15, 0, 0), 5.0, RAINBOW[0])
	_build_swings(Vector3(0, 0, -12))
	_build_merry_go_round(Vector3(9, 0, -18))
	_build_block_tower(Vector3(-11, 0, -20))
	_build_balls(Vector3(-1, 0, 1))
	_build_trees()
	_build_clouds()
	for course_name in COURSES:
		_build_door(course_name)
	_build_hat_stands()

	var player := PlayerScript.new()
	_player = player
	player.respawn_point = SPAWN
	player.sound = _sound
	player.position = SPAWN
	add_child(player)

	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := TouchUIScript.new()
	layer.add_child(ui)
	player.ui = ui
	ui.home_pressed.connect(_go_home)

	_ui = ui
	ui.stage_prev_pressed.connect(_skip_stage.bind(-1))
	ui.stage_next_pressed.connect(_skip_stage.bind(1))
	ui.music_pressed.connect(func():
		_sound.toggle_music()
		ui.music_on = _sound.music_on
		ui.queue_redraw())

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_take_screenshot(arg.trim_prefix("--shot="))


func _enter_course(course_name: String) -> void:
	if _active:
		return
	var course: Node = _courses.get(course_name)
	if course == null:
		var info: Dictionary = COURSES[course_name]
		course = info["script"].new()
		course.position = info["pos"]
		course.player = _player
		course.sound = _sound
		course.ui = _ui
		course.go_home.connect(_go_home)
		add_child(course)
		_courses[course_name] = course
	_set_park_shown(false)
	_active = course
	course.enter()


func _skip_stage(step: int) -> void:
	if _active:
		_active.skip(step)


func _go_home() -> void:
	if _active:
		_active.leave()
		_active = null
	_set_park_shown(true)
	_player.kill_y = -10.0
	_player.respawn_point = SPAWN
	_player.fall_sound = "home"
	_player.respawn()


## Hiding the park and taking it out of physics keeps the phone fast while on a course.
func _set_park_shown(shown: bool) -> void:
	_park.visible = shown
	_park.process_mode = Node.PROCESS_MODE_INHERIT if shown else Node.PROCESS_MODE_DISABLED


## Five hats on little stands in a half circle in front of the start. Walk up to one to wear it.
func _build_hat_stands() -> void:
	for i in Hats.NAMES.size():
		var hat_name := Hats.NAMES[i]
		var a := deg_to_rad(-60 + 30 * i)
		var pos := SPAWN + Vector3(sin(a) * 4.0, -0.1, -cos(a) * 4.0)
		U.solid_cylinder(_park, 0.55, 0.5, pos + Vector3(0, 0.25, 0), RAINBOW[i])
		var display := Node3D.new()
		display.position = pos + Vector3(0, 1.0, 0)
		display.scale = Vector3.ONE * 2.6
		_park.add_child(display)
		Hats.build(hat_name, display)
		_icons.append(display)
		var area := Area3D.new()
		area.position = pos + Vector3(0, 1.0, 0)
		var shape := SphereShape3D.new()
		shape.radius = 1.3
		var cs := CollisionShape3D.new()
		cs.shape = shape
		area.add_child(cs)
		_park.add_child(area)
		area.body_entered.connect(func(body: Node3D):
			if body == _player and _player.hat != hat_name:
				_player.set_hat(hat_name)
				_sound.play("sit")
				U.confetti(self, pos + Vector3(0, 1.0, 0), 30, RAINBOW), CONNECT_DEFERRED)


func _build_door(course_name: String) -> void:
	var pos: Vector3 = COURSES[course_name]["door"]
	# The doors stand away from the rides, facing the start, with a sand path leading to each.
	var to_start := Vector3(SPAWN.x - pos.x, 0, SPAWN.z - pos.z)
	var door := U.portal(_park, pos, Basis.looking_at(to_start, Vector3.UP), RAINBOW)
	var path := U.mesh_box(_park, Vector3(2.4, 0.02, to_start.length()), pos + to_start * 0.5 + Vector3.UP * 0.012, SAND)
	path.rotation.y = atan2(to_start.x, to_start.z)
	door.body_entered.connect(func(body: Node3D):
		if body == _player:
			_enter_course(course_name), CONNECT_DEFERRED)
	var icon := Node3D.new()
	icon.position = pos + Vector3(0, 4.3, 0)
	_park.add_child(icon)
	_icons.append(icon)
	if course_name == "slide":
		# A little spiral slide around a white pole.
		U.mesh_box(icon, Vector3(0.14, 1.4, 0.14), Vector3.ZERO, WHITE)
		for k in 10:
			var a := k * 0.7
			var step := U.mesh_box(icon, Vector3(0.32, 0.08, 0.2), Vector3(cos(a) * 0.32, 0.6 - k * 0.13, sin(a) * 0.32), RAINBOW[k % RAINBOW.size()])
			step.rotation.y = -a
	elif course_name == "sky":
		# A cloud.
		U.mesh_box(icon, Vector3(1.6, 0.6, 0.5), Vector3(0, 0, 0), WHITE)
		U.mesh_box(icon, Vector3(0.8, 0.6, 0.5), Vector3(-0.35, 0.4, 0), WHITE)
		U.mesh_box(icon, Vector3(0.7, 0.5, 0.5), Vector3(0.35, 0.3, 0), WHITE)
	else:
		# A flame: red outside, orange, then yellow inside.
		var flame := [[Color(0.95, 0.2, 0.1), 1.0, 0.0], [Color(1.0, 0.55, 0.1), 0.7, 0.06], [Color(1.0, 0.9, 0.3), 0.4, 0.12]]
		for f in flame:
			var b := U.mesh_box(icon, Vector3(f[1], f[1], 0.3 + f[2] * 2), Vector3(0, -0.15 + f[2], 0), f[0])
			b.rotation.z = PI * 0.25
			U.mesh_box(icon, Vector3(f[1] * 0.45, f[1] * 0.8, 0.3 + f[2] * 2), Vector3(0, 0.55 + f[2] * 0.5, 0), f[0])


func _process(delta: float) -> void:
	for icon in _icons:
		icon.rotation.y += delta * 1.2
		icon.position.y += sin(Time.get_ticks_msec() * 0.003) * delta * 0.3
	for c in _clouds:
		c.position.x += delta * 0.6
		if c.position.x > 60:
			c.position.x = -60


func _take_screenshot(path: String) -> void:
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.3, 0.58, 0.98)
	sky_mat.sky_horizon_color = Color(0.72, 0.87, 1.0)
	sky_mat.ground_horizon_color = Color(0.72, 0.87, 1.0)
	sky_mat.ground_bottom_color = Color(0.85, 0.9, 1.0)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.0
	add_child(sun)


func _build_ground() -> void:
	U.block(_park, Vector3(HALF_SIZE * 2 + 4, 1, HALF_SIZE * 2 + 4), Vector3(0, -0.5, 0), GRASS)
	# Sand patches under the play areas (looks only, no collision).
	U.mesh_box(_park, Vector3(16, 0.02, 14), Vector3(-10, 0.01, -2), SAND)
	U.mesh_box(_park, Vector3(14, 0.02, 22), Vector3(11, 0.01, -1), SAND)
	U.mesh_box(_park, Vector3(10, 0.02, 7), Vector3(0, 0.01, -12), SAND)
	# A bright start circle.
	U.mesh_cylinder(_park, 1.5, 0.03, Vector3(SPAWN.x, 0.015, SPAWN.z), Color(1, 1, 1, 0.6))


func _build_fence() -> void:
	var h := HALF_SIZE
	for side: float in [-1.0, 1.0]:
		# Tall invisible walls so nobody leaves the park, even from the big trampoline.
		var wall_x := StaticBody3D.new()
		_park.add_child(wall_x)
		U.add_box_shape(wall_x, Vector3(1, 60, h * 2 + 2), Vector3(h * side, 30, 0))
		var wall_z := StaticBody3D.new()
		_park.add_child(wall_z)
		U.add_box_shape(wall_z, Vector3(h * 2 + 2, 60, 1), Vector3(0, 30, h * side))
		# The fence you can see.
		for y: float in [0.45, 0.95]:
			U.mesh_box(_park, Vector3(0.15, 0.15, h * 2), Vector3(h * side, y, 0), WHITE)
			U.mesh_box(_park, Vector3(h * 2, 0.15, 0.15), Vector3(0, y, h * side), WHITE)
		var post := -h
		while post <= h:
			U.mesh_box(_park, Vector3(0.25, 1.3, 0.25), Vector3(h * side, 0.65, post), WHITE)
			U.mesh_box(_park, Vector3(0.25, 1.3, 0.25), Vector3(post, 0.65, h * side), WHITE)
			post += 3.0


func _build_trampoline(pos: Vector3, radius: float, power: float, color: Color) -> void:
	U.solid_cylinder(_park, radius, 0.6, pos + Vector3(0, 0.3, 0), color)
	var pad := U.solid_cylinder(_park, radius - 0.3, 0.1, pos + Vector3(0, 0.62, 0), Color(0.15, 0.15, 0.2))
	pad.set_meta("bounce", power)


func _build_trampolines() -> void:
	_build_trampoline(Vector3(-7, 0, -4), 2.0, 12.0, RAINBOW[1])
	_build_trampoline(Vector3(-12, 0, 1), 2.0, 12.0, RAINBOW[3])
	_build_trampoline(Vector3(-6, 0, 2.5), 1.6, 10.0, RAINBOW[6])
	# The super trampoline sends you really high.
	_build_trampoline(Vector3(-14, 0, -7), 3.0, 19.0, RAINBOW[5])


## A slide with stairs on the +Z side, a platform on top and the slide going down toward -Z.
func _build_slide(origin: Vector3, height: float, color: Color) -> void:
	var root := Node3D.new()
	root.position = origin
	_park.add_child(root)
	var half := 1.2
	var width := 2.0

	U.block(root, Vector3(2.4, 0.3, 2.4), Vector3(0, height - 0.15, 0), WOOD)
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			U.block(root, Vector3(0.25, height, 0.25), Vector3(x * 1.05, height * 0.5, z * 1.05), WHITE)
		# Side rails on the platform.
		U.block(root, Vector3(0.16, 0.8, 2.4), Vector3(x * 1.2, height + 0.4, 0), color)

	# Stairs: a gentle ramp with steps drawn on top.
	var stairs_len := height / tan(deg_to_rad(33))
	var bottom := Vector3(0, 0, half + stairs_len)
	var top := Vector3(0, height, half)
	U.ramp(root, bottom, top, width, WOOD)
	U.ramp_walls(root, bottom, top, width, WHITE, 0.9)
	var steps := int(height / 0.35)
	for i in steps:
		var t := (i + 0.5) / steps
		var p := bottom.lerp(top, t)
		U.mesh_box(root, Vector3(width, 0.12, stairs_len / steps * 0.6), p + Vector3(0, 0.02, 0), Color(0.75, 0.55, 0.32))

	# The slide itself.
	var slide_len := height / tan(deg_to_rad(30))
	var s_top := Vector3(0, height, -half)
	var s_bottom := Vector3(0, 0.02, -half - slide_len)
	var slide := U.ramp(root, s_top, s_bottom, width, color)
	slide.set_meta("slide", true)
	U.ramp_walls(root, s_top, s_bottom, width, color, 0.7)


func _build_swings(origin: Vector3) -> void:
	var bar_h := 3.4
	for x: float in [-3.0, 3.0]:
		for z: float in [-0.8, 0.8]:
			U.block(_park, Vector3(0.25, bar_h, 0.25), origin + Vector3(x, bar_h * 0.5, z), RAINBOW[0])
	U.block(_park, Vector3(6.4, 0.25, 0.25), origin + Vector3(0, bar_h, 0), RAINBOW[0])
	var colors := [RAINBOW[2], RAINBOW[4]]
	for i in 2:
		var seat := Rides.SwingSeat.new()
		seat.pivot = origin + Vector3(-1.4 + 2.8 * i, bar_h - 0.1, 0)
		seat.rope_length = bar_h - 0.7
		seat.phase = PI * 0.5 * i
		seat.set_meta("seat", true)
		U.mesh_box(seat, Vector3(1.3, 0.15, 0.7), Vector3.ZERO, colors[i])
		U.add_box_shape(seat, Vector3(1.3, 0.15, 0.7))
		for side: float in [-1.0, 1.0]:
			U.mesh_box(seat, Vector3(0.06, seat.rope_length, 0.06), Vector3(0.6 * side, seat.rope_length * 0.5, 0), Color(0.3, 0.3, 0.3))
		_park.add_child(seat)


func _build_merry_go_round(pos: Vector3) -> void:
	U.solid_cylinder(_park, 0.6, 0.3, pos + Vector3(0, 0.15, 0), Color(0.4, 0.4, 0.45))
	var spinner := Rides.Spinner.new()
	spinner.position = pos + Vector3(0, 0.45, 0)
	_park.add_child(spinner)
	var radius := 3.2
	U.mesh_cylinder(spinner, radius, 0.3, Vector3.ZERO, WHITE)
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 0.3
	var cs := CollisionShape3D.new()
	cs.shape = shape
	spinner.add_child(cs)
	for i in 6:
		var a := TAU * i / 6.0
		var dir := Vector3(cos(a), 0, sin(a))
		var stripe := U.mesh_box(spinner, Vector3(0.7, 0.02, radius), dir * radius * 0.5 + Vector3(0, 0.16, 0), RAINBOW[i])
		stripe.rotation.y = -a + PI * 0.5
		# Handle bars to hold on to.
		U.mesh_box(spinner, Vector3(0.12, 1.0, 0.12), dir * (radius - 0.5) + Vector3(0, 0.65, 0), RAINBOW[i])
	U.mesh_cylinder(spinner, 0.5, 1.2, Vector3(0, 0.75, 0), RAINBOW[2])
	var pole := CylinderShape3D.new()
	pole.radius = 0.5
	pole.height = 1.2
	var pole_cs := CollisionShape3D.new()
	pole_cs.shape = pole
	pole_cs.position.y = 0.75
	spinner.add_child(pole_cs)


## Rainbow blocks that climb in a spiral around a tall tower with a flag on top.
func _build_block_tower(center: Vector3) -> void:
	var steps := 9
	var step_h := 0.7
	var top_h := step_h * steps
	U.block(_park, Vector3(2.6, top_h, 2.6), center + Vector3(0, top_h * 0.5, 0), WHITE)
	for i in steps:
		var h := step_h * (i + 1)
		var a := TAU * i / 8.5
		var p := center + Vector3(cos(a) * 2.5, h * 0.5, sin(a) * 2.5)
		var b := U.block(_park, Vector3(1.4, h, 1.4), p, RAINBOW[i % RAINBOW.size()])
		b.rotation.y = -a
	U.mesh_box(_park, Vector3(0.1, 2.0, 0.1), center + Vector3(0, top_h + 1.0, 0), Color(0.3, 0.3, 0.3))
	U.mesh_box(_park, Vector3(0.9, 0.55, 0.05), center + Vector3(0.45, top_h + 1.7, 0), RAINBOW[0])
	# Reaching the top plays a fanfare.
	var goal := Area3D.new()
	goal.position = center + Vector3(0, top_h + 0.8, 0)
	U.add_box_shape(goal, Vector3(2.6, 1.6, 2.6))
	_park.add_child(goal)
	goal.body_entered.connect(func(body: Node3D):
		if body is CharacterBody3D:
			_sound.play("fanfare"))


func _build_balls(center: Vector3) -> void:
	var bouncy := PhysicsMaterial.new()
	bouncy.bounce = 0.6
	bouncy.friction = 0.6
	for i in 7:
		var ball := RigidBody3D.new()
		ball.mass = 0.4
		ball.physics_material_override = bouncy
		ball.linear_damp = 0.3
		ball.angular_damp = 0.5
		var a := TAU * i / 7.0
		ball.position = center + Vector3(cos(a) * 2.5, 0.7 + i * 0.2, sin(a) * 2.5)
		var shape := SphereShape3D.new()
		shape.radius = 0.6
		var cs := CollisionShape3D.new()
		cs.shape = shape
		ball.add_child(cs)
		var mesh := SphereMesh.new()
		mesh.radius = 0.6
		mesh.height = 1.2
		mesh.radial_segments = 16
		mesh.rings = 8
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = U.mat(RAINBOW[i])
		ball.add_child(mi)
		_park.add_child(ball)


func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var placed := 0
	while placed < 26:
		var p := Vector3(rng.randf_range(-34, 34), 0, rng.randf_range(-34, 34))
		# Keep trees near the edges, away from the rides.
		if absf(p.x) < 25 and absf(p.z) < 26:
			continue
		var trunk_h := rng.randf_range(1.6, 2.6)
		U.block(_park, Vector3(0.6, trunk_h, 0.6), p + Vector3(0, trunk_h * 0.5, 0), WOOD)
		var green := Color(0.2, rng.randf_range(0.5, 0.7), 0.25)
		U.mesh_box(_park, Vector3(2.6, 1.6, 2.6), p + Vector3(0, trunk_h + 0.7, 0), green)
		U.mesh_box(_park, Vector3(1.7, 1.1, 1.7), p + Vector3(0, trunk_h + 1.9, 0), green.lightened(0.15))
		placed += 1


func _build_clouds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 7:
		var cloud := Node3D.new()
		cloud.position = Vector3(rng.randf_range(-60, 60), rng.randf_range(22, 30), rng.randf_range(-50, 30))
		_park.add_child(cloud)
		for j in 3:
			U.mesh_box(cloud, Vector3(rng.randf_range(4, 7), 1.6, rng.randf_range(3, 4)), Vector3(j * 2.5 - 2.5, rng.randf_range(0, 0.8), 0), WHITE)
		_clouds.append(cloud)
