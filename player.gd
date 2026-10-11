extends CharacterBody2D

const SPEED: float = 150.0

# =========================
# ATAQUE
# =========================

var iceSpear = preload("res://attack/ice_spear.tscn")

@onready var iceSpearTimer = get_node("%iceSpearTimer")
@onready var iceSpearAttackTimer = get_node("%iceSpearAttackTimer")

var icespear_amo: int = 0
var icespear_baseamo: int = 1
var icespear_attackspeed: float = 1.5
var icespear_level: int = 1

# Lista dos inimigos próximos
var enemy_close: Array[Node2D] = []

# =========================
# VIDA
# =========================

@export var HP: int = 100

# =========================
# NÓS
# =========================

@onready var sprite = $Sprite2D
@onready var walk_timer = $walkTimer
@onready var health_bar = $ProgressBar

# Game Over está no mesmo nível do Player
@onready var game_over = get_parent().get_node("GameOver")


func _ready():
	# Configura a barra de vida
	health_bar.max_value = HP
	health_bar.value = HP

	attack()


func _physics_process(_delta):
	velocity = Input.get_vector("left", "right", "up", "down") * SPEED

	move_and_slide()

	# =========================
	# VIRAR SPRITE
	# =========================

	if velocity.x < 0:
		sprite.flip_h = true
	elif velocity.x > 0:
		sprite.flip_h = false

	# =========================
	# ANIMAÇÃO
	# =========================

	if velocity != Vector2.ZERO:
		if walk_timer.is_stopped():

			if sprite.frame >= sprite.hframes - 1:
				sprite.frame = 0
			else:
				sprite.frame += 1

			walk_timer.start()


# ==================================================
# SISTEMA DE ATAQUE
# ==================================================

func attack():

	if icespear_level > 0:

		iceSpearTimer.wait_time = icespear_attackspeed

		if iceSpearTimer.is_stopped():
			iceSpearTimer.start()


# ==================================================
# TIMER QUE GERA A MUNIÇÃO
# ==================================================

func _on_ice_spear_timer_timeout():

	icespear_amo += icespear_baseamo

	if iceSpearAttackTimer.is_stopped():
		iceSpearAttackTimer.start()


# ==================================================
# DISPARAR ICE SPEAR
# ==================================================

func _on_ice_spear_attack_timer_timeout():

	if icespear_amo <= 0:
		return

	# Escolhe o alvo ANTES de adicionar a lança na árvore
	var target_position = get_random_target()

	# Cria a lança
	var icespear_attack = iceSpear.instantiate()

	# IMPORTANTE:
	# Define tudo ANTES do add_child()
	icespear_attack.global_position = global_position
	icespear_attack.target = target_position
	icespear_attack.level = icespear_level

	# Agora adiciona na árvore
	get_parent().add_child(icespear_attack)

	# Diminui munição
	icespear_amo -= 1

	# Se ainda houver munição
	if icespear_amo > 0:
		iceSpearAttackTimer.start()
	else:
		iceSpearAttackTimer.stop()


# ==================================================
# ESCOLHER INIMIGO
# ==================================================

func get_random_target() -> Vector2:

	# Remove inimigos que já foram destruídos
	for enemy in enemy_close.duplicate():

		if not is_instance_valid(enemy):
			enemy_close.erase(enemy)

	# Se houver inimigos próximos
	if enemy_close.size() > 0:

		var enemy = enemy_close.pick_random()

		if is_instance_valid(enemy):
			return enemy.global_position

	# Se não houver inimigo
	# dispara para cima
	return global_position + Vector2.UP * 100.0


# ==================================================
# DETECTOR DE INIMIGOS
# ==================================================

func _on_enemy_detection_area_body_entered(body: Node2D):

	if not is_instance_valid(body):
		return

	if not enemy_close.has(body):

		enemy_close.append(body)

		print("INIMIGO DETECTADO: ", body.name)


func _on_enemy_detection_area_body_exited(body: Node2D):

	if enemy_close.has(body):

		enemy_close.erase(body)

		print("INIMIGO SAIU DO ALCANCE: ", body.name)


# ==================================================
# DANO NO PLAYER
# ==================================================

func _on_hurt_box_hurt(damage):

	print("PLAYER RECEBEU DANO: ", damage)

	HP -= damage

	# Impede que o HP fique negativo
	if HP < 0:
		HP = 0

	# Atualiza a barra de vida
	health_bar.value = HP

	print("HP DO PLAYER: ", HP)

	if HP <= 0:

		print("PLAYER MORREU")

		# Mostra a tela de Game Over
		game_over.show_game_over()

		# Remove o Player
		queue_free()
