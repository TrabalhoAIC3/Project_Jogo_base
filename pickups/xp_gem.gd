extends Area2D

@export var amount: int = 10

const MAGNET_RADIUS := 190.0
const PICKUP_RADIUS := 30.0
const MAGNET_SPEED := 300.0

var network_id := ""
var network_remote := false
var _collection_requested := false
var _retry_elapsed := 0.0


func _ready() -> void:
	add_to_group("xp_gem")
	monitoring = true
	monitorable = true
	$Polygon2D.polygon = PackedVector2Array([
		Vector2(0, -8),
		Vector2(6, 0),
		Vector2(0, 8),
		Vector2(-6, 0)
	])
	$Polygon2D.color = Color("42f5d7")
	$Polygon2D.scale = Vector2(1.5, 1.5)


func _process(delta: float) -> void:
	if _collection_requested:
		_retry_elapsed += delta
		if _retry_elapsed < 0.5:
			return
		_retry_elapsed = 0.0
		_send_collection_request()
		return

	var local_players := get_tree().get_nodes_in_group("local_player")
	if local_players.is_empty():
		return
	var player := local_players[0] as Node2D
	if not is_instance_valid(player):
		return

	var distance := global_position.distance_to(player.global_position)
	if distance <= MAGNET_RADIUS:
		global_position = global_position.move_toward(player.global_position, MAGNET_SPEED * delta)
	if global_position.distance_to(player.global_position) > PICKUP_RADIUS:
		return

	if WebSocketClient.is_connected_to_server() and WebSocketClient.current_room.get("started", false):
		if network_id.is_empty():
			network_id = "xp-%s" % get_instance_id()
		_send_collection_request()
		return

	if player.has_method("gain_xp"):
		player.gain_xp(amount)
	queue_free()


func _send_collection_request() -> void:
	var result := WebSocketClient.send_message({
		"type": "xp_collect",
		"gem_id": network_id
	})
	_collection_requested = result == OK


func apply_network_position(position: Vector2) -> void:
	if network_remote:
		global_position = position
