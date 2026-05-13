extends Node

var score := 0
var best_time := INF


func register_defense() -> void:
	score += 100


func register_clear(time_used: float) -> void:
	score += maxi(25, 150 - int(time_used))
	best_time = minf(best_time, time_used)


func register_trap_kill() -> void:
	score += 35
