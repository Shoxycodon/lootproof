extends Node2D

signal finished

var replay: Array = []
var cursor := 0
var elapsed := 0.0
var start_time := 0.0
var has_finished := false


func play(data: Array) -> void:
	replay = data.duplicate(true)
	cursor = 0
	elapsed = 0.0
	has_finished = false
	start_time = replay[0]["time"] if not replay.is_empty() else 0.0
	visible = not replay.is_empty()


func _process(delta: float) -> void:
	if replay.is_empty():
		return
	elapsed += delta
	var target_time := start_time + elapsed
	while cursor < replay.size() - 1 and replay[cursor + 1]["time"] <= target_time:
		cursor += 1
	if cursor < replay.size() - 1:
		var a = replay[cursor]
		var b = replay[cursor + 1]
		var span = maxf(b["time"] - a["time"], 0.001)
		var t = clampf((target_time - a["time"]) / span, 0.0, 1.0)
		global_position = a["position"].lerp(b["position"], t)
	else:
		global_position = replay[cursor]["position"]
		if not has_finished:
			has_finished = true
			finished.emit()
