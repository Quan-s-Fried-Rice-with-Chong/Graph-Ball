@tool
extends Button
## Native vector icons with a text tooltip.

@export var symbol := "play":
	set(value):
		symbol = value
		queue_redraw()
@export var highlighted := false

func _ready() -> void:
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	toggled.connect(func(_value: bool): queue_redraw())

func _draw() -> void:
	var color := Color("4968b5") if highlighted else Color("62666e")
	if disabled:
		color = Color("c5c8ce")
	var c := size * 0.5
	match symbol:
		"play":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-5, -8), c + Vector2(8, 0), c + Vector2(-5, 8)]), color)
		"pause":
			draw_rect(Rect2(c + Vector2(-6, -8), Vector2(4, 16)), color)
			draw_rect(Rect2(c + Vector2(2, -8), Vector2(4, 16)), color)
		"retry":
			draw_arc(c, 8, -0.9, 4.4, 40, color, 1.7, true)
			draw_polyline(PackedVector2Array([c + Vector2(-7, -11), c + Vector2(-2, -8), c + Vector2(-6, -3)]), color, 1.7, true)
		"reset":
			draw_polyline(PackedVector2Array([c + Vector2(-9, 3), c + Vector2(1, -8), c + Vector2(9, -1), c + Vector2(0, 9), c + Vector2(-4, 9), c + Vector2(-9, 3)]), color, 1.6, true)
			draw_line(c + Vector2(-5, -1), c + Vector2(4, 6), color, 1.6, true)
			draw_line(c + Vector2(-5, 10), c + Vector2(10, 10), color, 1.6, true)
		"chevron_right":
			draw_polyline(PackedVector2Array([c + Vector2(-3, -5), c + Vector2(2, 0), c + Vector2(-3, 5)]), color, 1.5, true)
		"chevron_down":
			draw_polyline(PackedVector2Array([c + Vector2(-5, -2), c + Vector2(0, 3), c + Vector2(5, -2)]), color, 1.5, true)
		"plus":
			draw_line(c + Vector2(-6, 0), c + Vector2(6, 0), color, 1.5, true)
			draw_line(c + Vector2(0, -6), c + Vector2(0, 6), color, 1.5, true)
		"minus":
			draw_line(c + Vector2(-6, 0), c + Vector2(6, 0), color, 1.5, true)
		"fit":
			for signs in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var corner: Vector2 = c + signs * 7.0
				draw_polyline(PackedVector2Array([corner - Vector2(signs.x * 5, 0), corner, corner - Vector2(0, signs.y * 5)]), color, 1.5, true)
