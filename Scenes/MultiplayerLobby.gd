extends Control

@onready var host_button := $HostButton
@onready var join_button := $JoinButton
@onready var back_button := $BackButton
@onready var address_input := $AddressInput
@onready var status_label := $StatusLabel


func _ready() -> void:
	host_button.grab_focus()
	MultiplayerManager.player_connected.connect(_on_player_connected)
	MultiplayerManager.connection_success.connect(_on_connection_success)
	MultiplayerManager.connection_failed.connect(_on_connection_failed)
	MultiplayerManager.server_disconnected.connect(_on_server_disconnected)
	if MultiplayerManager.last_error_message != "":
		status_label.text = MultiplayerManager.last_error_message
		MultiplayerManager.last_error_message = ""


func _on_host_button_pressed() -> void:
	var error := MultiplayerManager.host_game()
	if error != OK:
		status_label.text = "Host Error: %d" % error
		return
	status_label.text = "Room open on port %d. Waiting for player 2..." % MultiplayerManager.DEFAULT_PORT


func _on_join_button_pressed() -> void:
	var address: String = address_input.text.strip_edges()
	if address == "":
		address = "127.0.0.1"
	var error := MultiplayerManager.join_game(address)
	if error == OK:
		status_label.text = "Joining %s..." % address
	else:
		status_label.text = "Join Error: %d" % error


func _on_back_button_pressed() -> void:
	MultiplayerManager.close_connection()
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")


func _on_player_connected(_peer_id: int) -> void:
	if multiplayer.is_server():
		_start_match.rpc()
		_start_match()


func _on_connection_success() -> void:
	status_label.text = "Connected. Waiting for host..."


func _on_connection_failed() -> void:
	status_label.text = "Connection failed"


func _on_server_disconnected() -> void:
	status_label.text = "Server disconnected"


@rpc("authority", "call_remote", "reliable")
func _start_match() -> void:
	get_tree().change_scene_to_file("res://Scenes/MultiplayerDungeonScene.tscn")
