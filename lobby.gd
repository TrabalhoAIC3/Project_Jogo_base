extends Control

const ACCENT := Color("a5ef72")
const MUTED := Color("98a7bb")
var name_input: LineEdit
var code_input: LineEdit
var status: Label
var feedback: Label
var rooms_list: VBoxContainer
var players_list: VBoxContainer
var room_title: Label
var create_button: Button
var join_button: Button
var ready_button: Button
var start_button: Button
var leave_button: Button
var copy_button: Button
var busy := false
var request_timer: Timer


func _ready() -> void:
	_build_ui()
	WebSocketClient.message_received.connect(_on_message)
	WebSocketClient.disconnected.connect(_on_disconnected)
	request_timer = Timer.new()
	request_timer.one_shot = true
	request_timer.wait_time = 12.0
	request_timer.timeout.connect(func():
		busy = false
		feedback.text = "O servidor demorou a responder. Reconecte e tente novamente."
		_update_controls())
	add_child(request_timer)
	var refresh_timer := Timer.new()
	refresh_timer.wait_time = 5.0
	refresh_timer.timeout.connect(_refresh_rooms)
	add_child(refresh_timer)
	refresh_timer.start()
	if WebSocketClient.is_connected_to_server():
		_online()
	_render_room()
	_update_controls()


func _build_ui() -> void:
	var skin := Theme.new()
	skin.default_font_size = 18
	skin.set_color("font_color", "Label", Color("eaf0f8"))
	skin.set_color("font_color", "Button", Color("eaf0f8"))
	skin.set_color("font_disabled_color", "Button", Color("657085"))
	skin.set_stylebox("normal", "Button", _box(Color("24344a")))
	skin.set_stylebox("hover", "Button", _box(Color("344a63")))
	skin.set_stylebox("pressed", "Button", _box(Color("416039")))
	skin.set_stylebox("disabled", "Button", _box(Color("172234")))
	skin.set_stylebox("normal", "LineEdit", _box(Color("0c1420")))
	skin.set_stylebox("focus", "LineEdit", _box(Color("162737"), ACCENT))
	skin.set_color("font_color", "LineEdit", Color("eaf0f8"))
	theme = skin
	var background := ColorRect.new()
	background.color = Color("0b111b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := _label("SURVIVAL ARENA", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	status = _label("Conectando ao servidor…", 16, MUTED)
	header.add_child(status)
	header.add_child(_button("Reconectar", _reconnect))
	layout.add_child(_label("Monte sua equipe. Prepare-se para sobreviver.", 18, MUTED))
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 20)
	layout.add_child(columns)
	var browse := _panel(columns)
	browse.add_child(_label("ENCONTRE SUA EQUIPE", 22, ACCENT))
	browse.add_child(_label("Seu nome", 16, MUTED))
	name_input = LineEdit.new()
	name_input.placeholder_text = "Como você quer ser chamado?"
	name_input.max_length = 24
	name_input.text = WebSocketClient.player_name
	name_input.custom_minimum_size.y = 44
	browse.add_child(name_input)
	create_button = _button("+ Criar sala", _create_room)
	browse.add_child(create_button)
	browse.add_child(_label("Ou entre com o código da sala", 16, MUTED))
	var join_row := HBoxContainer.new()
	browse.add_child(join_row)
	code_input = LineEdit.new()
	code_input.placeholder_text = "Ex.: A1B2C3"
	code_input.max_length = 6
	code_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_input.text_submitted.connect(func(_text: String): _join_room(code_input.text))
	join_row.add_child(code_input)
	join_button = _button("Entrar", func(): _join_room(code_input.text))
	join_row.add_child(join_button)
	var rooms_header := HBoxContainer.new()
	browse.add_child(rooms_header)
	var rooms_title := _label("SALAS DISPONÍVEIS", 18)
	rooms_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rooms_header.add_child(rooms_title)
	rooms_header.add_child(_button("Atualizar", _refresh_rooms))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	browse.add_child(scroll)
	rooms_list = VBoxContainer.new()
	rooms_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rooms_list)
	rooms_list.add_child(_label("Aguardando conexão…", 16, MUTED))
	var team := _panel(columns)
	room_title = _label("SUA SALA", 26, ACCENT)
	team.add_child(room_title)
	team.add_child(_label("Até 2 sobreviventes por equipe", 17, MUTED))
	copy_button = _button("Copiar código", func():
		DisplayServer.clipboard_set(str(WebSocketClient.current_room.get("code", "")))
		feedback.text = "Código copiado. Envie para sua equipe!")
	team.add_child(copy_button)
	var players_scroll := ScrollContainer.new()
	players_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	players_scroll.custom_minimum_size.y = 130
	team.add_child(players_scroll)
	players_list = VBoxContainer.new()
	players_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	players_list.add_theme_constant_override("separation", 12)
	players_scroll.add_child(players_list)
	ready_button = _button("Marcar Pronto", _toggle_ready)
	team.add_child(ready_button)
	start_button = _button("Iniciar partida", func(): _request({"type": "game_start"}))
	team.add_child(start_button)
	leave_button = _button("Sair da sala", func(): _request({"type": "room_leave"}))
	team.add_child(leave_button)
	feedback = _label("O anfitrião inicia quando todos estiverem prontos.", 16, MUTED)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(feedback)
	layout.add_child(_label("ATÉ 2 JOGADORES  /  CONEXÃO ONLINE", 13, MUTED))


func _box(color: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(8)
	box.set_content_margin_all(12)
	box.border_color = border
	box.set_border_width_all(1)
	return box


func _panel(parent: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(Color("131e2d")))
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	return content


func _label(text: String, font_size: int = 18, color: Color = Color("eaf0f8")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	button.pressed.connect(action)
	return button


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _request(message: Dictionary) -> void:
	if busy:
		return
	if WebSocketClient.send_message(message) != OK:
		feedback.text = "Sem conexão. Clique em Reconectar."
		return
	busy = true
	request_timer.start()
	feedback.text = "Aguardando servidor…"
	_update_controls()


func _valid_name() -> bool:
	var value := name_input.text.strip_edges()
	if value.is_empty():
		feedback.text = "Digite seu nome para criar ou entrar em uma sala."
		name_input.grab_focus()
		return false
	WebSocketClient.player_name = value
	return true


func _create_room() -> void:
	if _valid_name():
		_request({"type": "room_create", "name": WebSocketClient.player_name})


func _join_room(code: String) -> void:
	if not _valid_name():
		return
	if code.strip_edges().length() != 6:
		feedback.text = "Digite o código de 6 caracteres da sala."
		return
	_request({"type": "room_join", "code": code.strip_edges().to_upper(), "name": WebSocketClient.player_name})


func _refresh_rooms() -> void:
	if WebSocketClient.is_connected_to_server() and WebSocketClient.lobby_version >= 1:
		WebSocketClient.send_message({"type": "lobby_list"})


func _toggle_ready() -> void:
	for player: Dictionary in WebSocketClient.current_room.get("players", []):
		if player.get("id") == WebSocketClient.client_id:
			_request({"type": "room_ready", "ready": not bool(player.get("ready", false))})
			return


func _online() -> void:
	if WebSocketClient.lobby_version < 1:
		status.text = "Servidor aguardando atualização"
		feedback.text = "Aguarde o deploy do lobby e reconecte."
	else:
		status.text = "● Online"
		_refresh_rooms()
		if WebSocketClient.last_room_code != "" and not WebSocketClient.player_name.is_empty():
			_request({"type": "room_join", "code": WebSocketClient.last_room_code, "name": WebSocketClient.player_name})


func _on_message(message: Dictionary) -> void:
	match str(message.get("type", "")):
		"welcome":
			_online()
		"rooms_list":
			_clear(rooms_list)
			var rooms: Array = message.get("rooms", [])
			if rooms.is_empty():
				rooms_list.add_child(_label("Nenhuma sala. Seja o primeiro a criar!", 16, MUTED))
			for room: Dictionary in rooms:
				var code := str(room.get("code", ""))
				var capacity := int(room.get("capacity", 2))
				var button := _button("%s · %s · %s/%s" % [code, room.get("host_name", ""), room.get("player_count", 0), capacity], _join_room.bind(code))
				button.clip_text = true
				button.set_meta("full", int(room.get("player_count", 0)) >= capacity)
				rooms_list.add_child(button)
		"room_state":
			_finish_request()
			_render_room()
			feedback.text = "Compartilhe o código e marque Pronto quando estiver preparado."
		"room_left":
			_finish_request()
			_render_room()
			_refresh_rooms()
			feedback.text = "Você saiu da sala."
		"game_started":
			_finish_request()
			get_tree().change_scene_to_file("res://test_scene.tscn")
		"error":
			_finish_request()
			feedback.text = str(message.get("message", "Não foi possível concluir."))
	_update_controls()


func _finish_request() -> void:
	busy = false
	request_timer.stop()


func _on_disconnected(_code: int, _reason: String) -> void:
	_finish_request()
	status.text = "● Desconectado"
	feedback.text = "A conexão caiu. Reconecte para entrar em uma nova sala."
	_clear(rooms_list)
	_render_room()
	_update_controls()


func _reconnect() -> void:
	if WebSocketClient.is_connected_to_server():
		WebSocketClient.disconnect_from_server()
		feedback.text = "Encerrando conexão. Clique em Reconectar novamente."
		return
	var error := WebSocketClient.connect_to_server()
	status.text = "Conectando…"
	feedback.text = "A primeira conexão pode demorar enquanto o servidor inicia."
	if error == ERR_ALREADY_IN_USE:
		feedback.text = "A conexão ainda está em andamento. Aguarde."
	_update_controls()


func _render_room() -> void:
	_clear(players_list)
	var room := WebSocketClient.current_room
	if room.is_empty():
		room_title.text = "SUA SALA"
		players_list.add_child(_label("Crie uma sala ou entre na equipe\nde um amigo.", 18, MUTED))
		return
	room_title.text = "SALA  " + str(room.get("code", ""))
	for player: Dictionary in room.get("players", []):
		var suffix := "  ·  ANFITRIÃO" if player.get("id") == room.get("host_id") else ""
		if player.get("id") == WebSocketClient.client_id:
			suffix += "  ·  VOCÊ"
		var ready := bool(player.get("ready", false))
		var player_label := _label(str(player.get("name", "")) + suffix, 18)
		player_label.clip_text = true
		player_label.tooltip_text = player_label.text
		players_list.add_child(player_label)
		players_list.add_child(_label("● Pronto" if ready else "○ Preparando…", 15, ACCENT if ready else MUTED))
	for index in range(room.get("players", []).size(), int(room.get("capacity", 2))):
		players_list.add_child(_label("+ Vaga disponível", 17, Color("52647a")))


func _update_controls() -> void:
	var online := WebSocketClient.is_connected_to_server() and WebSocketClient.lobby_version >= 1
	var room := WebSocketClient.current_room
	var inside := not room.is_empty()
	create_button.disabled = not online or inside or busy
	join_button.disabled = create_button.disabled
	name_input.editable = not inside and not busy
	code_input.editable = not inside and not busy
	copy_button.disabled = not inside
	leave_button.disabled = not inside or busy
	ready_button.disabled = not inside or busy
	ready_button.text = "Marcar Pronto"
	var all_ready := inside
	for player: Dictionary in room.get("players", []):
		all_ready = all_ready and bool(player.get("ready", false))
		if player.get("id") == WebSocketClient.client_id:
			ready_button.text = "Cancelar Pronto" if player.get("ready", false) else "Marcar Pronto"
	start_button.disabled = not all_ready or room.get("host_id", "") != WebSocketClient.client_id or busy
	start_button.text = "Iniciar partida" if room.get("host_id", "") == WebSocketClient.client_id else "Aguardando anfitrião"
	for child in rooms_list.get_children():
		if child is Button:
			child.disabled = not online or inside or busy or bool(child.get_meta("full", false))
