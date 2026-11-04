extends Node2D

var _info: Label
var _remote_players: Dictionary = {}


func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	layer.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	panel.add_child(row)
	_info = Label.new()
	row.add_child(_info)
	var leave := Button.new()
	leave.text = "Voltar ao lobby"
	leave.pressed.connect(_return_to_lobby)
	row.add_child(leave)
	_update_info()
	_sync_players(WebSocketClient.current_room)
	WebSocketClient.message_received.connect(_on_message)
	WebSocketClient.disconnected.connect(_on_disconnected)


func _update_info() -> void:
	var room := WebSocketClient.current_room
	_info.text = "Sala %s  ·  %s jogador(es)  ·  WASD para mover" % [room.get("code", "—"), room.get("players", []).size()]


func _on_message(message: Dictionary) -> void:
	if message.get("type") in ["room_state", "game_started", "player_move"]:
		_update_info()
		_sync_players(message.get("room", WebSocketClient.current_room))

func _sync_players(room: Dictionary) -> void:
	for player: Dictionary in room.get("players", []):
		var id := str(player.get("id", ""))
		if id.is_empty() or id == WebSocketClient.client_id:
			continue
		var remote: Node2D = _remote_players.get(id)
		if remote == null:
			remote = Node2D.new()
			remote.name = "Remote_" + id
			var body := Polygon2D.new()
			body.polygon = PackedVector2Array([Vector2(-16, -20), Vector2(16, -20), Vector2(16, 20), Vector2(-16, 20)])
			body.color = Color("e67e9b")
			remote.add_child(body)
			add_child(remote)
			_remote_players[id] = remote
		remote.position = Vector2(float(player.get("x", 0)), float(player.get("y", 0)))
	for id in _remote_players.keys():
		var exists := false
		for player: Dictionary in room.get("players", []):
			if str(player.get("id", "")) == id:
				exists = true
		if not exists:
			_remote_players[id].queue_free()
			_remote_players.erase(id)


func _return_to_lobby() -> void:
	WebSocketClient.send_message({"type": "room_leave"})
	get_tree().change_scene_to_file("res://lobby.tscn")


func _on_disconnected(_code: int, _reason: String) -> void:
	get_tree().change_scene_to_file("res://lobby.tscn")
