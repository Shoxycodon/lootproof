extends Node

@export var proof_clears_required := 2
var proof_status := false


func reset_proof() -> void:
	proof_status = false


func register_clear(clear_count: int) -> void:
	proof_status = clear_count >= proof_clears_required
