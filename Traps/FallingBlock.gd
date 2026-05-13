extends RigidBody2D

signal triggered(target: Node)

@export var trigger_delay := 0.18
var has_triggered := false


func _ready() -> void:
	$Trigger.body_entered.connect(_on_trigger_body_entered)


func _on_trigger_body_entered(body: Node) -> void:
	if has_triggered:
		return
	has_triggered = true
	triggered.emit(body)
	await get_tree().create_timer(trigger_delay).timeout
	freeze = false
