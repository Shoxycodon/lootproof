extends Node

var active_traps: Array[Node] = []


func register_trap(trap: Node) -> void:
	active_traps.append(trap)


func clear_traps() -> void:
	for trap in active_traps:
		if is_instance_valid(trap):
			trap.queue_free()
	active_traps.clear()
