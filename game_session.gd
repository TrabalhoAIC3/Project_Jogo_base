extends Node2D

const PLAYER_TEXTURE: Texture2D = preload("res://Textures/Player/ImageToStl.com_merged-document(1).png")
const PLAYER_TWO_TEXTURE: Texture2D = preload("res://Textures/Player/player2.png")
const ENEMY_SCENE: PackedScene = preload("res://enemy2.tscn")
const XP_GEM_SCENE: PackedScene = preload("res://pickups/XPGem.tscn")
const POSITION_INTERVAL := 0.05
const WORLD_STATE_INTERVAL := 0.05

var _info: Label
var _xp_info: Label
var _remote_players: Dictionary = {}
var _enemy_nodes: Dictionary = {}
var _gem_nodes: Dictionary = {}
var _local_player: CharacterBody2D
var _position_elapsed := 0.0
var _world_state_elapsed := 0.0


func _ready() -> void:
	_build_hud()
	_local_player = get_node_or_null("Player") as CharacterBody2D
	var room: Dictionary = WebSocketClient.current_room
	_place_local_player(room)
	_add_name_tag(_local_player, WebSocketClient.player_name, Color("ffffff"))
	_configure_enemies()
	_sync_players(room)
	_update_info()
	WebSocketClient.message_received.connect(_on_message)
	WebSocketClient.disconnected.connect(_on_disconnected)
	_send_player_position()


func _physics_process(delta: float) -> void:
	_position_elapsed += delta
	if _position_elapsed >= POSITION_INTERVAL:
		_position_elapsed = 0.0
		_send_player_position()

	if _is_room_host():
		_world_state_elapsed += delta
		if _world_state_elapsed >= WORLD_STATE_INTERVAL:
			_world_state_elapsed = 0.0
			_send_world_state()


func _process(delta: float) -> void:
	for remote in _remote_players.values():
		var target: Vector2 = remote.get_meta("target_position", remote.position)
		var travel: Vector2 = target - remote.position
		remote.position = remote.position.lerp(target, minf(delta * 14.0, 1.0))

		var sprite: Sprite2D = remote.get_node("Sprite2D")
		if travel.length_squared() > 4.0:
			if absf(travel.x) > 1.0:
				sprite.flip_h = travel.x < 0.0
			var animation_time := float(remote.get_meta("animation_time", 0.0)) + delta
			if animation_time >= 0.16:
				sprite.frame = (sprite.frame + 1) % sprite.hframes
				animation_time = 0.0
			remote.set_meta("animation_time", animation_time)
		else:
			sprite.frame = 0
			remote.set_meta("animation_time", 0.0)

	if is_instance_valid(_local_player):
		_xp_info.text = "XP %d" % _local_player.XP


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101a27")
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	panel.add_child(row)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 17)
	row.add_child(_info)
	_xp_info = Label.new()
	_xp_info.add_theme_font_size_override("font_size", 17)
	row.add_child(_xp_info)
	var leave := Button.new()
	leave.text = "Voltar ao lobby"
	leave.pressed.connect(_return_to_lobby)
	row.add_child(leave)


func _configure_enemies() -> void:
	var authority := _is_room_host()
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var id := str(enemy.get("network_id"))
		if id.is_empty():
			id = "scene-enemy"
			enemy.set("network_id", id)
		enemy.call("set_network_remote", not authority)
		_enemy_nodes[id] = enemy


func _is_room_host() -> bool:
	var room: Dictionary = WebSocketClient.current_room
	if not room.get("started", false):
		return true
	return str(room.get("host_id", "")) == WebSocketClient.client_id


func _place_local_player(room: Dictionary) -> void:
	if _local_player == null:
		return
	var players: Array = room.get("players", [])
	for index in range(players.size()):
		var player: Dictionary = players[index]
		if str(player.get("id", "")) == WebSocketClient.client_id:
			_local_player.position = Vector2(527.0 + index * 160.0, 303.0)
			_apply_player_look(_local_player.get_node("Sprite2D") as Sprite2D, index)
			return


func _apply_player_look(sprite: Sprite2D, player_index: int) -> void:
	sprite.hframes = 4
	sprite.modulate = Color.WHITE
	if player_index == 1:
		sprite.texture = PLAYER_TWO_TEXTURE
		sprite.scale = Vector2(0.5, 0.5)
	else:
		sprite.texture = PLAYER_TEXTURE
		sprite.scale = Vector2.ONE


func _add_name_tag(parent: Node2D, player_name: String, color: Color) -> void:
	if parent == null:
		return
	var tag := Label.new()
	tag.name = "PlayerName"
	tag.text = player_name if not player_name.is_empty() else "Jogador"
	tag.position = Vector2(-52, -78)
	tag.size = Vector2(104, 22)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_color_override("font_color", color)
	tag.add_theme_color_override("font_outline_color", Color("101820"))
	tag.add_theme_constant_override("outline_size", 4)
	tag.z_index = 5
	parent.add_child(tag)


func _send_player_position() -> void:
	if not is_instance_valid(_local_player) or not WebSocketClient.is_connected_to_server():
		return
	if not WebSocketClient.current_room.get("started", false):
		return
	WebSocketClient.send_message({
		"type": "game_move",
		"x": _local_player.global_position.x,
		"y": _local_player.global_position.y
	})


func _send_world_state() -> void:
	if not WebSocketClient.is_connected_to_server() or not WebSocketClient.current_room.get("started", false):
		return

	var enemies: Array[Dictionary] = []
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy.has_method("apply_network_state") or enemy.get("network_remote"):
			continue
		if enemy.is_queued_for_deletion():
			continue
		var enemy_id := str(enemy.get("network_id"))
		if enemy_id.is_empty():
			enemy_id = "enemy-%s" % enemy.get_instance_id()
			enemy.set("network_id", enemy_id)
		_enemy_nodes[enemy_id] = enemy
		enemies.append({
			"id": enemy_id,
			"x": enemy.global_position.x,
			"y": enemy.global_position.y,
			"hp": int(enemy.get("HP"))
		})

	var gems: Array[Dictionary] = []
	for gem in get_tree().get_nodes_in_group("xp_gem"):
		if gem.get("network_remote") or gem.is_queued_for_deletion():
			continue
		var id := str(gem.get("network_id"))
		if id.is_empty():
			continue
		gems.append({
			"id": id,
			"x": gem.global_position.x,
			"y": gem.global_position.y,
			"amount": int(gem.get("amount"))
		})

	WebSocketClient.send_message({"type": "game_state", "enemies": enemies, "gems": gems})


func _update_info() -> void:
	var room: Dictionary = WebSocketClient.current_room
	var players: Array = room.get("players", [])
	_info.text = "SALA %s   ·   %d/2 JOGADORES   ·   WASD PARA MOVER" % [
		str(room.get("code", "—")),
		players.size()
	]
	if is_instance_valid(_local_player):
		_xp_info.text = "XP %d" % _local_player.XP


func _on_message(message: Dictionary) -> void:
	match str(message.get("type", "")):
		"room_state", "game_started", "player_move":
			_update_info()
			_sync_players(message.get("room", WebSocketClient.current_room))
		"game_state":
			if not _is_room_host():
				_sync_enemies(message.get("enemies", []))
				_sync_gems(message.get("gems", []))
		"enemy_hit":
			if _is_room_host():
				var enemy: Node = _enemy_nodes.get(str(message.get("enemy_id", "")))
				if is_instance_valid(enemy):
					enemy.call("take_network_damage", int(message.get("damage", 0)))
		"xp_collected":
			_remove_gem(str(message.get("gem_id", "")))
			if str(message.get("player_id", "")) == WebSocketClient.client_id and is_instance_valid(_local_player):
				_local_player.gain_xp(int(message.get("amount", 0)))
				_update_info()


func _sync_players(room: Dictionary) -> void:
	var seen: Dictionary = {}
	var players: Array = room.get("players", [])
	for index in range(players.size()):
		var player: Dictionary = players[index]
		var id := str(player.get("id", ""))
		if id.is_empty() or id == WebSocketClient.client_id:
			continue
		seen[id] = true
		var remote: Node2D = _remote_players.get(id)
		var position := Vector2(float(player.get("x", 0.0)), float(player.get("y", 0.0)))
		if room.get("started", false) and position == Vector2.ZERO:
			position = Vector2(527.0 + index * 160.0, 303.0)
		if remote == null:
			remote = Node2D.new()
			remote.name = "Remote_" + id
			remote.add_to_group("player")
			remote.position = position
			var sprite := Sprite2D.new()
			sprite.name = "Sprite2D"
			_apply_player_look(sprite, index)
			remote.add_child(sprite)
			_add_name_tag(remote, str(player.get("name", "Jogador")), Color("a8ddff"))
			add_child(remote)
			_remote_players[id] = remote
		remote.set_meta("target_position", position)

	for id in _remote_players.keys():
		if not seen.has(id):
			_remote_players[id].queue_free()
			_remote_players.erase(id)


func _sync_enemies(states: Array) -> void:
	var seen: Dictionary = {}
	for state: Dictionary in states:
		var id := str(state.get("id", ""))
		if id.is_empty():
			continue
		seen[id] = true
		var enemy: Node = _enemy_nodes.get(id)
		if enemy == null:
			enemy = ENEMY_SCENE.instantiate()
			enemy.set("network_id", id)
			enemy.set("player_reference", _local_player)
			enemy.call("set_network_remote", true)
			add_child(enemy)
			_enemy_nodes[id] = enemy
		enemy.call("apply_network_state",
			Vector2(float(state.get("x", 0.0)), float(state.get("y", 0.0))),
			int(state.get("hp", 0)))

	for id in _enemy_nodes.keys():
		if not seen.has(id):
			_enemy_nodes[id].queue_free()
			_enemy_nodes.erase(id)


func _sync_gems(states: Array) -> void:
	var seen: Dictionary = {}
	for state: Dictionary in states:
		var id := str(state.get("id", ""))
		if id.is_empty():
			continue
		seen[id] = true
		var gem: Area2D = _gem_nodes.get(id)
		var position := Vector2(float(state.get("x", 0.0)), float(state.get("y", 0.0)))
		if gem == null:
			gem = XP_GEM_SCENE.instantiate()
			gem.set("network_id", id)
			gem.set("network_remote", true)
			gem.set("amount", int(state.get("amount", 10)))
			add_child(gem)
			_gem_nodes[id] = gem
		gem.call("apply_network_position", position)

	for id in _gem_nodes.keys():
		if not seen.has(id):
			_remove_gem(id)


func _remove_gem(id: String) -> void:
	var gem: Node = _gem_nodes.get(id)
	if gem != null:
		gem.queue_free()
		_gem_nodes.erase(id)
	for candidate in get_tree().get_nodes_in_group("xp_gem"):
		if str(candidate.get("network_id")) == id:
			candidate.queue_free()


func _return_to_lobby() -> void:
	WebSocketClient.send_message({"type": "room_leave"})
	get_tree().change_scene_to_file("res://lobby.tscn")


func _on_disconnected(_code: int, _reason: String) -> void:
	get_tree().change_scene_to_file("res://lobby.tscn")
