extends CharacterBody2D

signal died
signal sampled_input(sample: Dictionary)
signal dashed

@export var speed := 220.0
@export var ground_acceleration := 1550.0
@export var air_acceleration := 1450.0
@export var friction := 1650.0
@export var jump_velocity := -360.0
@export var wall_jump_x := 240.0
@export var wall_jump_y := -340.0
@export var dash_speed := 420.0
@export var dash_time := 0.16
@export var dash_cooldown := 0.35
@export var coyote_time := 0.12
@export var jump_buffer_time := 0.1
@export var gravity := 1050.0
@export var fall_gravity_multiplier := 1.18
@export var max_fall_speed := 620.0
@export var wall_slide_speed := 90.0
@export var wall_stick_time := 0.18
@export var shadow_ray_length := 220.0

var facing := 1.0
var coyote_timer := 0.0
var jump_buffer := 0.0
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var wall_stick_timer := 0.0
var wall_jump_direction := 0.0
var dead := false
var was_on_floor := false
var spin_rotation := 0.0
var wall_spin_timer := 0.0
var wall_spin_duration := 0.58
var wall_spin_direction := 1.0
var screw_flip_timer := 0.0
var screw_flip_duration := 0.1275
var screw_flip_direction := 1.0
var wall_dust_timer := 0.0

@onready var visual_root := $VisualRoot
@onready var body_visual := $VisualRoot/Body
@onready var shadow := $Shadow
@onready var trail := $Trail


func _physics_process(delta: float) -> void:
	if dead:
		return

	var move_axis := Input.get_axis("move_left", "move_right")
	if absf(move_axis) > 0.1:
		facing = signf(move_axis)

	if is_on_floor():
		coyote_timer = coyote_time
		wall_stick_timer = 0.0
	else:
		coyote_timer -= delta
		wall_stick_timer -= delta

	if Input.is_action_just_pressed("jump"):
		jump_buffer = jump_buffer_time
	else:
		jump_buffer -= delta

	dash_cooldown_timer -= delta
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0:
		dash_timer = dash_time
		dash_cooldown_timer = dash_cooldown
		velocity = Vector2(facing * dash_speed, 0.0)
		visual_root.scale = Vector2(1.24, 0.74)
		dashed.emit()

	if dash_timer > 0.0:
		dash_timer -= delta
	else:
		_apply_movement(move_axis, delta)
		_apply_wall_slide()
		_try_jump()

	move_and_slide()
	_update_wall_contact()
	_update_game_feel(move_axis, delta)
	_update_floor_shadow()
	_emit_replay_sample(move_axis)


func _apply_movement(move_axis: float, delta: float) -> void:
	var gravity_scale := fall_gravity_multiplier if velocity.y > 0.0 else 1.0
	velocity.y = minf(velocity.y + gravity * gravity_scale * delta, max_fall_speed)

	if absf(move_axis) > 0.1:
		var accel := ground_acceleration if is_on_floor() else air_acceleration
		velocity.x = move_toward(velocity.x, move_axis * speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.48


func _try_jump() -> void:
	if jump_buffer <= 0.0:
		return

	if coyote_timer > 0.0:
		velocity.y = jump_velocity
		visual_root.scale = Vector2(0.82, 1.22)
		_start_screw_flip(facing)
		jump_buffer = 0.0
		coyote_timer = 0.0
	elif wall_stick_timer > 0.0:
		velocity = Vector2(wall_jump_direction * wall_jump_x, wall_jump_y)
		facing = signf(wall_jump_direction)
		visual_root.scale = Vector2(0.78, 1.18)
		_start_wall_spin(wall_jump_direction)
		jump_buffer = 0.0
		wall_stick_timer = 0.0


func kill() -> void:
	if dead:
		return
	dead = true
	body_visual.modulate = Color(1.0, 0.32, 0.36, 1)
	died.emit()


func _update_game_feel(move_axis: float, delta: float) -> void:
	if is_on_floor() and not was_on_floor:
		visual_root.scale = Vector2(1.18, 0.78)
		wall_spin_timer = 0.0
		spin_rotation = 0.0
		screw_flip_timer = 0.0
	was_on_floor = is_on_floor()

	var target_scale := Vector2.ONE
	if dash_timer > 0.0:
		target_scale = Vector2(1.24, 0.74)
	elif not is_on_floor() and velocity.y < 0.0:
		target_scale = Vector2(0.9, 1.12)
	visual_root.scale = visual_root.scale.lerp(target_scale, 16.0 * delta)
	_apply_screw_flip(delta)

	var target_rotation := 0.0
	if dash_timer > 0.0:
		target_rotation = deg_to_rad(16.0) * facing
	elif absf(move_axis) > 0.1:
		target_rotation = deg_to_rad(7.0) * move_axis
	_update_wall_spin(delta)
	visual_root.rotation = lerp_angle(visual_root.rotation, target_rotation + spin_rotation, 12.0 * delta)

	trail.clear_points()
	if dash_timer > 0.0 or velocity.length() > 250.0:
		trail.add_point(Vector2.ZERO)
		trail.add_point(Vector2(-facing * 34.0, 0.0))


func _apply_wall_slide() -> void:
	if is_on_floor() or wall_stick_timer <= 0.0 or velocity.y <= 0.0:
		return
	velocity.y = minf(velocity.y, wall_slide_speed)
	wall_dust_timer -= get_physics_process_delta_time()
	if wall_dust_timer <= 0.0:
		wall_dust_timer = 0.055
		_spawn_wall_dust()
	visual_root.rotation = lerp_angle(visual_root.rotation, deg_to_rad(10.0) * -wall_jump_direction, 0.35)


func _update_wall_contact() -> void:
	if is_on_wall_only():
		var normal := get_wall_normal()
		if absf(normal.x) > 0.1:
			wall_jump_direction = normal.x
			wall_stick_timer = wall_stick_time


func _start_screw_flip(direction: float) -> void:
	screw_flip_direction = signf(direction if direction != 0.0 else facing)
	screw_flip_timer = screw_flip_duration
	wall_spin_timer = 0.0
	spin_rotation = 0.0


func _start_wall_spin(direction: float) -> void:
	wall_spin_direction = signf(direction if direction != 0.0 else facing)
	wall_spin_timer = wall_spin_duration
	screw_flip_timer = 0.0
	spin_rotation = 0.0


func _apply_screw_flip(delta: float) -> void:
	if screw_flip_timer <= 0.0:
		return
	screw_flip_timer = maxf(screw_flip_timer - delta, 0.0)
	var progress := 1.0 - screw_flip_timer / screw_flip_duration
	var flip_scale := cos(progress * TAU)
	if absf(flip_scale) < 0.18:
		flip_scale = 0.18 * signf(flip_scale if flip_scale != 0.0 else screw_flip_direction)
	visual_root.scale.x *= flip_scale


func _update_wall_spin(delta: float) -> void:
	if wall_spin_timer <= 0.0:
		return
	wall_spin_timer = maxf(wall_spin_timer - delta, 0.0)
	var progress := 1.0 - wall_spin_timer / wall_spin_duration
	spin_rotation = TAU * wall_spin_direction * ease(progress, -1.8)


func _spawn_wall_dust() -> void:
	var dust := Polygon2D.new()
	dust.polygon = PackedVector2Array([Vector2(-3, -3), Vector2(3, -3), Vector2(3, 3), Vector2(-3, 3)])
	dust.color = Color(0.9, 0.78, 0.52, 0.72)
	dust.global_position = global_position + Vector2(-wall_jump_direction * 15.0, randf_range(4.0, 13.0))
	get_parent().add_child(dust)
	var drift := Vector2(-wall_jump_direction * randf_range(8.0, 18.0), randf_range(8.0, 18.0))
	var tween := create_tween()
	tween.tween_property(dust, "global_position", dust.global_position + drift, 0.24)
	tween.parallel().tween_property(dust, "modulate:a", 0.0, 0.24)
	tween.tween_callback(dust.queue_free)


func _update_floor_shadow() -> void:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2.DOWN * shadow_ray_length)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		shadow.visible = false
		return

	var floor_distance: float = global_position.distance_to(hit["position"])
	shadow.visible = true
	shadow.global_position = hit["position"] + Vector2(0.0, -1.0)
	shadow.global_rotation = 0.0
	var distance_t := clampf(floor_distance / shadow_ray_length, 0.0, 1.0)
	var scale_factor := lerpf(1.05, 0.55, distance_t)
	shadow.scale = Vector2(scale_factor, 0.24 * scale_factor)
	shadow.modulate.a = lerpf(0.34, 0.08, distance_t)


func _emit_replay_sample(move_axis: float) -> void:
	sampled_input.emit({
		"time": Time.get_ticks_msec() / 1000.0,
		"move_direction": move_axis,
		"jump_pressed": Input.is_action_pressed("jump"),
		"dash_pressed": Input.is_action_pressed("dash"),
		"position": global_position,
		"velocity": velocity
	})
