extends Control

@onready var start_button := $StartButton
@onready var multiplayer_button := $MultiplayerButton


func _ready() -> void:
	start_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump") or event.is_action_pressed("interact"):
		_on_start_button_pressed()


func _on_start_button_pressed() -> void:
	MultiplayerManager.close_connection()
	get_tree().change_scene_to_file("res://Scenes/DungeonScene.tscn")


func _on_multiplayer_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/MultiplayerLobby.tscn")
