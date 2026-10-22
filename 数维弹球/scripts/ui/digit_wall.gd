extends Control
## Repeating rows scroll along a tilted plane, with no raster assets.

var elapsed := 0.0
var _font := SystemFont.new()
var _rows: Array[String] = []

func _ready() -> void:
	_font.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "DejaVu Sans Mono"])
	for digits in ["3  1  4  1  5  9  2  6  5  3  5  8  9  7  9  ", "2  7  1  8  2  8  1  8  2  8  4  5  9  0  4  ", "0  1  1  2  3  5  8  1  3  2  1  3  4  5  5  ", "1  4  1  4  2  1  3  5  6  2  3  7  3  0  9  ", "6  0  2  2  1  4  0  7  6  8  1  9  2  3  4  ", "9  8  7  6  5  4  3  2  1  0  2  4  6  8  0  "]:
		_rows.append(digits.repeat(6))

func _process(delta: float) -> void:
	if is_visible_in_tree():
		elapsed += delta
		queue_redraw()

func _draw() -> void:
	if _rows.is_empty():
		return
	var spacing := 54.0
	var offset := fposmod(elapsed * 15.0, spacing * _rows.size())
	var extent := size.length() * 0.75 + 400.0
	draw_set_transform(size * 0.5, deg_to_rad(-16.0))
	for i in range(-28, 29):
		var index: int = posmod(i, _rows.size())
		var alpha := 0.20 if index % 2 == 0 else 0.14
		draw_string(_font, Vector2(-extent - index * 21, i * spacing - offset), _rows[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color(0.45, 0.56, 0.74, alpha))
	draw_set_transform(Vector2.ZERO)
