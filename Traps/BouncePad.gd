extends "res://Traps/BaseTrap.gd"

@export var bounce_velocity := -760.0


func _ready() -> void:
	lethal = false
	super()


func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D:
		body.velocity.y = bounce_velocity
	triggered.emit(body)
