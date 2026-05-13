extends Control

@onready var start_button := $StartButton
@onready var host_button := $HostButton
@onready var join_button := $JoinButton
@onready var address_input := $AddressInput
@onready var status_label := $StatusLabel


func _ready() -> void:
	host_button.grab_focus()
	MultiplayerManager.connection_success.connect(_on_connection_success)
	MultiplayerManager.connection_failed.connect(_on_connection_failed)
	MultiplayerManager.server_disconnected.connect(_on_server_disconnected)
	if MultiplayerManager.last_error_message != "":
		status_label.text = MultiplayerManager.last_error_message
		MultiplayerManager.last_error_message = ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump") or event.is_action_pressed("interact"):
		_on_start_button_pressed()


func _on_start_button_pressed() -> void:
	MultiplayerManager.close_connection()
	get_tree().change_scene_to_file("res://Scenes/DungeonScene.tscn")


func _on_host_button_pressed() -> void:
	var error := MultiplayerManager.host_game()
	if error != OK:
		status_label.text = "Host Error: %d" % error
		return
	status_label.text = "Hosting on port %d..." % MultiplayerManager.DEFAULT_PORT
	if not MultiplayerManager.player_connected.is_connected(_on_player_connected):
		MultiplayerManager.player_connected.connect(_on_player_connected)


func _on_join_button_pressed() -> void:
	var address: String = address_input.text.strip_edges()
	if address == "":
		address = "127.0.0.1"
	var error := MultiplayerManager.join_game(address)
	if error == OK:
		status_label.text = "Connecting to %s..." % address
	else:
		status_label.text = "Join Error: %d" % error


func _on_player_connected(_peer_id: int) -> void:
	_start_game()


func _on_connection_success() -> void:
	_start_game()


func _on_connection_failed() -> void:
	status_label.text = "Connection failed"


func _on_server_disconnected() -> void:
	status_label.text = "Server disconnected"


func _start_game() -> void:
	get_tree().change_scene_to_file("res://Scenes/DungeonScene.tscn")
