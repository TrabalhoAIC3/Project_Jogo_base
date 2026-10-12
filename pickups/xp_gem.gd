extends Area2D

# ==========================================
# CONFIGURAÇÃO DO CRISTAL DE XP
# ==========================================

@export var amount: int = 10


# ==========================================
# INICIALIZAÇÃO
# ==========================================

func _ready() -> void:
	# Ativa a detecção da área
	monitoring = true
	monitorable = true

	# Configura a aparência do cristal
	var crystal: Polygon2D = $Polygon2D

	crystal.polygon = PackedVector2Array([
		Vector2(0, -8),
		Vector2(6, 0),
		Vector2(0, 8),
		Vector2(-6, 0)
	])

	crystal.color = Color("#42F5D7")

	# Conecta o sinal de coleta
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	print("CRISTAL DE XP CRIADO: ", amount, " XP")


# ==========================================
# COLETAR XP
# ==========================================

func _on_body_entered(body: Node2D) -> void:
	# Verifica se o corpo é o jogador
	if not body.is_in_group("player"):
		return

	# Confere se o jogador já possui a função de XP
	if not body.has_method("gain_xp"):
		print("ERRO: o Player ainda não possui a função gain_xp().")
		return

	# Concede experiência
	body.gain_xp(amount)

	print("XP COLETADA: ", amount)

	# Remove o cristal após a coleta
	queue_free()
