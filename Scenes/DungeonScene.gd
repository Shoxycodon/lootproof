extends Node2D

enum Phase { BUILD, PROOF, RAID, SOLUTION, COLLAPSE }

@export var player_scene: PackedScene
@export var ghost_scene: PackedScene
@export var run_time_limit := 120.0
@export var proof_clears_required := 2
@export var builder_rounds_per_player := 3
@export var carryover_bonus_points := 8
@export var max_carryover_build_points := 32

var phase := Phase.BUILD
var time_left := 120.0
var proof_clears := 0
var best_replay: Array = []
var player: Node2D
var ghost: Node2D
var collapse_elapsed := 0.0
var current_builder := 1
var current_raider := 2
var builder_round := 1
var player_scores := {1: 0, 2: 0}
var builder_dungeon_snapshots := {1: {}, 2: {}}
var run_history: Array[String] = []
var raid_deaths := 0
var raid_elapsed := 0.0
var proof_elapsed := 0.0
var shake_time := 0.0
var shake_strength := 0.0

@onready var build_grid := $World/BuildGrid
@onready var traps := $World/Traps
@onready var spawn_point := $World/SpawnPoint
@onready var camera := $Camera2D
@onready var hud := $HUD
@onready var validator := $DungeonValidator
@onready var recorder := $ReplayRecorder
@onready var treasure_glow := $World/Goal/TreasureGlow
@onready var far_parallax := $World/FarParallax
@onready var mid_parallax := $World/MidParallax


func _ready() -> void:
	build_grid.build_changed.connect(_on_build_changed)
	build_grid.trap_requested.connect(_on_trap_requested)
	validator.proof_clears_required = proof_clears_required
	_start_build_phase()


func _process(delta: float) -> void:
	treasure_glow.scale = Vector2.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.08)
	if phase in [Phase.PROOF, Phase.RAID]:
		time_left -= delta
		if phase == Phase.PROOF:
			proof_elapsed += delta
		if phase == Phase.RAID:
			raid_elapsed += delta
		if time_left <= 0.0:
			if phase == Phase.RAID:
				_start_solution_replay()
			else:
				_start_collapse()
	if phase == Phase.COLLAPSE:
		collapse_elapsed += delta
		build_grid.collapse_step(collapse_elapsed)

	_update_camera(delta)

	hud.set_state(
		Phase.keys()[phase],
		maxf(time_left, 0.0),
		build_grid.build_points,
		build_grid.get_selected_item_name(),
		build_grid.get_selected_item_cost(),
		proof_clears,
		proof_clears_required,
		validator.proof_status,
		best_replay.size(),
		current_builder,
		current_raider,
		builder_round,
		builder_rounds_per_player,
		player_scores[1],
		player_scores[2],
		raid_deaths
	)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("scoreboard"):
		hud.set_scoreboard_visible(true)
	if event.is_action_released("scoreboard"):
		hud.set_scoreboard_visible(false)
	if event.is_action_pressed("build_mode"):
		if phase == Phase.BUILD:
			_start_proof_phase()
		else:
			_start_build_phase(false)
	if event.is_action_pressed("restart_run"):
		if phase == Phase.BUILD:
			_start_proof_phase()
		elif phase == Phase.RAID:
			_start_raid_phase()
		else:
			_start_proof_phase()


func _start_build_phase(load_builder_layout := true) -> void:
	phase = Phase.BUILD
	time_left = run_time_limit
	raid_elapsed = 0.0
	proof_elapsed = 0.0
	raid_deaths = 0
	_remove_runner()
	_remove_ghost()
	if load_builder_layout:
		_load_builder_dungeon(current_builder)
	build_grid.set_build_mode(true)
	hud.show_turn_banner(current_builder)
	_update_scoreboard()
	hud.show_feedback("PLAYER %d BUILDS: place traps, then start proof" % current_builder)


func _start_proof_phase() -> void:
	phase = Phase.PROOF
	time_left = run_time_limit
	proof_elapsed = 0.0
	collapse_elapsed = 0.0
	build_grid.set_build_mode(false)
	_spawn_runner(true)
	_remove_ghost()
	recorder.start_recording()
	hud.show_feedback("PLAYER %d PROOF: reach TREASURE twice" % current_builder)


func _start_raid_phase() -> void:
	phase = Phase.RAID
	time_left = run_time_limit
	collapse_elapsed = 0.0
	raid_elapsed = 0.0
	raid_deaths = 0
	build_grid.set_build_mode(false)
	_spawn_runner(false)
	_remove_ghost()
	hud.show_feedback("PLAYER %d RAID: steal TREASURE before time runs out" % current_raider)


func _start_solution_replay() -> void:
	phase = Phase.SOLUTION
	time_left = 0.0
	_remove_runner()
	_spawn_ghost()
	var points := 150 + raid_deaths * 40
	_add_score(current_builder, points)
	_record_run("P%d defense timeout vs P%d: deaths %d, +%d" % [current_builder, current_raider, raid_deaths, points])
	_shake(0.18, 5.0)
	hud.show_feedback("TIME UP: creator ghost shows the proven route")


func _start_collapse() -> void:
	phase = Phase.COLLAPSE
	collapse_elapsed = 0.0
	_shake(0.24, 6.0)
	hud.show_feedback("DUNGEON COLLAPSE")
	if is_instance_valid(player):
		player.kill()


func _spawn_runner(record_run: bool) -> void:
	_remove_runner()
	player = player_scene.instantiate()
	$World.add_child(player)
	player.global_position = spawn_point.global_position
	player.died.connect(_on_player_died)
	player.dashed.connect(_on_player_dashed)
	if record_run:
		player.sampled_input.connect(recorder.record_sample)


func _remove_runner() -> void:
	if is_instance_valid(player):
		player.queue_free()
	player = null


func _spawn_ghost() -> void:
	_remove_ghost()
	if best_replay.is_empty():
		hud.show_feedback("No proof ghost recorded yet")
		return
	ghost = ghost_scene.instantiate()
	$World.add_child(ghost)
	ghost.global_position = spawn_point.global_position
	if phase == Phase.SOLUTION:
		ghost.finished.connect(_on_solution_ghost_finished)
	ghost.play(best_replay)


func _remove_ghost() -> void:
	if is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null


func _on_goal_body_entered(body: Node) -> void:
	if body != player:
		return
	if phase == Phase.PROOF:
		var replay: Array = recorder.stop_recording()
		if best_replay.is_empty() or replay.size() < best_replay.size():
			best_replay = replay
		proof_clears += 1
		_record_run("P%d Proof %d/%d: %.1fs" % [current_builder, proof_clears, proof_clears_required, proof_elapsed])
		validator.register_clear(proof_clears)
		if validator.proof_status:
			hud.show_feedback("MAP PROVEN: Player 2 can now raid")
			await get_tree().create_timer(0.8).timeout
			_start_raid_phase()
		else:
			hud.show_feedback("Proof clear %d/%d - starting next proof run" % [proof_clears, proof_clears_required])
			await get_tree().create_timer(0.8).timeout
			_start_proof_phase()
	elif phase == Phase.RAID:
		var time_bonus := maxi(0, int(time_left))
		var clean_bonus := maxi(0, 60 - raid_deaths * 20)
		var points := 120 + time_bonus + clean_bonus
		_add_score(current_raider, points)
		_save_successful_builder_dungeon()
		_record_run("P%d Raid clear vs P%d: %.1fs, deaths %d, +%d" % [current_raider, current_builder, raid_elapsed, raid_deaths, points])
		hud.show_feedback("PLAYER %d RAID CLEAR +%d" % [current_raider, points])
		await get_tree().create_timer(1.0).timeout
		_finish_round_and_swap_roles()


func _on_player_died() -> void:
	_shake(0.16, 5.0)
	hud.show_feedback("DEATH")
	await get_tree().create_timer(0.8).timeout
	if phase == Phase.PROOF:
		_record_run("P%d Proof death after %.1fs" % [current_builder, proof_elapsed])
		_start_proof_phase()
	elif phase == Phase.RAID:
		raid_deaths += 1
		_add_score(current_builder, 40)
		_record_run("P%d Raid death vs P%d: attempt %d, +40 builder" % [current_raider, current_builder, raid_deaths])
		_start_raid_phase()


func _on_build_changed() -> void:
	proof_clears = 0
	best_replay.clear()
	validator.reset_proof()
	hud.show_feedback("Layout changed: proof reset")


func _on_trap_requested(scene: PackedScene, grid_position: Vector2i, item_index: int) -> void:
	var trap := scene.instantiate()
	traps.add_child(trap)
	trap.global_position = build_grid.grid_to_world(grid_position)
	trap.triggered.connect(_on_trap_triggered.bind(trap))
	build_grid.set_trap_node(grid_position, trap, item_index)


func _on_trap_triggered(target: Node, trap: Node) -> void:
	if target == player and target.has_method("kill") and trap.get("lethal") != false:
		target.kill()


func _on_solution_ghost_finished() -> void:
	builder_dungeon_snapshots[current_builder] = {}
	hud.show_feedback("DEFENSE SCORED: roles swap")
	await get_tree().create_timer(1.0).timeout
	_finish_round_and_swap_roles()


func _finish_round_and_swap_roles() -> void:
	if current_builder == 2:
		builder_round += 1
	if builder_round > builder_rounds_per_player:
		_show_match_result()
		return
	var old_builder := current_builder
	current_builder = current_raider
	current_raider = old_builder
	proof_clears = 0
	best_replay.clear()
	validator.reset_proof()
	_start_build_phase()


func _show_match_result() -> void:
	phase = Phase.BUILD
	_remove_runner()
	_remove_ghost()
	build_grid.set_build_mode(false)
	var winner := 0
	if player_scores[1] != player_scores[2]:
		winner = 1 if player_scores[1] > player_scores[2] else 2
	hud.show_feedback("MATCH OVER: DRAW" if winner == 0 else "MATCH OVER: PLAYER %d WINS" % winner)


func _add_score(player_id: int, points: int) -> void:
	player_scores[player_id] += points
	_update_scoreboard()


func _record_run(line: String) -> void:
	run_history.append(line)
	if run_history.size() > 12:
		run_history.pop_front()
	_update_scoreboard()


func _update_scoreboard() -> void:
	var lines: Array[String] = [
		"SCOREBOARD",
		"P1 Score: %d     P2 Score: %d" % [player_scores[1], player_scores[2]],
		"Builder: P%d     Raider: P%d     Round: %d/%d" % [current_builder, current_raider, builder_round, builder_rounds_per_player],
		"",
		"Run Log:"
	]
	if run_history.is_empty():
		lines.append("No runs recorded yet.")
	else:
		for entry in run_history:
			lines.append("- " + entry)
	hud.update_scoreboard(lines)


func _load_builder_dungeon(builder_id: int) -> void:
	var snapshot: Dictionary = builder_dungeon_snapshots.get(builder_id, {})
	if snapshot.is_empty():
		build_grid.clear_user_build()
	else:
		build_grid.restore_user_build(snapshot)


func _save_successful_builder_dungeon() -> void:
	var snapshot: Dictionary = build_grid.snapshot_user_build()
	snapshot["build_points"] = mini(max_carryover_build_points, int(snapshot.get("build_points", build_grid.max_build_points)) + carryover_bonus_points)
	builder_dungeon_snapshots[current_builder] = snapshot


func _on_player_dashed() -> void:
	_shake(0.06, 1.8)


func _shake(duration: float, strength: float) -> void:
	shake_time = maxf(shake_time, duration)
	shake_strength = maxf(shake_strength, strength)


func _update_camera(delta: float) -> void:
	if is_instance_valid(player):
		var lookahead := Vector2.ZERO
		if player is CharacterBody2D:
			lookahead = Vector2(clampf(player.velocity.x * 0.22, -58.0, 58.0), clampf(player.velocity.y * 0.05, -22.0, 32.0))
		var target := player.global_position + lookahead
		camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-8.5 * delta))
	far_parallax.global_position.x = camera.global_position.x * 0.18 + 485.0
	mid_parallax.global_position.x = camera.global_position.x * 0.35 + 370.0
	if shake_time > 0.0:
		shake_time -= delta
		camera.offset = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
		shake_strength = move_toward(shake_strength, 0.0, 18.0 * delta)
	else:
		camera.offset = camera.offset.lerp(Vector2.ZERO, 12.0 * delta)
