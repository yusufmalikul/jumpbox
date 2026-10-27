extends CharacterBody3D
## The blocky kid you play as. Walks, jumps, bounces on trampolines and slides down slides.
## It also owns the follow camera.

const U := preload("res://scripts/util.gd")
const Hats := preload("res://scripts/hats.gd")
const SETTINGS_PATH := "user://settings.cfg"

const WALK_SPEED := 6.0
const JUMP_SPEED := 8.0
const GRAVITY := 22.0
const SLIDE_ACCEL := 16.0
const SLIDE_MAX_SPEED := 13.0
const COYOTE_TIME := 0.15
const CAM_DISTANCE := 7.0

const SKIN := Color(1.0, 0.8, 0.25)
const SHIRT := Color(0.95, 0.3, 0.3)
const PANTS := Color(0.2, 0.45, 0.9)

## The touch UI (touch_ui.gd). Set by main.gd.
var ui: Node
## The sound player (sound.gd). Set by main.gd.
var sound: Node
## Where you come back after falling or pressing home. The sky course moves it to its checkpoints.
var respawn_point := Vector3.ZERO
## Falling below this height sends you back to respawn_point.
var kill_y := -10.0
## Walking speed is multiplied by this (the water park makes it slower in the pool).
var move_scale := 1.0
## The sound for falling below kill_y.
var fall_sound := "home"

var _model: Node3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _hat_root: Node3D
## The hat being worn ("" for none). Saved, so it stays on next time.
var hat := ""
var _walk_time := 0.0
var _squash := 0.0
var _air_time := 0.0
## What is right under our feet (from the shadow ray). Used to know if we are on a slide.
var _floor_obj: Object
## The swing seat we sit on, if any.
var _seat: Node3D
var _seat_cooldown := 0.0
var _was_on_slide := false
var _kick_cooldown := 0.0

var _cam_yaw := 0.0
var _cam_pitch := -0.3
var _cam_rig: Node3D
var _cam_pitch_node: Node3D
var _shadow: MeshInstance3D


func _ready() -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.7
	var cs := CollisionShape3D.new()
	cs.shape = capsule
	cs.position.y = 0.85
	add_child(cs)
	floor_max_angle = deg_to_rad(50)
	floor_snap_length = 0.3
	_build_model()
	_build_camera()
	_build_shadow()
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		set_hat(cfg.get_value("player", "hat", ""), false)


func set_hat(hat_name: String, save := true) -> void:
	if hat_name == hat:
		return
	hat = hat_name
	for child in _hat_root.get_children():
		child.queue_free()
	var holder := Node3D.new()
	_hat_root.add_child(holder)
	Hats.build(hat_name, holder)
	if save:
		var cfg := ConfigFile.new()
		cfg.load(SETTINGS_PATH)
		cfg.set_value("player", "hat", hat_name)
		cfg.save(SETTINGS_PATH)


func respawn(sound_name := "home") -> void:
	teleport(respawn_point)
	_sfx(sound_name)


## Throws the player straight up, like a water jet does.
func launch(up_speed: float) -> void:
	velocity.y = up_speed
	_air_time = COYOTE_TIME
	_squash = 1.0


## Turns the camera to look along `dir` (only its flat part counts).
func look_toward(dir: Vector3) -> void:
	_cam_yaw = atan2(-dir.x, -dir.z)


func teleport(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_seat = null
	_cam_rig.global_position = pos + Vector3.UP * 1.3


func _sfx(sound_name: String, volume_db := 0.0, pitch := 1.0) -> void:
	if sound:
		sound.play(sound_name, volume_db, pitch)


func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	for side: float in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(0.15 * side, 0.75, 0)
		_model.add_child(leg)
		U.mesh_box(leg, Vector3(0.26, 0.75, 0.3), Vector3(0, -0.375, 0), PANTS)
		_legs.append(leg)
		var arm := Node3D.new()
		arm.position = Vector3(0.43 * side, 1.32, 0)
		_model.add_child(arm)
		U.mesh_box(arm, Vector3(0.22, 0.62, 0.26), Vector3(0, -0.28, 0), SKIN)
		_arms.append(arm)
	U.mesh_box(_model, Vector3(0.62, 0.62, 0.36), Vector3(0, 1.06, 0), SHIRT)
	var head := U.mesh_box(_model, Vector3(0.5, 0.5, 0.5), Vector3(0, 1.64, 0), SKIN)
	# Face looks toward -Z, which is "forward" in Godot.
	U.mesh_box(head, Vector3(0.08, 0.12, 0.02), Vector3(-0.11, 0.05, -0.255), Color.BLACK)
	U.mesh_box(head, Vector3(0.08, 0.12, 0.02), Vector3(0.11, 0.05, -0.255), Color.BLACK)
	U.mesh_box(head, Vector3(0.22, 0.05, 0.02), Vector3(0, -0.11, -0.255), Color(0.5, 0.1, 0.1))
	_hat_root = Node3D.new()
	_hat_root.position.y = 0.25  # top of the head
	head.add_child(_hat_root)


func _build_camera() -> void:
	_cam_rig = Node3D.new()
	_cam_rig.top_level = true
	add_child(_cam_rig)
	_cam_pitch_node = Node3D.new()
	_cam_rig.add_child(_cam_pitch_node)
	var arm := SpringArm3D.new()
	arm.spring_length = CAM_DISTANCE
	arm.margin = 0.3
	arm.add_excluded_object(get_rid())
	_cam_pitch_node.add_child(arm)
	var cam := Camera3D.new()
	cam.fov = 70
	cam.far = 200
	cam.current = true
	arm.add_child(cam)
	_cam_rig.global_position = global_position + Vector3.UP * 1.2


func _build_shadow() -> void:
	_shadow = U.mesh_cylinder(self, 0.45, 0.02, Vector3.ZERO, Color(0, 0, 0, 0.35))
	_shadow.top_level = true


func _read_move() -> Vector2:
	var v := Vector2.ZERO
	if ui:
		v = ui.move_vector
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): v.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): v.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): v.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): v.y += 1
	return v.limit_length(1.0)


func _read_jump() -> bool:
	return (ui != null and ui.jump_down) or Input.is_key_pressed(KEY_SPACE)


func _physics_process(delta: float) -> void:
	_seat_cooldown -= delta
	_kick_cooldown -= delta
	if _seat:
		_ride_seat()
		return
	var input := _read_move()
	var wish := Vector3(input.x, 0, input.y).rotated(Vector3.UP, _cam_yaw)
	var on_floor := is_on_floor()
	var on_slide := on_floor and _floor_obj != null and _floor_obj.has_meta("slide")
	if on_slide and not _was_on_slide:
		_sfx("slide", -2.0)
	_was_on_slide = on_slide

	_air_time = 0.0 if on_floor else _air_time + delta
	if not on_floor:
		velocity.y -= GRAVITY * delta

	if on_slide:
		var n := get_floor_normal()
		var downhill := (Vector3.DOWN - n * n.dot(Vector3.DOWN)).normalized()
		velocity += downhill * SLIDE_ACCEL * delta + wish * 3.0 * delta
		velocity = velocity.limit_length(SLIDE_MAX_SPEED)
	else:
		var flat := Vector3(velocity.x, 0, velocity.z)
		var accel := 40.0 if on_floor else 14.0
		if on_floor and wish == Vector3.ZERO:
			accel = 18.0
		flat = flat.move_toward(wish * WALK_SPEED * move_scale, accel * delta)
		velocity.x = flat.x
		velocity.z = flat.z

	# Holding the jump button keeps jumping. Easy for small hands.
	if _read_jump() and _air_time < COYOTE_TIME and velocity.y <= 0.5:
		velocity.y = JUMP_SPEED
		_air_time = COYOTE_TIME
		_sfx("jump", -4.0)

	var fall_speed := -velocity.y
	move_and_slide()
	var bounced := _after_move()
	if not bounced and not on_floor and is_on_floor() and fall_speed > 6.0:
		_sfx("land", -6.0)
	_update_shadow()

	if global_position.y < kill_y:
		respawn(fall_sound)


## Sit still on the swing seat and move with it. Jump to get off.
func _ride_seat() -> void:
	global_position = _seat.global_position + _seat.global_basis.y * 0.08
	velocity = Vector3.ZERO
	_update_shadow()
	if _read_jump():
		velocity = Vector3.UP * JUMP_SPEED + _seat.global_basis.z * -3.0
		_seat = null
		_seat_cooldown = 0.8
		_air_time = COYOTE_TIME
		_sfx("jump", -4.0)
		global_position.y += 0.1


## Handles what we touched. Returns true if we bounced on a trampoline.
func _after_move() -> bool:
	var bounced := false
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var obj := c.get_collider()
		if obj == null:
			continue
		var n := c.get_normal()
		if n.y > 0.6 and obj.has_meta("seat") and _seat_cooldown <= 0.0:
			_seat = obj
			_sfx("sit")
		if n.y > 0.6:
			if obj.has_meta("bounce"):
				var power: float = obj.get_meta("bounce")
				if _read_jump():
					power *= 1.15
				velocity.y = power
				_squash = 1.0
				_air_time = COYOTE_TIME
				if not bounced:
					_sfx("boing", 0.0, 1.25 - power * 0.025)  # bigger bounce, deeper boing
				bounced = true
		if obj is RigidBody3D:
			var push := -n
			push.y = 0.3
			obj.apply_central_impulse(push * 1.2)
			if _kick_cooldown <= 0.0:
				_sfx("kick", -3.0)
				_kick_cooldown = 0.3
	return bounced


func _process(delta: float) -> void:
	_update_camera(delta)
	_update_model(delta)


func _update_camera(delta: float) -> void:
	if ui:
		var look: Vector2 = ui.consume_look()
		_cam_yaw -= look.x * 0.008
		_cam_pitch = clampf(_cam_pitch - look.y * 0.006, -1.2, 0.25)
	# While sliding fast, turn the camera to look where we go, so spirals are not confusing.
	var on_slide := is_on_floor() and _floor_obj != null and _floor_obj.has_meta("slide")
	var flat := Vector3(velocity.x, 0, velocity.z)
	if on_slide and flat.length() > 3.0:
		_cam_yaw = lerp_angle(_cam_yaw, atan2(-flat.x, -flat.z), 1.0 - exp(-4.0 * delta))
	if Input.is_key_pressed(KEY_Q): _cam_yaw += 2.0 * delta
	if Input.is_key_pressed(KEY_E): _cam_yaw -= 2.0 * delta
	var target := global_position + Vector3.UP * 1.3
	_cam_rig.global_position = _cam_rig.global_position.lerp(target, 1.0 - exp(-10.0 * delta))
	_cam_rig.rotation = Vector3(0, _cam_yaw, 0)
	_cam_pitch_node.rotation.x = _cam_pitch


func _update_model(delta: float) -> void:
	var flat := Vector3(velocity.x, 0, velocity.z)
	var speed := flat.length()
	if speed > 0.5:
		var target_yaw := atan2(-flat.x, -flat.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, 1.0 - exp(-12.0 * delta))

	var leg_swing := 0.0
	var arm_angle := 0.0
	var on_slide := _floor_obj != null and _floor_obj.has_meta("slide")
	if _seat:
		_model.rotation.y = _seat.global_rotation.y
		arm_angle = -2.9  # hold the ropes
		leg_swing = -1.4  # legs forward, like sitting
		for i in 2:
			_legs[i].rotation.x = lerpf(_legs[i].rotation.x, leg_swing, 0.3)
			_arms[i].rotation.x = lerpf(_arms[i].rotation.x, arm_angle, 0.3)
		return
	if on_slide or not is_on_floor():
		arm_angle = -2.6  # arms up: wheee!
		leg_swing = 0.0 if on_slide else 0.35
	elif speed > 0.5:
		var before := sin(_walk_time)
		_walk_time += delta * speed * 1.8
		if signf(before) != signf(sin(_walk_time)):
			_sfx("step", -14.0)
		leg_swing = sin(_walk_time) * 0.7
	for i in 2:
		var s := 1.0 if i == 0 else -1.0
		_legs[i].rotation.x = lerpf(_legs[i].rotation.x, leg_swing * s, 0.3)
		var arm_target := arm_angle if arm_angle != 0.0 else -leg_swing * s
		_arms[i].rotation.x = lerpf(_arms[i].rotation.x, arm_target, 0.25)

	_squash = move_toward(_squash, 0.0, delta * 4.0)
	var q := sin(_squash * PI) * 0.3
	_model.scale = Vector3(1.0 + q, 1.0 - q, 1.0 + q)


func _update_shadow() -> void:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.5, global_position + Vector3.DOWN * 40)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	_shadow.visible = not hit.is_empty()
	_floor_obj = null
	if not hit.is_empty():
		if hit["position"].distance_to(global_position) < 0.3:
			_floor_obj = hit["collider"]
		_shadow.global_position = hit["position"] + Vector3.UP * 0.02
