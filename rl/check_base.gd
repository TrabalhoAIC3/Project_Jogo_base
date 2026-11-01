extends SceneTree

func _initialize() -> void:
    print("\n========== DIAGNOSTICO FIGHTER_BASE ==========")

    var script = load("res://rl/fighter_base.gd")

    if script == null:
        printerr("FALHA: fighter_base.gd nao pode ser carregado.")
        quit(1)
        return

    print("fighter_base.gd carregado corretamente.")

    var shooter = load("res://rl/shooter_agent.gd")
    print("Shooter: ", shooter != null)

    var knife = load("res://rl/knife_agent.gd")
    print("KnifeFighter: ", knife != null)

    quit()
