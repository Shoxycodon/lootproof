extends CanvasLayer

@onready var timer_label := $Root/Timer
@onready var left_panel := $Root/LeftPanel
@onready var right_panel := $Root/RightPanel
@onready var feedback := $Root/Feedback
@onready var build_preview := $Root/BuildPreview
@onready var turn_banner := $Root/TurnBanner
@onready var turn_banner_art := $Root/TurnBannerArt
@onready var scoreboard := $Root/Scoreboard
@onready var scoreboard_text := $Root/Scoreboard/ScoreboardText

var turn_tween: Tween


func set_state(phase: String, time_left: float, build_points: int, selected_item: String, selected_cost: int, proof_clears: int, proof_required: int, proof_status: bool, replay_samples: int, builder: int, raider: int, round_index: int, max_rounds: int, p1_score: int, p2_score: int, raid_deaths: int) -> void:
	timer_label.text = "%03d" % ceili(time_left)
	timer_label.modulate = Color(1, 0.3, 0.25, 1) if time_left <= 10.0 else Color.WHITE
	left_panel.text = "P%d BUILDS / P%d RAIDS\nRound: %d/%d\nItem: %s\nCost: %d  Points: %d\nProof: %d/%d" % [builder, raider, round_index, max_rounds, selected_item, selected_cost, build_points, proof_clears, proof_required]
	right_panel.text = "P1 %d  P2 %d\nTAB: Scoreboard" % [p1_score, p2_score]
	_update_build_preview(selected_item)


func show_feedback(message: String) -> void:
	feedback.text = message


func show_turn_banner(builder: int) -> void:
	turn_banner.text = "SPIELER %d VERTEIDIGT NUN" % builder
	turn_banner.visible = true
	turn_banner_art.visible = true
	turn_banner.modulate.a = 0.0
	turn_banner_art.modulate.a = 0.0
	if turn_tween:
		turn_tween.kill()
	turn_tween = create_tween()
	turn_tween.tween_property(turn_banner, "modulate:a", 1.0, 0.18)
	turn_tween.parallel().tween_property(turn_banner_art, "modulate:a", 1.0, 0.18)
	turn_tween.tween_interval(1.25)
	turn_tween.tween_property(turn_banner, "modulate:a", 0.0, 0.3)
	turn_tween.parallel().tween_property(turn_banner_art, "modulate:a", 0.0, 0.3)
	turn_tween.tween_callback(func():
		turn_banner.visible = false
		turn_banner_art.visible = false
	)


func set_scoreboard_visible(enabled: bool) -> void:
	scoreboard.visible = enabled


func update_scoreboard(lines: Array[String]) -> void:
	scoreboard_text.text = "\n".join(lines)


func _update_build_preview(selected_item: String) -> void:
	var icons := {
		"Platform": "■",
		"Spike": "▲",
		"Saw": "●",
		"Bounce": "▰",
		"Falling": "▣"
	}
	var colors := {
		"Platform": Color(0.35, 0.72, 0.86, 1),
		"Spike": Color(1, 0.16, 0.24, 1),
		"Saw": Color(1, 0.82, 0.18, 1),
		"Bounce": Color(0.18, 1, 0.56, 1),
		"Falling": Color(0.78, 0.45, 0.22, 1)
	}
	build_preview.text = icons.get(selected_item, "■")
	build_preview.modulate = colors.get(selected_item, Color.WHITE)
