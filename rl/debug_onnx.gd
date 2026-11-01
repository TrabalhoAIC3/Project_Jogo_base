extends SceneTree

const INFERENCER_PATH = \
    "res://addons/godot_rl_agents/onnx/csharp/ONNXInference.cs"

const MODEL_PATH = \
    "res://models/duel_inference_embedded.onnx"


func _initialize() -> void:
    call_deferred("_run_test")


func _run_test() -> void:
    print("\n========== TESTE DIRETO DO INFERENCIADOR ==========")
    print("Modelo: ", MODEL_PATH)

    if not FileAccess.file_exists(MODEL_PATH):
        printerr("ERRO: arquivo ONNX nao encontrado.")
        quit(1)
        return

    print("\n1. Carregando o script C#...")

    var inferencer_script: Variant = load(INFERENCER_PATH)

    print("Recurso C#: ", inferencer_script)

    if inferencer_script == null:
        printerr(
            "FALHA: Godot nao conseguiu carregar ONNXInference.cs."
        )
        quit(1)
        return

    print("\n2. Criando a instancia C#...")

    var inferencer: Variant = inferencer_script.new()

    print("Instancia: ", inferencer)

    if inferencer == null:
        printerr(
            "FALHA: nao foi possivel criar ONNXInference."
        )
        quit(1)
        return

    print("\n3. Inicializando o modelo ONNX...")

    var output_size: Variant = inferencer.call(
        "Initialize",
        MODEL_PATH,
        1
    )

    print("Tamanho de saida informado: ", output_size)

    if output_size == null or int(output_size) <= 0:
        printerr(
            "FALHA: o modelo nao informou um tamanho de saida valido."
        )
        quit(1)
        return

    print("\n4. Executando uma inferencia de teste...")

    var observations: Array[float] = [
        0.0, 0.0, 0.5, 1.0,
        1.0, 0.0, 1.0, 1.0
    ]

    var result: Variant = inferencer.call(
        "RunInference",
        observations,
        0
    )

    print("Resultado: ", result)

    if result == null:
        printerr("FALHA: a inferencia retornou null.")
        inferencer.call("FreeDisposables")
        inferencer.free()
        quit(1)
        return

    if not result is Dictionary:
        printerr("FALHA: formato de resposta inesperado.")
        inferencer.call("FreeDisposables")
        inferencer.free()
        quit(1)
        return

    if not result.has("output"):
        printerr("FALHA: a resposta nao possui a chave output.")
        inferencer.call("FreeDisposables")
        inferencer.free()
        quit(1)
        return

    print("\nSUCESSO: C# inicializou o modelo e executou inferencia.")

    inferencer.call("FreeDisposables")
    inferencer.free()

    quit(0)
