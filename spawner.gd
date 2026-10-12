extends Node2D

@export var player: CharacterBody2D
@export var enemy: PackedScene

var distance := 300.0

var minute := 0
var second := 0


func spawn():
	var enemy_instance = enemy.instantiate()

	enemy_instance.player_reference = player

	enemy_instance.global_position = player.global_position + Vector2(
		randf_range(-distance, distance),
		randf_range(-distance, distance)
	)

	add_child(enemy_instance)


func amount(number: int = 1):
	for i in range(number):
		spawn()


func _ready():
	amount(5)


func _on_timer_timeout():
	second += 1

	if second >= 60:
		second = 0
		minute += 1

	%Minute.text = str(minute)
	%Second.text = str(second).pad_zeros(2)

	amount(1)
