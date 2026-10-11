extends CharacterBody2D

@export var HP: int = 1
@export var player_reference: CharacterBody2D

var speed: float = 75.0

# Força da separação entre os inimigos
@export var separation_weight: float = 2.0

# Cena do cristal de XP
const XP_GEM_SCENE: PackedScene = preload("res://pickups/xp_gem.tscn")

@onready var sprite = $Sprite2D
@onready var walk_timer = $walkTimer
@onready var separation_area = $SeparationArea


func _ready():
	add_to_group("enemy")


func _physics_process(delta):
	if player_reference == null:
		return

	# ==========================================
	# SEEK
	# ==========================================

	var direction = (
		player_reference.global_position - global_position
	).normalized()


	# ==========================================
	# SEPARATION
	# ==========================================

	var separation = Vector2.ZERO

	for other_enemy in separation_area.get_overlapping_bodies():

		# Não considerar o próprio inimigo
		if other_enemy == self:
			continue

		# Só considerar outros inimigos
		if not other_enemy.is_in_group("enemy"):
			continue

		# Distância até o outro inimigo
		var distance_to_enemy = global_position.distance_to(
			other_enemy.global_position
		)

		if distance_to_enemy > 0:

			# Direção para longe do outro inimigo
			var away = (
				global_position - other_enemy.global_position
			).normalized()

			# Quanto mais perto, maior a força de afastamento
			var strength = 1.0 - (
				distance_to_enemy / 40.0
			)

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


# ==========================================
# DANO E MORTE
# ==========================================

func _on_hurt_box_hurt(damage):

	# Impede que um inimigo morto receba dano novamente
	if HP <= 0:
		return

	print("INIMIGO RECEBEU DANO: ", damage)

	HP -= damage

	print("HP DO INIMIGO: ", HP)

	# ==========================================
	# MORTE DO INIMIGO
	# ==========================================

	if HP <= 0:

		print("INIMIGO MORREU")

		# Guarda a posição onde o inimigo morreu
		var death_position: Vector2 = global_position

		# Cria o cristal de XP
		var xp_gem = XP_GEM_SCENE.instantiate()

		# Obtém a cena principal
		var scene_root = get_tree().current_scene

		# Adiciona o cristal à cena
		scene_root.add_child(xp_gem)

		# Posiciona o cristal onde o inimigo morreu
		xp_gem.global_position = death_position

		print("CRISTAL DE XP GERADO!")

		# Remove o inimigo
		queue_free()
