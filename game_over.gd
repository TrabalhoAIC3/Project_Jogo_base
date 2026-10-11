extends CanvasLayer

@onready var restart_button: Button = $RestartButton


func _ready():
	# Game Over começa escondido
	visible = false

	# Permite que o Game Over continue funcionando
	# mesmo quando o jogo estiver pausado
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Conecta o botão ao código
	restart_button.pressed.connect(_on_restart_button_pressed)


func show_game_over():
	# Mostra a tela
	visible = true

	# Pausa o jogo
	get_tree().paused = true


func _on_restart_button_pressed():
	# Despausa antes de reiniciar
	get_tree().paused = false

	# Recarrega a cena atual
	get_tree().reload_current_scene()
