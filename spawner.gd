extends Node2D

@export var player: CharacterBody2D
@export var enemy: PackedScene

var distance := 300.0

var minute := 0
var second := 0
var _spawn_serial := 0


func spawn():
	if not is_instance_valid(player):
		return
	_spawn_serial += 1
	var enemy_instance = enemy.instantiate()
	enemy_instance.player_reference = player
	enemy_instance.network_id = "spawn-%s" % _spawn_serial
	var direction := Vector2.RIGHT.rotated(randf_range(0.0, TAU))
	var spawn_radius := randf_range(distance * 0.8, distance)
	var spawn_position := player.global_position + direction * spawn_radius

	# O Spawner tem offset próprio; os inimigos pertencem à raiz do mundo.
	enemy_instance.position = spawn_position
	get_tree().current_scene.call_deferred("add_child", enemy_instance)


func amount(number: int = 1):
	for i in range(number):
		spawn()


func _ready():
	var room: Dictionary = WebSocketClient.current_room
	if room.get("started", false) and str(room.get("host_id", "")) != WebSocketClient.client_id:
		$Timer.stop()
		return
	amount(5)
	var clock: Timer = $Timer
	clock.wait_time = 1.0
	clock.one_shot = false
	clock.timeout.connect(_on_timer_timeout)
	clock.start()


func _on_timer_timeout():
	second += 1

	if second >= 60:
		second = 0
		minute += 1

	%Minute.text = str(minute)
	%Second.text = str(second).pad_zeros(2)

	# Mantém o ritmo legível e aumenta a pressão aos poucos.
	if second % 8 == 0:
		amount(1)
