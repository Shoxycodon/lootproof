extends Node2D

enum Phase { BUILD, PROOF, WAITING, RAID, RESULTS }

@export var player_scene: PackedScene
@export var run_time_limit := 120.0
@export var proof_clears_required := 2

var phase := Phase.BUILD
var time_left := 120.0
var proof_clears := 0
var player: Node2D
var my_player_id := 1
var opponent_player_id := 2
var submitted_dungeons := {}
var raid_results := {}
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
@onready var treasure_glow := $World/Goal/TreasureGlow
@onready var far_parallax := $World/FarParallax
@onready var mid_parallax := $World/MidParallax


func _ready() -> void:
	my_player_id = 1 if multiplayer.is_server() else 2
	opponent_player_id = 2 if my_player_id == 1 else 1
	build_grid.network_shared_build = false
	build_grid.build_changed.connect(_on_build_changed)
	build_grid.trap_requested.connect(_on_trap_requested)
	validator.proof_clears_required = proof_clears_required
	_start_build_phase()


func _process(delta: float) -> void:
	treasure_glow.scale = Vector2.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.08)
	if phase == Phase.PROOF:
		time_left -= delta
		proof_elapsed += delta
		if time_left <= 0.0:
			_start_build_phase(false)
	elif phase == Phase.RAID:
		time_left -= delta
		raid_elapsed += delta
		if time_left <= 0.0:
			_finish_raid(false)

	_update_camera(delta)
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("scoreboard"):
		hud.set_scoreboard_visible(true)
	if event.is_action_released("scoreboard"):
		hud.set_scoreboard_visible(false)
	if event.is_action_pressed("build_mode") and phase == Phase.BUILD:
		_start_proof_phase()
	if event.is_action_pressed("restart_run"):
		if phase == Phase.PROOF:
			_start_proof_phase()
		elif phase == Phase.RAID:
			_start_raid_phase()


func _start_build_phase(reset_proof := true) -> void:
	phase = Phase.BUILD
	time_left = run_time_limit
	proof_elapsed = 0.0
	raid_elapsed = 0.0
	raid_deaths = 0
	_remove_runner()
	build_grid.set_build_mode(true)
	if reset_proof:
		proof_clears = 0
		validator.reset_proof()
	hud.show_feedback("P%d BUILD: create the dungeon P%d must raid" % [my_player_id, opponent_player_id])


func _start_proof_phase() -> void:
	phase = Phase.PROOF
	time_left = run_time_limit
	proof_elapsed = 0.0
	build_grid.set_build_mode(false)
	_spawn_runner()
	hud.show_feedback("P%d PROOF: clear your dungeon %d times" % [my_player_id, proof_clears_required])


func _start_waiting_phase() -> void:
	phase = Phase.WAITING
	time_left = 0.0
	_remove_runner()
	build_grid.set_build_mode(false)
	hud.show_feedback("Dungeon proven. Waiting for P%d..." % opponent_player_id)


func _start_raid_phase() -> void:
	phase = Phase.RAID
	time_left = run_time_limit
	raid_elapsed = 0.0
	raid_deaths = 0
	build_grid.set_build_mode(false)
	_spawn_runner()
	hud.show_feedback("RAID: clear P%d's proven dungeon" % opponent_player_id)


func _show_results(results: Dictionary) -> void:
	phase = Phase.RESULTS
	_remove_runner()
	build_grid.set_build_mode(false)
	var mine: Dictionary = results.get(my_player_id, {})
	var theirs: Dictionary = results.get(opponent_player_id, {})
	var mine_clear := bool(mine.get("cleared", false))
	var theirs_clear := bool(theirs.get("cleared", false))
	hud.show_feedback("RESULTS: You %s, P%d %s" % [
		"cleared" if mine_clear else "failed",
		opponent_player_id,
		"cleared" if theirs_clear else "failed"
	])
	_update_scoreboard(results)


func _submit_proven_dungeon() -> void:
	var snapshot: Dictionary = build_grid.snapshot_user_build()
	_start_waiting_phase()
	if multiplayer.is_server():
		_receive_proven_dungeon(my_player_id, snapshot)
	else:
		_submit_proven_dungeon_rpc.rpc_id(1, snapshot)


@rpc("any_peer", "call_remote", "reliable")
func _submit_proven_dungeon_rpc(snapshot: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	_receive_proven_dungeon(2, snapshot)


func _receive_proven_dungeon(player_id: int, snapshot: Dictionary) -> void:
	submitted_dungeons[player_id] = snapshot
	if submitted_dungeons.has(1) and submitted_dungeons.has(2):
		_begin_raid_for_all()


func _begin_raid_for_all() -> void:
	var p1_snapshot: Dictionary = submitted_dungeons[1]
	var p2_snapshot: Dictionary = submitted_dungeons[2]
	_begin_raid_with_snapshot(p2_snapshot)
	_begin_raid_with_snapshot_rpc.rpc_id(2, p1_snapshot)


@rpc("authority", "call_remote", "reliable")
func _begin_raid_with_snapshot_rpc(snapshot: Dictionary) -> void:
	_begin_raid_with_snapshot(snapshot)


func _begin_raid_with_snapshot(snapshot: Dictionary) -> void:
	build_grid.restore_user_build(snapshot)
	_start_raid_phase()


func _finish_raid(cleared: bool) -> void:
	var result: Dictionary = {
		"cleared": cleared,
		"time": raid_elapsed,
		"deaths": raid_deaths
	}
	phase = Phase.RESULTS
	_remove_runner()
	build_grid.set_build_mode(false)
	hud.show_feedback("Raid submitted. Waiting for P%d..." % opponent_player_id)
	if multiplayer.is_server():
		_receive_raid_result(my_player_id, result)
	else:
		_submit_raid_result_rpc.rpc_id(1, result)


@rpc("any_peer", "call_remote", "reliable")
func _submit_raid_result_rpc(result: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	_receive_raid_result(2, result)


func _receive_raid_result(player_id: int, result: Dictionary) -> void:
	raid_results[player_id] = result
	if raid_results.has(1) and raid_results.has(2):
		_show_results(raid_results)
		_show_results_rpc.rpc_id(2, raid_results)


@rpc("authority", "call_remote", "reliable")
func _show_results_rpc(results: Dictionary) -> void:
	_show_results(results)


func _spawn_runner() -> void:
	_remove_runner()
	player = player_scene.instantiate()
	$World.add_child(player)
	player.global_position = spawn_point.global_position
	player.died.connect(_on_player_died)
	player.dashed.connect(_on_player_dashed)


func _remove_runner() -> void:
	if is_instance_valid(player):
		player.queue_free()
	player = null


func _on_goal_body_entered(body: Node) -> void:
	if body != player:
		return
	if phase == Phase.PROOF:
		proof_clears += 1
		validator.register_clear(proof_clears)
		if validator.proof_status:
			_submit_proven_dungeon()
		else:
			hud.show_feedback("Proof clear %d/%d" % [proof_clears, proof_clears_required])
			await get_tree().create_timer(0.8).timeout
			_start_proof_phase()
	elif phase == Phase.RAID:
		_finish_raid(true)


func _on_player_died() -> void:
	_shake(0.16, 5.0)
	await get_tree().create_timer(0.8).timeout
	if phase == Phase.PROOF:
		hud.show_feedback("Proof failed. Try again.")
		_start_proof_phase()
	elif phase == Phase.RAID:
		raid_deaths += 1
		hud.show_feedback("Raid death %d" % raid_deaths)
		_start_raid_phase()


func _on_build_changed() -> void:
	if phase != Phase.BUILD:
		return
	proof_clears = 0
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


func _update_hud() -> void:
	hud.set_state(
		Phase.keys()[phase],
		maxf(time_left, 0.0),
		build_grid.build_points,
		build_grid.get_selected_item_name(),
		build_grid.get_selected_item_cost(),
		proof_clears,
		proof_clears_required,
		validator.proof_status,
		0,
		my_player_id,
		opponent_player_id,
		1,
		1,
		0,
		0,
		raid_deaths
	)


func _update_scoreboard(results: Dictionary) -> void:
	var lines: Array[String] = [
		"MULTIPLAYER RESULTS",
		"P1: %s" % _format_result(results.get(1, {})),
		"P2: %s" % _format_result(results.get(2, {}))
	]
	hud.update_scoreboard(lines)
	hud.set_scoreboard_visible(true)


func _format_result(result: Dictionary) -> String:
	if result.is_empty():
		return "waiting"
	return "%s, %.1fs, %d deaths" % [
		"clear" if bool(result.get("cleared", false)) else "failed",
		float(result.get("time", 0.0)),
		int(result.get("deaths", 0))
	]


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
