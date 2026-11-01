extends "res://rl/fighter_base.gd"

@export var projectile_damage: int = 10

const PROJECTILE_SCENE: PackedScene = preload(
    "res://rl/projectile.tscn"
)


func _ready() -> void:
	role_feature = 1.0
	move_speed = 185.0
	rotation_speed = 3.4
	attack_cooldown = 0.35

	super._ready()


func _perform_attack() -> void:
	if not is_instance_valid(opponent) or (opponent.get("is_dead") == true):
		return

	var projectile := PROJECTILE_SCENE.instantiate() as Area2D

	if projectile == null:
		push_error("Nao foi possivel carregar rl/projectile.tscn")
		return

	projectile.set("source_agent", self)
	projectile.set(
		"travel_direction",
		Vector2.RIGHT.rotated(global_rotation)
	)
	projectile.set("damage", projectile_damage)

	var scene_root: Node = get_tree().current_scene

	if scene_root == null:
		scene_root = get_parent()

	scene_root.add_child(projectile)
	projectile.global_position = muzzle.global_position
