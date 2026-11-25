extends Area2D

@export_enum("Cooldown", "HitOnce", "DisableHitBox")
var HurtBoxType: int = 0

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var DisableTimer: Timer = $DisableTimer

signal hurt(damage)


func _on_area_entered(area: Area2D) -> void:
	# Verifica se a área pertence ao grupo de ataques
	if not area.is_in_group("attack"):
		return

	# Projéteis de uso único avisam antes de aplicar dano, evitando hits duplicados.
	if area.has_method("try_consume") and not area.try_consume():
		return

	# Obtém o dano do ataque
	var attack_damage = area.get("damage")

	if attack_damage == null:
		push_warning("A área de ataque não define dano: %s" % area.get_path())
		return

	var damage: int = int(attack_damage)

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


func _on_disable_timer_timeout() -> void:
	collision.set_deferred("disabled", false)
