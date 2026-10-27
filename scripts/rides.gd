extends RefCounted
## Moving playground parts: swing seats and the merry-go-round.


## A swing seat that swings back and forth by itself under a pivot point.
class SwingSeat extends AnimatableBody3D:
	var pivot := Vector3.ZERO
	var rope_length := 2.6
	var amplitude := 0.55
	var phase := 0.0
	var _t := 0.0

	func _ready() -> void:
		sync_to_physics = true
		add_to_group("seats")
		_place()

	func _physics_process(delta: float) -> void:
		_t += delta
		_place()

	func _place() -> void:
		var omega := sqrt(9.8 / rope_length)
		var angle := amplitude * sin(_t * omega + phase)
		var b := Basis(Vector3.RIGHT, angle)
		global_transform = Transform3D(b, pivot + b * Vector3(0, -rope_length, 0))


## A round platform that keeps turning slowly.
class Spinner extends AnimatableBody3D:
	var speed := 0.6

	func _ready() -> void:
		sync_to_physics = true

	func _physics_process(delta: float) -> void:
		rotate_y(speed * delta)


## A platform that glides back and forth, slowing down at each end.
class Mover extends AnimatableBody3D:
	var start := Vector3.ZERO
	var offset := Vector3.ZERO
	var period := 6.0
	var _t := 0.0

	func _ready() -> void:
		sync_to_physics = true
		position = start

	func _physics_process(delta: float) -> void:
		_t += delta
		position = start + offset * (0.5 - 0.5 * cos(TAU * _t / period))


## A swim ring floating on water: it bobs up and down and turns slowly.
## Jump onto it and you sit inside; then the joystick paddles it around (see player.gd).
class Floater extends AnimatableBody3D:
	const RADIUS := 1.1
	const PADDLE_SPEED := 3.5
	var base := Vector3.ZERO
	## Where the ring may go (x and z, in the parent's space), so it stays in the pool.
	var bounds := Rect2(-INF, -INF, INF, INF)
	## True while the player sits in it.
	var ridden := false
	var yaw := randf() * TAU
	var _vel := Vector2.ZERO
	var _wish := Vector2.ZERO
	var _t := randf() * TAU

	func _ready() -> void:
		sync_to_physics = true
		set_meta("float", true)
		_place()

	## Called by the player each physics frame while riding. `wish` is a flat direction.
	func paddle(wish: Vector3) -> void:
		_wish = Vector2(wish.x, wish.z)

	## Jumping off pushes the ring the other way, so it does not drift after you.
	func push_off(dir: Vector3) -> void:
		_vel = -Vector2(dir.x, dir.z) * 2.0

	func _physics_process(delta: float) -> void:
		_t += delta
		if ridden:
			_vel = _vel.move_toward(_wish * PADDLE_SPEED, 5.0 * delta)
			# Turn to face where we paddle (the duck looks where it goes).
			if _vel.length() > 0.3:
				yaw = lerp_angle(yaw, atan2(-_vel.x, -_vel.y), 1.0 - exp(-5.0 * delta))
		else:
			_vel = _vel.move_toward(Vector2.ZERO, 1.5 * delta)
			yaw += 0.3 * delta
		_wish = Vector2.ZERO
		base.x += _vel.x * delta
		base.z += _vel.y * delta
		_bump_others()
		var lo := bounds.position + Vector2.ONE * RADIUS
		var hi := bounds.end - Vector2.ONE * RADIUS
		if base.x < lo.x or base.x > hi.x: _vel.x *= -0.3
		if base.z < lo.y or base.z > hi.y: _vel.y *= -0.3
		base.x = clampf(base.x, lo.x, hi.x)
		base.z = clampf(base.z, lo.y, hi.y)
		_place()

	# Rings do not go through each other: a ring we touch gets a little push.
	func _bump_others() -> void:
		for other: Node in get_parent().get_children():
			if other == self or not other is Floater:
				continue
			var d := Vector2(base.x - other.base.x, base.z - other.base.z)
			var gap := d.length()
			if gap >= RADIUS * 2.0 or gap < 0.001:
				continue
			var n := d / gap
			var overlap := RADIUS * 2.0 - gap
			base.x += n.x * overlap * 0.5
			base.z += n.y * overlap * 0.5
			other.base.x -= n.x * overlap * 0.5
			other.base.z -= n.y * overlap * 0.5
			var hit: float = (_vel - other._vel).dot(n)
			if hit < 0.0:
				_vel -= n * hit * 0.8
				other._vel += n * hit * 0.8

	# Set position and turn together. With sync_to_physics, setting them one by one
	# makes the second write undo the first.
	func _place() -> void:
		transform = Transform3D(Basis(Vector3.UP, yaw), base + Vector3.UP * sin(_t * 1.8) * 0.06)
