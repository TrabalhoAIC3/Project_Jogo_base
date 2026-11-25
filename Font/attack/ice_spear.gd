extends Area2D

# =========================
# ATRIBUTOS DO ATAQUE
# =========================

var level: int = 1
var hp: int = 1
var speed: float = 520.0
var damage: int = 5
var knock_amount: int = 100
var attack_size: float = 1.0

# Alvo definido pelo Player antes de adicionar a lança à cena
var target: Node2D

# Direção do movimento
var angle: Vector2 = Vector2.ZERO
var _spent := false


func _ready() -> void:
	# Registra a lança como um ataque
	add_to_group("attack")

	# Permite a detecção de colisões
	monitoring = true
	monitorable = true

	# =========================
	# CONFIGURAÇÃO POR NÍVEL
	# =========================

	match level:
		1:
			hp = 1
			speed = 520.0
			damage = 5
			knock_amount = 100
			attack_size = 1.0

	# Ajusta o tamanho da lança
	scale = Vector2.ONE * attack_size

	_update_direction()


# =========================
# MOVIMENTO
# =========================

func _physics_process(delta: float) -> void:
	_update_direction()
	global_position += angle * speed * delta


func _update_direction() -> void:
	if is_instance_valid(target) and not target.is_queued_for_deletion():
		angle = global_position.direction_to(target.global_position)
	elif angle == Vector2.ZERO:
		angle = Vector2.UP
	# A textura aponta na diagonal; compensamos 45 graus para alinhar a ponta.
	rotation = angle.angle() + PI / 4.0


# =========================
# DURABILIDADE DO ATAQUE
# =========================

func enemy_hit(charge: int = 1) -> void:
	if _spent:
		return
	hp -= charge
	if hp <= 0:
		_spent = true
		queue_free()


func try_consume() -> bool:
	if _spent:
		return false
	hp -= 1
	if hp <= 0:
		_spent = true
		queue_free()
	return true


# =========================
# DESTRUIR APÓS O TEMPO
# =========================

func _on_timer_timeout() -> void:
	queue_free()
