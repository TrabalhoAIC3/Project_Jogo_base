extends Node

const INFERENCER_PATH := \
    "res://addons/godot_rl_agents/onnx/csharp/ONNXInference.cs"

const MODEL_PATH := \
    "res://models/duel_inference_embedded.onnx"


func _ready() -> void:
    print("\n========== TESTE C# ONNX ==========")

    if not FileAccess.file_exists(MODEL_PATH):
        printerr("ERRO: modelo ONNX nao encontrado.")
        get_tree().quit(1)
        return

    print("Carregando classe C#...")

    var inferencer_script: Variant = load(INFERENCER_PATH)

    if inferencer_script == null:
        printerr("ERRO: nao foi possivel carregar ONNXInference.cs.")
        get_tree().quit(1)
        return

    print("Script: ", inferencer_script)
    print("Pode instanciar: ", inferencer_script.can_instantiate())

    if not inferencer_script.can_instantiate():
        printerr("ERRO: classe C# nao pode ser instanciada.")
        get_tree().quit(1)
        return

    print("\nCriando instancia...")

    var inferencer: Variant = inferencer_script.new()

    if inferencer == null:
        printerr("ERRO: instancia C# retornou null.")
        get_tree().quit(1)
        return

    print("Instancia criada: ", inferencer)

    print("\nInicializando ONNX...")

    var output_size: Variant = inferencer.call(
        "Initialize",
        MODEL_PATH,
        1
    )

    print("Tamanho da saida: ", output_size)

    if output_size == null or int(output_size) <= 0:
        printerr("ERRO: tamanho de saida invalido.")
        get_tree().quit(1)
        return

    print("\nExecutando inferencia...")

    var observations: Array[float] = [
        0.0,
        0.0,
        0.5,
        1.0,
        1.0,
        0.0,
        1.0,
        1.0
    ]

    var result: Variant = inferencer.call(
        "RunInference",
        observations,
        0
    )

    print("Resultado: ", result)

    if result == null:
        printerr("ERRO: inferencia retornou null.")
        inferencer.call("FreeDisposables")
        inferencer.free()
        get_tree().quit(1)
        return

    if not result is Dictionary:
        printerr("ERRO: resultado nao e Dictionary.")
        inferencer.call("FreeDisposables")
        inferencer.free()
        get_tree().quit(1)
        return

    if not result.has("output"):
        printerr("ERRO: saida 'output' nao encontrada.")
        inferencer.call("FreeDisposables")
        inferencer.free()
        get_tree().quit(1)
        return

    print("\nSUCESSO: inferenciador ONNX funcionando!")

    inferencer.call("FreeDisposables")
    inferencer.free()

    get_tree().quit()
