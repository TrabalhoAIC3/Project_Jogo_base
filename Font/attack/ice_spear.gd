extends Area2D

# =========================
# ATRIBUTOS DO ATAQUE
# =========================

var level: int = 1
var hp: int = 1
var speed: float = 100.0
var damage: int = 5
var knock_amount: int = 100
var attack_size: float = 1.0

# Alvo definido pelo Player antes de adicionar a lança à cena
var target: Vector2 = Vector2.ZERO

# Direção do movimento
var angle: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Registra a lança como um ataque
	add_to_group("attack")

	# Permite a detecção de colisões
	monitoring = true
	monitorable = true

	# Define um alvo padrão caso nenhum tenha sido definido
	if target == Vector2.ZERO:
		target = global_position + Vector2.UP * 100.0

	# Calcula a direção até o alvo
	angle = global_position.direction_to(target)

	# Ajusta a rotação do sprite
	rotation = angle.angle() + deg_to_rad(135.0)

	# =========================
	# CONFIGURAÇÃO POR NÍVEL
	# =========================

	match level:
		1:
			hp = 1
			speed = 100.0
			damage = 5
			knock_amount = 100
			attack_size = 1.0

	# Ajusta o tamanho da lança
	scale = Vector2.ONE * attack_size

	print("ICE SPEAR CRIADA")
	print("Dano da lança: ", damage)


# =========================
# MOVIMENTO
# =========================

func _physics_process(delta: float) -> void:
	global_position += angle * speed * delta


# =========================
# DURABILIDADE DO ATAQUE
# =========================

func enemy_hit(charge: int = 1) -> void:
	hp -= charge

	if hp <= 0:
		queue_free()


# =========================
# DESTRUIR APÓS O TEMPO
# =========================

func _on_timer_timeout() -> void:
	queue_free()
