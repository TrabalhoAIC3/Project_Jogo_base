extends CharacterBody2D

@export var opponent_path: NodePath
@export var max_hp: int = 100
@export var move_speed: float = 180.0
@export var rotation_speed: float = 3.2
@export var attack_cooldown: float = 0.4
@export var role_feature: float = 1.0
@export var arena_half_size: Vector2 = Vector2(386.0, 236.0)

var hp: int = 100
var opponent: Node2D = null
var is_dead: bool = false

var attack_cooldown_remaining: float = 0.0
var spawn_position: Vector2 = Vector2.ZERO
var spawn_rotation: float = 0.0

var ai_controller: Node = null
var muzzle: Marker2D = null
var debug_log_elapsed: float = 0.0
var debug_dodge_active: bool = false


func _ready() -> void:
    add_to_group("rl_fighter")

    spawn_position = global_position
    spawn_rotation = global_rotation
    hp = max_hp

    # Os lutadores nao bloqueiam fisicamente um ao outro.
    # Continuam na camada 1 para receber projeteis.
    collision_layer = 1
    collision_mask = 0

    var body_collision := (
        get_node_or_null("CollisionShape2D") as CollisionShape2D
    )

    if body_collision == null:
        body_collision = CollisionShape2D.new()
        body_collision.name = "CollisionShape2D"
        add_child(body_collision)

    if body_collision.shape == null:
        var rectangle := RectangleShape2D.new()
        rectangle.size = Vector2(28.0, 28.0)
        body_collision.shape = rectangle

    muzzle = get_node_or_null("Muzzle") as Marker2D

    if muzzle == null:
        muzzle = Marker2D.new()
        muzzle.name = "Muzzle"
        add_child(muzzle)

    muzzle.position = Vector2(22.0, 0.0)

    _create_visual()

    opponent = get_node_or_null(opponent_path) as Node2D
    ai_controller = get_node_or_null("AIController2D")

    if ai_controller == null:
        push_error(name + ": faltou o filho AIController2D.")
        set_physics_process(false)
        return

    ai_controller.call("init", self)
    ai_controller.set("opponent", opponent)

    print(
        name,
        " pronto. Oponente: ",
        opponent.name if is_instance_valid(opponent) else "NAO ENCONTRADO"
    )


func _create_visual() -> void:
    var visual := get_node_or_null("Visual") as Polygon2D

    if visual == null:
        visual = Polygon2D.new()
        visual.name = "Visual"
        add_child(visual)

    visual.polygon = PackedVector2Array([
        Vector2(-14.0, -14.0),
        Vector2(14.0, -14.0),
        Vector2(14.0, 14.0),
        Vector2(-14.0, 14.0)
    ])

    if role_feature > 0.0:
        visual.color = Color("#2684FF")
    else:
        visual.color = Color("#FF4D5A")


func _physics_process(delta: float) -> void:
    if not is_instance_valid(ai_controller):
        return

    if (ai_controller.get("needs_reset") == true):
        _reset_episode()
        return

    if is_dead or (ai_controller.get("done") == true):
        velocity = Vector2.ZERO
        return

    if not is_instance_valid(opponent):
        velocity = Vector2.ZERO
        return

    attack_cooldown_remaining = maxf(
        0.0,
        attack_cooldown_remaining - delta
    )

    var move_action: float
    var strafe_action: float
    var turn_action: float
    var attack_action: float

    # Sem Python conectado, o combate usa uma heuristica automatica.
    # Com Python conectado, usamos as acoes recebidas pelo controlador.

    if str(ai_controller.get("heuristic")) == "human":
        var actions: Dictionary = _heuristic_actions()

        move_action = float(actions["move_forward"])
        strafe_action = float(actions["strafe"])
        turn_action = float(actions["turn"])
        attack_action = float(actions["attack"])

    else:
        move_action = clampf(
            float(ai_controller.get("move_forward")),
            -1.0,
            1.0
        )

        strafe_action = clampf(
            float(ai_controller.get("strafe")),
            -1.0,
            1.0
        )

        turn_action = clampf(
            float(ai_controller.get("turn")),
            -1.0,
            1.0
        )

        attack_action = clampf(
            float(ai_controller.get("attack")),
            -1.0,
            1.0
        )

    rotation += turn_action * rotation_speed * delta

    var forward: Vector2 = Vector2.RIGHT.rotated(global_rotation)
    var lateral: Vector2 = Vector2.DOWN.rotated(global_rotation)

    var movement: Vector2 = (
        forward * move_action
        + lateral * strafe_action
    )

    if movement.length() > 1.0:
        movement = movement.normalized()

    var position_before_move: Vector2 = global_position

    velocity = movement * move_speed
    move_and_slide()

    global_position.x = clampf(
        global_position.x,
        -arena_half_size.x,
        arena_half_size.x
    )

    global_position.y = clampf(
        global_position.y,
        -arena_half_size.y,
        arena_half_size.y
    )

    _log_ai_state(
        delta,
        move_action,
        strafe_action,
        turn_action,
        attack_action,
        movement,
        position_before_move
    )

    if attack_action > 0.15 and attack_cooldown_remaining <= 0.0:
        attack_cooldown_remaining = attack_cooldown
        _perform_attack()


func _heuristic_actions() -> Dictionary:
    if not is_instance_valid(opponent):
        return {
            "move_forward": 0.0,
            "strafe": 0.0,
            "turn": 0.0,
            "attack": 0.0
        }

    var target_direction: Vector2 = (
        opponent.global_position - global_position
    )

    var distance: float = target_direction.length()

    var angle: float = wrapf(
        target_direction.angle() - global_rotation,
        -PI,
        PI
    )

    var turn_action: float = clampf(
        angle * 0.85,
        -0.9,
        0.9
    )

    var forward_action: float = 0.0
    var strafe_action: float = 0.0
    var attack_action: float = 0.0

    if role_feature < 0.0:
        # KNIFEFIGHTER: perseguicao.
        if distance > 38.0:
            if absf(angle) < deg_to_rad(120.0):
                forward_action = clampf(
                    cos(angle),
                    0.65,
                    1.0
                )
            else:
                forward_action = 0.0
        else:
            forward_action = 0.0

        # Nao orbita constantemente.
        strafe_action = 0.0

        if (
            distance <= 48.0
            and absf(angle) <= deg_to_rad(60.0)
        ):
            attack_action = 1.0

    else:
        # SHOOTER: distancia, mira e disparo.
        if distance > 320.0:
            forward_action = 0.75
        elif distance < 175.0:
            forward_action = -0.65
        else:
            forward_action = 0.0

        strafe_action = 0.20

        if (
            distance < 500.0
            and absf(angle) <= deg_to_rad(28.0)
        ):
            attack_action = 1.0

    # Esquiva somente projeteis realmente perigosos.
    var dodge_direction: Vector2 = _get_incoming_projectile_dodge()

    debug_dodge_active = (
        dodge_direction.length_squared() > 0.0
    )

    if debug_dodge_active:
        var lateral_axis: Vector2 = Vector2.DOWN.rotated(
            global_rotation
        )

        var lateral_amount: float = dodge_direction.dot(
            lateral_axis
        )

        var dodge_side: float = (
            1.0 if lateral_amount >= 0.0 else -1.0
        )

        # Esquiva moderada, sem cancelar a perseguicao.
        strafe_action = dodge_side * 0.45

        if role_feature < 0.0 and distance > 85.0:
            forward_action = maxf(forward_action, 0.85)

    # Protecao contra os limites da arena.
    var forward_axis: Vector2 = Vector2.RIGHT.rotated(
        global_rotation
    )

    var lateral_axis: Vector2 = Vector2.DOWN.rotated(
        global_rotation
    )

    var desired_world: Vector2 = (
        forward_axis * forward_action
        + lateral_axis * strafe_action
    )

    var margin: float = 45.0

    if global_position.x <= -arena_half_size.x + margin:
        desired_world.x = maxf(desired_world.x, 0.30)

    elif global_position.x >= arena_half_size.x - margin:
        desired_world.x = minf(desired_world.x, -0.30)

    if global_position.y <= -arena_half_size.y + margin:
        desired_world.y = maxf(desired_world.y, 0.30)

    elif global_position.y >= arena_half_size.y - margin:
        desired_world.y = minf(desired_world.y, -0.30)

    forward_action = clampf(
        desired_world.dot(forward_axis),
        -1.0,
        1.0
    )

    strafe_action = clampf(
        desired_world.dot(lateral_axis),
        -1.0,
        1.0
    )

    return {
        "move_forward": forward_action,
        "strafe": strafe_action,
        "turn": turn_action,
        "attack": attack_action
    }


func _get_incoming_projectile_dodge() -> Vector2:
    var nearest_time: float = INF
    var selected_direction: Vector2 = Vector2.ZERO

    for projectile in get_tree().get_nodes_in_group("rl_projectile"):
        if not is_instance_valid(projectile):
            continue

        var source_agent: Variant = projectile.get("source_agent")

        if source_agent == self:
            continue

        var direction_value: Variant = projectile.get(
            "travel_direction"
        )

        if not direction_value is Vector2:
            continue

        var projectile_direction: Vector2 = direction_value

        if projectile_direction.length_squared() < 0.5:
            continue

        projectile_direction = projectile_direction.normalized()

        var speed_value: Variant = projectile.get("speed")
        var projectile_speed: float = 520.0

        if speed_value != null:
            projectile_speed = maxf(float(speed_value), 1.0)

        var relative: Vector2 = (
            global_position - projectile.global_position
        )

        var ahead: float = relative.dot(projectile_direction)

        if ahead <= 0.0:
            continue

        var time_to_impact: float = ahead / projectile_speed

        # Aumenta a exigencia para evitar esquivas desnecessarias.
        if time_to_impact > 0.28:
            continue

        var miss_distance: float = absf(
            projectile_direction.cross(relative)
        )

        if miss_distance > 18.0:
            continue

        if time_to_impact < nearest_time:
            nearest_time = time_to_impact

            var cross_value: float = (
                projectile_direction.cross(relative)
            )

            var side_sign: float = (
                1.0 if cross_value >= 0.0 else -1.0
            )

            selected_direction = (
                projectile_direction.orthogonal() * side_sign
            ).normalized()

    return selected_direction


func _log_ai_state(
    delta: float,
    forward_action: float,
    strafe_action: float,
    turn_action: float,
    attack_action: float,
    requested_movement: Vector2,
    position_before: Vector2
) -> void:

    debug_log_elapsed += delta

    # Um registro por segundo para cada lutador.
    if debug_log_elapsed < 1.0:
        return

    debug_log_elapsed = 0.0

    var target_distance: float = -1.0
    var target_angle: float = 0.0

    if is_instance_valid(opponent):
        target_distance = global_position.distance_to(
            opponent.global_position
        )

        var local_target: Vector2 = to_local(
            opponent.global_position
        )

        target_angle = rad_to_deg(local_target.angle())

    var actual_displacement: Vector2 = (
        global_position - position_before
    )

    var collisions: Array[String] = []

    for index in range(get_slide_collision_count()):
        var collision: KinematicCollision2D = get_slide_collision(index)
        var collider: Object = collision.get_collider()

        var collider_name: String = str(collider)

        if collider is Node:
            collider_name = str(collider.name)

        collisions.append(
            collider_name
            + " normal="
            + str(collision.get_normal())
        )

    var apparently_stuck: bool = (
        requested_movement.length() > 0.1
        and actual_displacement.length() < 0.5
    )

    print(
        "[AI_DEBUG] ",
        name,
        " | role=", role_feature,
        " | heuristic=", ai_controller.get("heuristic"),
        " | pos=", global_position,
        " | target_distance=", snappedf(target_distance, 0.1),
        " | target_angle=", snappedf(target_angle, 0.1),
        " | actions: forward=", snappedf(forward_action, 0.01),
        " strafe=", snappedf(strafe_action, 0.01),
        " turn=", snappedf(turn_action, 0.01),
        " attack=", snappedf(attack_action, 0.01),
        " | velocity=", velocity,
        " | requested_movement=", requested_movement,
        " | actual_displacement=", actual_displacement,
        " | collisions=", collisions,
        " | collision_layer=", collision_layer,
        " | collision_mask=", collision_mask,
        " | on_wall=", is_on_wall(),
        " | stuck=", apparently_stuck,
        " | dodge_active=", debug_dodge_active,
        " | hp=", hp,
        " | attack_cd=", snappedf(attack_cooldown_remaining, 0.01)
    )


func _perform_attack() -> void:
    pass


func take_damage(amount: int, attacker: Node2D) -> void:
    if is_dead:
        return

    hp = maxi(0, hp - maxi(0, amount))

    # Penalidade por receber dano.
    _add_reward(self, -0.15)

    # Recompensa por acertar o adversario.
    if is_instance_valid(attacker) and attacker != self:
        _add_reward(attacker, 0.5 + float(amount) * 0.05)

    if hp <= 0:
        is_dead = true
        velocity = Vector2.ZERO

        _add_reward(self, -3.0)

        if is_instance_valid(attacker) and attacker != self:
            _add_reward(attacker, 5.0)

        _finish_episode()
        print(name, " foi derrotado.")


func register_missed_attack() -> void:
    if not is_dead:
        _add_reward(self, -0.025)


func _add_reward(fighter: Node2D, amount: float) -> void:
    if not is_instance_valid(fighter):
        return

    var controller := fighter.get_node_or_null("AIController2D")

    if is_instance_valid(controller) and controller.has_method("add_reward"):
        controller.call("add_reward", amount)


func _finish_episode() -> void:
    for fighter in get_tree().get_nodes_in_group("rl_fighter"):
        var controller := fighter.get_node_or_null("AIController2D")

        if is_instance_valid(controller):
            controller.set("done", true)
            controller.set("needs_reset", true)


func _reset_episode() -> void:
    global_position = spawn_position
    global_rotation = spawn_rotation
    velocity = Vector2.ZERO

    hp = max_hp
    is_dead = false
    attack_cooldown_remaining = 0.0

    if is_instance_valid(ai_controller):
        ai_controller.call("reset")

        # Sem servidor de treino, precisamos continuar a luta de teste.
        # Durante o treinamento, o Sync controla o encerramento do episodio.
        if str(ai_controller.get("heuristic")) == "human":
            ai_controller.set("done", false)
