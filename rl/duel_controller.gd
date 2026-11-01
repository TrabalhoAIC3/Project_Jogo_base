extends AIController2D

@export var observation_scale: float = 800.0
@export var role_feature: float = 1.0

var opponent: Node2D = null

var move_forward: float = 0.0
var strafe: float = 0.0
var turn: float = 0.0
var attack: float = 0.0


func get_obs() -> Dictionary:
    if not is_instance_valid(_player):
        return {"obs": _empty_observations()}

    if not is_instance_valid(opponent):
        return {"obs": _empty_observations()}

    var relative_position: Vector2 = _player.to_local(
        opponent.global_position
    )

    var distance: float = _player.global_position.distance_to(
        opponent.global_position
    )

    var own_hp: float = _get_hp_ratio(_player)
    var enemy_hp: float = _get_hp_ratio(opponent)
    var angle: float = relative_position.angle()

    var observations: Array[float] = [
        clampf(relative_position.x / observation_scale, -1.0, 1.0),
        clampf(relative_position.y / observation_scale, -1.0, 1.0),
        clampf(distance / observation_scale, 0.0, 1.0),
        own_hp,
        enemy_hp,
        sin(angle),
        cos(angle),
        role_feature
    ]

    return {"obs": observations}


func _empty_observations() -> Array[float]:
    return [
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
        role_feature
    ]


func _get_hp_ratio(character: Node2D) -> float:
    var maximum_value: Variant = character.get("max_hp")
    var current_value: Variant = character.get("hp")

    if maximum_value == null or current_value == null:
        return 0.0

    if float(maximum_value) <= 0.0:
        return 0.0

    return clampf(
        float(current_value) / float(maximum_value),
        0.0,
        1.0
    )


func get_reward() -> float:
    return reward


func add_reward(value: float) -> void:
    reward += value


func get_action_space() -> Dictionary:
    return {
        "move_forward": {
            "size": 1,
            "action_type": "continuous"
        },
        "strafe": {
            "size": 1,
            "action_type": "continuous"
        },
        "turn": {
            "size": 1,
            "action_type": "continuous"
        },
        "attack": {
            "size": 1,
            "action_type": "continuous"
        }
    }


func set_action(action: Dictionary) -> void:
    move_forward = _read_action(action, "move_forward")
    strafe = _read_action(action, "strafe")
    turn = _read_action(action, "turn")
    attack = _read_action(action, "attack")


func _read_action(action: Dictionary, key: String) -> float:
    var values: Variant = action.get(key, [0.0])

    if values is Array and not values.is_empty():
        return clampf(float(values[0]), -1.0, 1.0)

    if values is PackedFloat32Array and values.size() > 0:
        return clampf(float(values[0]), -1.0, 1.0)

    return 0.0


func reset() -> void:
    super.reset()

    move_forward = 0.0
    strafe = 0.0
    turn = 0.0
    attack = 0.0
