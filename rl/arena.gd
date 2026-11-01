extends Node2D

const ARENA_RECT := Rect2(
    Vector2(-400.0, -250.0),
    Vector2(800.0, 500.0)
)

func _ready() -> void:
    queue_redraw()

func _draw() -> void:
    draw_rect(ARENA_RECT, Color("#202631"), true)
    draw_rect(ARENA_RECT, Color("#8792A8"), false, 3.0)

    draw_line(
        Vector2(0.0, -250.0),
        Vector2(0.0, 250.0),
        Color("#394253"),
        2.0
    )

    draw_circle(Vector2.ZERO, 5.0, Color("#B7C0D0"))
