extends CharacterBody2D

@export var HP: int = 10
@export var player_reference: CharacterBody2D

var network_id := ""
var network_remote := false
var speed: float = 75.0
var _network_target_position := Vector2.ZERO
var _network_position_initialized := false
var _network_animation_elapsed := 0.0

# Força da separação entre os inimigos
@export var separation_weight: float = 2.0

# Cena do cristal de XP
const XP_GEM_SCENE: PackedScene = preload("res://pickups/XPGem.tscn")

# Nós
@onready var sprite = $Sprite2D
@onready var walk_timer = $walkTimer
@onready var separation_area = $SeparationArea
@onready var hurt_box = $HurtBox
@onready var health_bar: ProgressBar = get_node_or_null("HealthBar")


# ==========================================
# INICIALIZAÇÃO
# ==========================================

func _ready():
	add_to_group("enemy")
	if health_bar != null:
		health_bar.max_value = HP
		health_bar.value = HP

	# Conecta o sinal de dano ao inimigo
	# sem duplicar uma conexão que já exista.
	var damage_callable = Callable(self, "_on_hurt_box_hurt")

	if not hurt_box.hurt.is_connected(damage_callable):
		hurt_box.hurt.connect(damage_callable)


func set_network_remote(value: bool) -> void:
	network_remote = value
	var hitbox: Area2D = get_node_or_null("Hitbox")
	if hitbox != null:
		hitbox.monitoring = not value
		hitbox.monitorable = not value


func apply_network_state(position: Vector2, health: int) -> void:
	if network_remote:
		if not _network_position_initialized:
			global_position = position
			_network_position_initialized = true
		_network_target_position = position
	else:
		global_position = position
	HP = health
	if health_bar != null:
		health_bar.value = HP


func take_network_damage(damage: int) -> void:
	if not network_remote:
		_apply_damage(damage)


func _nearest_player() -> Node2D:
	var nearest: Node2D
	var nearest_distance := INF
	for candidate in get_tree().get_nodes_in_group("player"):
		if not candidate is Node2D or candidate.is_queued_for_deletion():
			continue
		var candidate_distance := global_position.distance_squared_to(candidate.global_position)
		if candidate_distance < nearest_distance:
			nearest = candidate
			nearest_distance = candidate_distance
	if nearest == null and is_instance_valid(player_reference):
		nearest = player_reference
	return nearest


# ==========================================
# MOVIMENTO
# ==========================================

func _physics_process(_delta):
	if network_remote or HP <= 0:
		return

	var target := _nearest_player()
	if target == null:
		return

	# ==========================================
	# SEEK
	# ==========================================

	var direction := (target.global_position - global_position).normalized()

	# ==========================================
	# SEPARATION
	# ==========================================

	var separation = Vector2.ZERO

	for other_enemy in separation_area.get_overlapping_bodies():

		# Ignora o próprio inimigo
		if other_enemy == self:
			continue

		# Considera somente outros inimigos
		if not other_enemy.is_in_group("enemy"):
			continue

		# Calcula a distância até o outro inimigo
		var distance_to_enemy = global_position.distance_to(
			other_enemy.global_position
		)

		if distance_to_enemy > 0:

			# Direção para longe do outro inimigo
			var away = (
				global_position - other_enemy.global_position
			).normalized()

			# Quanto mais perto, maior o afastamento
			var strength = 1.0 - (distance_to_enemy / 40.0)

			if strength > 0:
				separation += away * strength

	# ==========================================
	# COMBINA SEEK + SEPARATION
	# ==========================================

	var final_direction = direction

	if separation != Vector2.ZERO:
		final_direction = (
			direction + separation * separation_weight
		).normalized()

	# ==========================================
	# MOVIMENTO
	# ==========================================

	velocity = final_direction * speed

	move_and_slide()

	# ==========================================
	# VIRAR SPRITE
	# ==========================================

	if velocity.x < 0:
		sprite.flip_h = true
	elif velocity.x > 0:
		sprite.flip_h = false

	# ==========================================
	# ANIMAÇÃO
	# ==========================================

	if velocity != Vector2.ZERO:

		if walk_timer.is_stopped():

			if sprite.frame >= sprite.hframes - 1:
				sprite.frame = 0
			else:
				sprite.frame += 1

			walk_timer.start()


func _process(delta: float) -> void:
	if not network_remote or not _network_position_initialized:
		return
	var previous_position := global_position
	global_position = global_position.lerp(_network_target_position, minf(delta * 18.0, 1.0))
	var movement := _network_target_position - previous_position
	if movement.length_squared() > 0.25:
		if absf(movement.x) > 0.1:
			sprite.flip_h = movement.x < 0.0
		_network_animation_elapsed += delta
		if _network_animation_elapsed >= 0.12:
			sprite.frame = (sprite.frame + 1) % sprite.hframes
			_network_animation_elapsed = 0.0
	else:
		sprite.frame = 0
		_network_animation_elapsed = 0.0


# ==========================================
# DANO E MORTE
# ==========================================

func _on_hurt_box_hurt(damage):
	if network_remote:
		if not network_id.is_empty() and WebSocketClient.is_connected_to_server():
			WebSocketClient.send_message({
				"type": "enemy_hit",
				"enemy_id": network_id,
				"damage": int(damage)
			})
		return
	_apply_damage(int(damage))


func _apply_damage(damage: int) -> void:

	# Evita aplicar dano novamente após a morte
	if HP <= 0:
		return

	sprite.modulate = Color("ff7777")
	var hit_flash := create_tween()
	hit_flash.tween_property(sprite, "modulate", Color.WHITE, 0.18)
	HP -= damage

	# Impede HP negativo
	if HP < 0:
		HP = 0

	if health_bar != null:
		health_bar.value = HP

	# ==========================================
	# MORTE DO INIMIGO
	# ==========================================

	if HP <= 0:

		# Guarda a posição da morte
		var death_position = global_position

		# Cria o cristal de XP
		var xp_gem = XP_GEM_SCENE.instantiate()
		xp_gem.network_id = "gem-" + network_id if not network_id.is_empty() else ""

		# Obtém a cena principal
		var scene_root = get_tree().current_scene

		if scene_root != null:

			# Adiciona o cristal à cena
			scene_root.add_child(xp_gem)

			# Posiciona o cristal onde o inimigo morreu
			xp_gem.global_position = death_position

		# Remove o inimigo
		queue_free()
