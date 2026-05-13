extends Area2D

signal triggered(target: Node)

@export var lethal := true
@export var trigger_cooldown := 0.2
var cooldown := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	cooldown = maxf(cooldown - delta, 0.0)


func _on_body_entered(body: Node) -> void:
	if cooldown > 0.0:
		return
	cooldown = trigger_cooldown
	triggered.emit(body)
