extends Area2D

@export var speed: float = 520.0
@export var lifetime: float = 1.2

var source_agent: Node2D = null
var travel_direction: Vector2 = Vector2.RIGHT
var damage: int = 10
var age: float = 0.0


func _ready() -> void:
    add_to_group("rl_projectile")

    collision_layer = 4
    collision_mask = 1

    if not body_entered.is_connected(_on_body_entered):
        body_entered.connect(_on_body_entered)

    travel_direction = travel_direction.normalized()


func _physics_process(delta: float) -> void:
    age += delta

    global_position += travel_direction * speed * delta

    if age >= lifetime:
        if (
            is_instance_valid(source_agent)
            and source_agent.has_method("register_missed_attack")
        ):
            source_agent.call("register_missed_attack")

        queue_free()


func _on_body_entered(body: Node2D) -> void:
    if body == source_agent:
        return

    if body.is_in_group("rl_fighter") and body.has_method("take_damage"):
        body.call("take_damage", damage, source_agent)
        queue_free()
