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
	var color := Color("6ee0c7") if highlighted else Color("b8c3cf")
	if disabled:
		color = Color("46596b")
	var c := size * 0.5
	match symbol:
		"play":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-5, -8), c + Vector2(8, 0), c + Vector2(-5, 8)]), color)
		"pause":
			draw_rect(Rect2(c + Vector2(-6, -8), Vector2(4, 16)), color)
			draw_rect(Rect2(c + Vector2(2, -8), Vector2(4, 16)), color)
		"retry":
			_draw_rotation(c, 20.0, 300.0, color)
		"reset":
			var body := PackedVector2Array([
				c + Vector2(-10, 3), c + Vector2(0, -7), c + Vector2(9, 2),
				c + Vector2(-1, 12), c + Vector2(-10, 3)
			])
			draw_polyline(body, color, 1.7, true)
			draw_line(c + Vector2(3.2, -3.9), c + Vector2(-6.8, 6.1), color, 1.7, true)
			draw_line(c + Vector2(-12, 13), c + Vector2(11, 13), color, 1.7, true)
		"chevron_right":
			draw_polyline(PackedVector2Array([c + Vector2(-3, -5), c + Vector2(2, 0), c + Vector2(-3, 5)]), color, 1.5, true)
		"chevron_left":
			draw_polyline(PackedVector2Array([c + Vector2(3, -5), c + Vector2(-2, 0), c + Vector2(3, 5)]), color, 1.5, true)
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

func _draw_rotation(center: Vector2, start_deg: float, end_deg: float, color: Color) -> void:
	var radius := 7.5
	var points := PackedVector2Array()
	for i in range(41):
		var angle := deg_to_rad(lerpf(start_deg, end_deg, i / 40.0))
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_polyline(points, color, 1.8, true)
	var end := deg_to_rad(end_deg)
	var tangent := Vector2(-sin(end), cos(end)) * signf(end_deg - start_deg)
	var radial := Vector2(cos(end), sin(end))
	var point := center + radial * radius
	var tip := point + tangent * 4.6
	var base := point - tangent * 1.2
	draw_colored_polygon(PackedVector2Array([tip, base + radial * 3.4, base - radial * 3.4]), color)
