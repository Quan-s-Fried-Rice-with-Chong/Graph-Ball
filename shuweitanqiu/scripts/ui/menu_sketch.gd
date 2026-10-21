extends Control

var _phase := 0.0
var _math_font := SystemFont.new()

func _ready() -> void:
	_math_font.font_names = PackedStringArray(["Cambria Math", "Times New Roman"])

func _process(delta: float) -> void:
	if is_visible_in_tree():
		_phase = fmod(_phase + delta * 0.12, 1.0)
		queue_redraw()

func _draw() -> void:
	var area := Rect2(Vector2(size.x * 0.55, size.y * 0.29), Vector2(size.x * 0.37, size.y * 0.44))
	var scale_factor := minf(area.size.x / 8.0, area.size.y / 6.0)
	var origin := area.get_center() + Vector2(0, scale_factor * 0.3)
	for i in range(-4, 5):
		var x := origin.x + i * scale_factor
		draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), Color("eceef1"))
	for i in range(-3, 4):
		var y := origin.y + i * scale_factor
		if y >= area.position.y and y <= area.end.y:
			draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color("eceef1"))
	draw_line(Vector2(area.position.x, origin.y), Vector2(area.end.x, origin.y), Color("b9bec8"), 1.2)
	draw_line(Vector2(origin.x, area.position.y), Vector2(origin.x, area.end.y), Color("b9bec8"), 1.2)
	var points := PackedVector2Array()
	for i in range(181):
		var x := lerpf(-3.2, 3.2, i / 180.0)
		var y := 0.12 * x * x - 0.6 * x + 0.1
		points.append(origin + Vector2(x, -y) * scale_factor)
	draw_polyline(points, Color("4968b5"), 2.2, true)
	for index in [0, 180]:
		draw_circle(points[index], 6, Color.WHITE)
		draw_arc(points[index], 6, 0, TAU, 32, Color("4968b5"), 1.6, true)
	var x := lerpf(-3.2, 3.2, _phase)
	var y := 0.12 * x * x - 0.6 * x + 0.1
	draw_circle(origin + Vector2(x, -y) * scale_factor, 5, Color("30343b"))
	draw_string(_math_font, Vector2(area.position.x + 15, area.end.y + 42), "y = 0.12x² − 0.6x + 0.1", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("7d8596"))
