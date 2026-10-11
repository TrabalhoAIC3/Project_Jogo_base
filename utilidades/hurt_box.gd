extends Area2D

@export_enum("Cooldown", "HitOnce", "DisableHitBox")
var HurtBoxType: int = 0

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var DisableTimer: Timer = $DisableTimer

signal hurt(damage)


func _on_area_entered(area: Area2D) -> void:

	print(
		"HURTBOX: ", get_path(),
		" | AREA DETECTADA: ", area.name,
		" | CAMINHO: ", area.get_path()
	)

	# Verifica se a área pertence ao grupo de ataques
	if not area.is_in_group("attack"):
		print("Não é um ataque.")
		return

	print("É um ATAQUE!")

	# Obtém o dano do ataque
	var attack_damage = area.get("damage")

	if attack_damage == null:
		print("ERRO: o ataque não possui a variável damage.")
		return

	var damage: int = int(attack_damage)

	print("DANO DETECTADO: ", damage)

	# Aplica o comportamento configurado
	match HurtBoxType:

		0: # Cooldown
			collision.set_deferred("disabled", true)
			DisableTimer.start()

		1: # HitOnce
			pass

		2: # DisableHitBox
			if area.has_method("tempdisable"):
				area.tempdisable()

	# Emite o sinal de dano
	hurt.emit(damage)

	print("SINAL HURT EMITIDO!")


func _on_disable_timer_timeout() -> void:
	collision.set_deferred("disabled", false)
