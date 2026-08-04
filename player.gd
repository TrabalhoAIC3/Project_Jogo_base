extends CharacterBody2D

const SPEED: float = 150.0

var HP = 100

@onready var sprite = $Sprite2D
@onready var walk_timer = $walkTimer

func _physics_process(delta):
	velocity = Input.get_vector("left", "right", "up", "down") * SPEED

	move_and_collide(velocity * delta)

	if velocity.x < 0:
		sprite.flip_h = true
	elif velocity.x > 0:
		sprite.flip_h = false
		
	if velocity != Vector2.ZERO:
		if walk_timer.is_stopped():
			if sprite.frame >= sprite.hframes - 1:
				sprite.frame = 0
			else:
				sprite.frame += 1

			walk_timer.start()
