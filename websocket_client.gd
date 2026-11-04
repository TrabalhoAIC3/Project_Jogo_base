extends Node
## Cliente JSON para o servidor em res://server. Disponível como WebSocketClient.

signal connected
signal disconnected(code: int, reason: String)
signal message_received(message: Dictionary)

@export var server_url: String = "wss://aic-iv-websocket.onrender.com"

var client_id: String = ""
var current_room: Dictionary = {}
var lobby_version: int = 0
var player_name: String = ""
var last_room_code: String = ""
var _socket := WebSocketPeer.new()
var _was_open: bool = false
var _reconnect_attempt := 0
var _reconnect_timer := 0.0


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--server="):
			server_url = argument.trim_prefix("--server=")
	connect_to_server()


func connect_to_server(url: String = "") -> Error:
	if _socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		return ERR_ALREADY_IN_USE
	if not url.is_empty():
		server_url = url
	_socket = WebSocketPeer.new()
	_socket.heartbeat_interval = 20.0
	_was_open = false
	client_id = ""
	current_room = {}
	lobby_version = 0
	var error := _socket.connect_to_url(server_url)
	set_process(error == OK)
	if error != OK:
		push_warning("Não foi possível conectar ao WebSocket: %s" % error_string(error))
	return error


func _process(_delta: float) -> void:
	_socket.poll()
	if _socket.get_ready_state() == WebSocketPeer.STATE_CLOSED and _reconnect_timer > 0:
		_reconnect_timer -= _delta
		if _reconnect_timer <= 0:
			connect_to_server()
		return
	var state := _socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _was_open:
			_was_open = true
			_reconnect_attempt = 0
			print("WebSocket conectado: ", server_url)
			connected.emit()
			send_message({"type": "ping"})
		while _socket.get_available_packet_count() > 0:
			var packet := _socket.get_packet()
			if not _socket.was_string_packet():
				continue
			var parser := JSON.new()
			if parser.parse(packet.get_string_from_utf8()) != OK:
				push_warning("O servidor enviou JSON inválido.")
				continue
			if parser.data is Dictionary:
				var message: Dictionary = parser.data
				if message.get("type") == "welcome":
					client_id = str(message.get("client_id", ""))
					lobby_version = int(message.get("lobby_version", 0))
				elif message.get("type") in ["room_state", "game_started"]:
					current_room = message.get("room", {})
					last_room_code = str(current_room.get("code", last_room_code))
				elif message.get("type") == "room_left":
					current_room = {}
					last_room_code = ""
				print("WebSocket recebeu: ", message)
				message_received.emit(message)
	elif state == WebSocketPeer.STATE_CLOSED:
		_was_open = false
		client_id = ""
		if not current_room.is_empty():
			last_room_code = str(current_room.get("code", last_room_code))
		current_room = {}
		lobby_version = 0
		var code := _socket.get_close_code()
		var reason := _socket.get_close_reason()
		print("WebSocket desconectado: ", code, " ", reason)
		disconnected.emit(code, reason)
		_reconnect_attempt = min(_reconnect_attempt + 1, 6)
		_reconnect_timer = min(2.0 * pow(1.7, _reconnect_attempt - 1), 20.0)


func send_message(message: Dictionary) -> Error:
	if _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return ERR_UNCONFIGURED
	return _socket.send_text(JSON.stringify(message))


func disconnect_from_server() -> void:
	if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_socket.close(1000, "Cliente encerrando")


func is_connected_to_server() -> bool:
	return _socket.get_ready_state() == WebSocketPeer.STATE_OPEN and not client_id.is_empty()


func _exit_tree() -> void:
	disconnect_from_server()
