extends CharacterBody2D

@export var HP = 10
@export var player_reference : CharacterBody2D

var speed : float = 75

@onready var sprite = $Sprite2D
@onready var walk_timer = $walkTimer


func _physics_process(delta):
	if player_reference == null:
		return

	var direction = (player_reference.global_position - global_position).normalized()

	velocity = direction * speed

	move_and_slide()

	# Virar sprite
	if velocity.x < 0:
		sprite.flip_h = true
	elif velocity.x > 0:
		sprite.flip_h = false

	# Animação
	if velocity != Vector2.ZERO:
		if walk_timer.is_stopped():
			if sprite.frame >= sprite.hframes - 1:
				sprite.frame = 0
			else:
				sprite.frame += 1

			walk_timer.start()
