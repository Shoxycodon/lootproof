extends "res://Traps/BaseTrap.gd"

@export var rotation_speed := 8.0


func _process(delta: float) -> void:
	super(delta)
	$Visual.rotation += rotation_speed * delta
