extends "res://rl/fighter_base.gd"

@export var melee_damage: int = 12
@export var attack_range: float = 48.0
@export var attack_arc_degrees: float = 65.0


func _ready() -> void:
    role_feature = -1.0
    max_hp = 150
    move_speed = 250.0
    rotation_speed = 3.5
    attack_cooldown = 0.4

    super._ready()


func _perform_attack() -> void:
    if not is_instance_valid(opponent):
        return

    if opponent.get("is_dead") == true:
        return

    var distance: float = global_position.distance_to(
        opponent.global_position
    )

    var target_in_local_space: Vector2 = to_local(
        opponent.global_position
    )

    var angle_degrees: float = absf(
        rad_to_deg(target_in_local_space.angle())
    )

    var inside_arc: bool = (
        angle_degrees <= attack_arc_degrees
    )

    if distance <= attack_range and inside_arc:
        print(
            "[MELEE_HIT] KnifeFighter acertou Shooter | ",
            "distancia=", snappedf(distance, 0.1),
            " | angulo=", snappedf(angle_degrees, 0.1),
            " | dano=", melee_damage
        )

        opponent.call("take_damage", melee_damage, self)

    else:
        print(
            "[MELEE_MISS] KnifeFighter errou | ",
            "distancia=", snappedf(distance, 0.1),
            " | angulo=", snappedf(angle_degrees, 0.1),
            " | alcance=", attack_range
        )

        register_missed_attack()
