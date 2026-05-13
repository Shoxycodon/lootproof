extends Node

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal connection_failed
signal connection_success
signal server_disconnected

const DEFAULT_PORT := 10567
const MAX_CLIENTS := 1

var peer: ENetMultiplayerPeer
var last_error_message := ""
var _signals_connected := false


func host_game(port: int = DEFAULT_PORT) -> Error:
	_close_existing_peer()
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_CLIENTS)
	if error != OK:
		last_error_message = "Host error: %d" % error
		return error
	multiplayer.multiplayer_peer = peer
	_setup_signals()
	return OK


func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	_close_existing_peer()
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		last_error_message = "Join error: %d" % error
		return error
	multiplayer.multiplayer_peer = peer
	_setup_signals()
	return OK


func close_connection() -> void:
	_close_existing_peer()
	multiplayer.multiplayer_peer = null


func is_online() -> bool:
	return multiplayer.multiplayer_peer != null


func _setup_signals() -> void:
	if _signals_connected:
		return
	multiplayer.peer_connected.connect(func(id: int) -> void: player_connected.emit(id))
	multiplayer.peer_disconnected.connect(func(id: int) -> void: player_disconnected.emit(id))
	multiplayer.connected_to_server.connect(func() -> void: connection_success.emit())
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_signals_connected = true


func _close_existing_peer() -> void:
	if peer:
		peer.close()
	peer = null


func _on_connection_failed() -> void:
	last_error_message = "Connection failed."
	connection_failed.emit()


func _on_server_disconnected() -> void:
	last_error_message = "Server disconnected."
	server_disconnected.emit()
