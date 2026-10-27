extends "res://scripts/place.gd"
## A water park: a big shallow pool, a tower with two curvy water slides that end with a
## splash, water jets that throw you up, and floating rings to hop across.
## The water is waist deep, so nobody can sink. Walking in water is a little slower.

const Rides := preload("res://scripts/rides.gd")

const HALF := 56.0
## The pool: x from -POOL_X to POOL_X, z from POOL_Z0 to POOL_Z1.
const POOL_X := 14.0
const POOL_Z0 := -18.0
const POOL_Z1 := 6.0
const POOL_FLOOR := -1.0
const WATER_Y := -0.25
const TOWER := Vector3(0, 10, -45)
const DECK := Color(0.9, 0.78, 0.6)
const WATER := Color(0.3, 0.7, 1.0, 0.55)

var spawn := Vector3(0, 0.1, 16)
## Where each water slide starts and ends (for tests).
var slide_paths: Array = []


func _ready() -> void:
	_build_ground()
	_build_pool()
	_build_tower()
	_build_water_slide(-1.0, COLORS[4])
	_build_water_slide(1.0, COLORS[1])
	for p in [Vector3(-8, 0, -10), Vector3(8, 0, -10), Vector3(0, 0, -2)]:
		_build_jet(p)
	for i in 5:
		_build_ring(Vector3(-10 + i * 5, 0, 1 + (i % 2) * 2), COLORS[i])
	_build_decor()
	_home_door(Vector3(0, 0, 24), Basis.looking_at(Vector3.FORWARD, Vector3.UP))
	_edge_walls(HALF)


func _arrive() -> void:
	player.kill_y = global_position.y - 10.0
	player.fall_sound = "home"
	player.respawn_point = global_position + spawn
	player.teleport(global_position + spawn)
	player.look_toward(Vector3.FORWARD)
	sound.play("home")


func leave() -> void:
	super()
	player.move_scale = 1.0


# ---------- building ----------

## The deck around the pool is four blocks, leaving a hole for the pool.
func _build_ground() -> void:
	var h := 2.0
	var y := -h * 0.5
	var w := HALF * 2
	U.block(self, Vector3(HALF - POOL_X, h, w), Vector3(-(HALF + POOL_X) * 0.5, y, 0), DECK)
	U.block(self, Vector3(HALF - POOL_X, h, w), Vector3((HALF + POOL_X) * 0.5, y, 0), DECK)
	U.block(self, Vector3(POOL_X * 2, h, HALF - POOL_Z1), Vector3(0, y, (HALF + POOL_Z1) * 0.5), DECK)
	U.block(self, Vector3(POOL_X * 2, h, HALF + POOL_Z0), Vector3(0, y, (POOL_Z0 - HALF) * 0.5), DECK)
	# Grass outside the deck, for looks.
	U.mesh_box(self, Vector3(300, 0.5, 300), Vector3(0, -2.3, 0), Color(0.42, 0.78, 0.35))


func _build_pool() -> void:
	var size := Vector3(POOL_X * 2, 0.5, POOL_Z1 - POOL_Z0)
	var center := Vector3(0, POOL_FLOOR - 0.25, (POOL_Z0 + POOL_Z1) * 0.5)
	U.block(self, size, center, Color(0.55, 0.8, 0.95))
	# Tile lines on the pool floor.
	for i in range(1, 7):
		U.mesh_box(self, Vector3(0.08, 0.02, size.z), Vector3(-POOL_X + i * 4, POOL_FLOOR + 0.01, center.z), Color(0.4, 0.65, 0.9))

	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size.x, size.z)
	water.mesh = plane
	water.material_override = U.mat(WATER)
	water.position = Vector3(0, WATER_Y, center.z)
	add_child(water)

	# Gentle steps down into the pool at the front.
	U.ramp(self, Vector3(0, 0, POOL_Z1 - 0.01), Vector3(0, POOL_FLOOR, POOL_Z1 - 3.5), 5.0, Color(0.85, 0.92, 1.0))

	# The water itself: a splash when you jump in, and slower walking while you are in.
	var area := Area3D.new()
	U.add_box_shape(area, Vector3(size.x, 1.2, size.z), Vector3(0, POOL_FLOOR + 0.6, center.z))
	add_child(area)
	area.body_entered.connect(func(body: Node3D):
		if body == player:
			player.move_scale = 0.65
			# Splash when you jump in, or come in fast off a slide.
			if body.velocity.y < -3.0 or body.velocity.length() > 6.0:
				_splash(body.global_position, 40)
				sound.play("splash"), CONNECT_DEFERRED)
	area.body_exited.connect(func(body: Node3D):
		if body == player:
			player.move_scale = 1.0, CONNECT_DEFERRED)


## A tower with a platform on top and stairs up the right side.
func _build_tower() -> void:
	var top := TOWER.y
	U.block(self, Vector3(6, 0.4, 6), TOWER + Vector3.DOWN * 0.2, Color(0.95, 0.95, 1.0))
	for x: float in [-2.7, 2.7]:
		for z: float in [-2.7, 2.7]:
			U.block(self, Vector3(0.4, top, 0.4), Vector3(TOWER.x + x, top * 0.5, TOWER.z + z), COLORS[4])
	# Rails on the back and sides; the front is open for the slides.
	U.block(self, Vector3(6, 1.0, 0.2), TOWER + Vector3(0, 0.5, -3.0), Color.WHITE)
	U.block(self, Vector3(0.2, 1.0, 6), TOWER + Vector3(-3.0, 0.5, 0), Color.WHITE)
	U.block(self, Vector3(0.2, 1.0, 3.6), TOWER + Vector3(3.0, 0.5, -1.2), Color.WHITE)
	# A striped roof, like a sun shade.
	for i in 6:
		U.mesh_box(self, Vector3(1.0, 0.15, 6.4), TOWER + Vector3(-2.5 + i, 3.6, 0), COLORS[0] if i % 2 == 0 else Color.WHITE)
	for x: float in [-2.7, 2.7]:
		for z: float in [-2.7, 2.7]:
			U.mesh_box(self, Vector3(0.15, 3.6, 0.15), TOWER + Vector3(x, 1.8, z), Color.WHITE)
	# Stairs: a ramp from the deck up to the right side of the platform, toward the back.
	var stairs_top := TOWER + Vector3(3.0, 0, 1.8)
	var stairs_bottom := Vector3(20.0, 0, stairs_top.z)
	U.ramp(self, stairs_bottom, stairs_top, 2.4, Color(0.75, 0.55, 0.32))
	U.ramp_walls(self, stairs_bottom, stairs_top, 2.4, Color.WHITE, 0.9)
	var steps := 22
	for i in steps:
		var p := stairs_bottom.lerp(stairs_top, (i + 0.5) / steps)
		U.mesh_box(self, Vector3(0.4, 0.1, 2.4), p + Vector3(0, 0.03, 0), Color(0.85, 0.65, 0.4))


## A curvy slide from the front of the tower down into the pool.
## side = -1 for the left slide, 1 for the right one.
func _build_water_slide(side: float, color: Color) -> void:
	var z0 := TOWER.z + 3.0
	var z1 := POOL_Z0 + 3.0
	var count := 48
	var points: Array[Vector3] = []
	for i in count + 1:
		var t := float(i) / count
		var x := side * (1.3 + 3.5 * sin(PI * t) + 3.0 * t + 1.3 * sin(3.0 * PI * t))
		var y := TOWER.y * (1.0 - t) + (WATER_Y + 0.6) * t
		points.append(Vector3(x, y, lerpf(z0, z1, t)))
	U.slide_path(self, points, 2.2, color, 1.0)
	slide_paths.append(points)


## A water jet in the pool. Step in and it throws you up into the air.
func _build_jet(pos: Vector3) -> void:
	var base := Vector3(pos.x, POOL_FLOOR, pos.z)
	U.mesh_cylinder(self, 0.9, 0.06, base + Vector3.UP * 0.03, Color(0.85, 0.85, 0.9))
	U.mesh_cylinder(self, 0.5, 0.08, base + Vector3.UP * 0.05, Color(0.4, 0.4, 0.45))

	var spray := CPUParticles3D.new()
	var drop := BoxMesh.new()
	drop.size = Vector3(0.12, 0.25, 0.12)
	drop.material = U.mat(Color(0.8, 0.95, 1.0, 0.8))
	spray.mesh = drop
	spray.amount = 40
	spray.lifetime = 0.9
	spray.direction = Vector3.UP
	spray.spread = 6
	spray.initial_velocity_min = 7
	spray.initial_velocity_max = 9
	spray.gravity = Vector3(0, -9.8, 0)
	spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	spray.emission_sphere_radius = 0.25
	spray.position = base + Vector3.UP * 0.1
	add_child(spray)

	var area := Area3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.8
	shape.height = 1.6
	var cs := CollisionShape3D.new()
	cs.shape = shape
	area.add_child(cs)
	area.position = base + Vector3.UP * 0.8
	add_child(area)
	area.body_entered.connect(func(body: Node3D):
		if body == player:
			player.launch(11.0)
			_splash(base + Vector3.UP * 0.8, 25)
			sound.play("splash"), CONNECT_DEFERRED)


## A swim ring that bobs on the water. You can stand on it.
func _build_ring(pos: Vector3, color: Color) -> void:
	var ring := Rides.Floater.new()
	ring.base = Vector3(pos.x, WATER_Y - 0.05, pos.z)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 1.1
	torus.rings = 16
	torus.ring_segments = 8
	var mi := MeshInstance3D.new()
	mi.mesh = torus
	mi.material_override = U.mat(color)
	ring.add_child(mi)
	# White stripes on the ring.
	for k in 4:
		var a := TAU * k / 4.0
		var stripe := U.mesh_box(ring, Vector3(0.18, 0.3, 0.6), Vector3(cos(a) * 0.82, 0, sin(a) * 0.82), Color.WHITE)
		stripe.rotation.y = -a
	var shape := CylinderShape3D.new()
	shape.radius = 1.1
	shape.height = 0.5
	var cs := CollisionShape3D.new()
	cs.shape = shape
	ring.add_child(cs)
	add_child(ring)


func _build_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	# Palm trees around the deck.
	var palms := [Vector3(-20, 0, -8), Vector3(-22, 0, 8), Vector3(20, 0, -25), Vector3(22, 0, 8),
		Vector3(-18, 0, -30), Vector3(-26, 0, -20), Vector3(26, 0, -6), Vector3(-10, 0, 20), Vector3(12, 0, 22)]
	for p: Vector3 in palms:
		_palm(p, rng)
	# Beach umbrellas with a lounge chair under each.
	var spots := [Vector3(-18, 0, 2), Vector3(18, 0, -2), Vector3(-17, 0, -14), Vector3(8, 0, 12)]
	for i in spots.size():
		var p: Vector3 = spots[i]
		U.mesh_box(self, Vector3(0.12, 2.6, 0.12), p + Vector3.UP * 1.3, Color.WHITE)
		for k in 8:
			var a := TAU * k / 8.0
			var slice := U.mesh_box(self, Vector3(0.9, 0.12, 1.6), p + Vector3(cos(a) * 0.7, 2.55, sin(a) * 0.7), COLORS[i] if k % 2 == 0 else Color.WHITE)
			slice.rotation.y = -a + PI * 0.5
		U.block(self, Vector3(0.9, 0.3, 2.0), p + Vector3(1.2, 0.15, 0), COLORS[(i + 3) % COLORS.size()])


func _palm(p: Vector3, rng: RandomNumberGenerator) -> void:
	var lean := rng.randf_range(-0.25, 0.25)
	var top := p
	for k in 6:
		var piece := U.mesh_box(self, Vector3(0.45, 1.0, 0.45), top + Vector3(lean * k * 0.3, 0.5, 0), Color(0.6, 0.42, 0.25))
		piece.rotation.z = -lean
		top += Vector3(lean * 0.3, 1.0, 0)
	top += Vector3(lean * 1.5, 0.2, 0)
	for k in 6:
		var a := TAU * k / 6.0
		var leaf := U.mesh_box(self, Vector3(2.4, 0.1, 0.6), top + Vector3(cos(a) * 1.1, -0.3, sin(a) * 1.1), Color(0.2, 0.65, 0.3))
		leaf.rotation = Vector3(0, -a, -0.35)
	U.mesh_box(self, Vector3(0.35, 0.35, 0.35), top + Vector3(0.2, -0.45, 0.1), Color(0.45, 0.3, 0.15))
	var trunk := StaticBody3D.new()
	trunk.position = p
	add_child(trunk)
	U.add_box_shape(trunk, Vector3(0.5, 6, 0.5), Vector3(0, 3, 0))


func _splash(pos: Vector3, amount: int) -> void:
	var c := CPUParticles3D.new()
	var drop := BoxMesh.new()
	drop.size = Vector3(0.14, 0.14, 0.14)
	drop.material = U.mat(Color(0.85, 0.95, 1.0, 0.85))
	c.mesh = drop
	c.amount = amount
	c.lifetime = 1.0
	c.one_shot = true
	c.explosiveness = 1.0
	c.direction = Vector3.UP
	c.spread = 45
	c.initial_velocity_min = 3
	c.initial_velocity_max = 6
	c.gravity = Vector3(0, -12, 0)
	c.top_level = true
	add_child(c)
	c.global_position = Vector3(pos.x, global_position.y + WATER_Y + 0.1, pos.z)
	c.emitting = true
	get_tree().create_timer(1.5).timeout.connect(c.queue_free)
