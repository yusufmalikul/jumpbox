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
class Floater extends AnimatableBody3D:
	var base := Vector3.ZERO
	var _t := randf() * TAU

	func _ready() -> void:
		sync_to_physics = true
		_place()

	func _physics_process(delta: float) -> void:
		_t += delta
		_place()

	# Set position and turn together. With sync_to_physics, setting them one by one
	# makes the second write undo the first.
	func _place() -> void:
		transform = Transform3D(Basis(Vector3.UP, _t * 0.3), base + Vector3.UP * sin(_t * 1.8) * 0.06)
