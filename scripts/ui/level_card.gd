extends Button

const UITheme = preload("res://scripts/ui/ui_theme.gd")
var level_index := 0
var level_title := ""
var concept := ""
var locked := false
var completed := false

func _ready() -> void:
	disabled = locked
	mouse_default_cursor_shape = Control.CURSOR_ARROW if locked else Control.CURSOR_POINTING_HAND
	var background := Color("e0e5ee") if locked else Color.WHITE
	var border := Color("cbd2de") if locked else Color("d9dfeb")
	for state in ["normal", "disabled"]:
		add_theme_stylebox_override(state, UITheme.panel(background, 5, border))
	add_theme_stylebox_override("hover", UITheme.panel(Color("f2f5fc"), 5, Color("8da3d1")))
	add_theme_stylebox_override("pressed", UITheme.panel(Color("e9eef9"), 5, Color("4968b5")))
	tooltip_text = "完成前一关后解锁" if locked else "进入 " + level_title

func _draw() -> void:
	var center_x := size.x * 0.5
	var circle_color := Color("b9c3d2") if locked else Color("4968b5")
	var circle_y := size.y * 0.24
	var circle_radius := minf(29.0, size.y * 0.128)
	draw_circle(Vector2(center_x, circle_y), circle_radius, circle_color)
	_centered("%02d" % (level_index + 1), circle_y + 9, minf(24.0, size.y * 0.106), Color("515d71") if locked else Color.WHITE)
	_centered(level_title, size.y * 0.53, 19, Color("606b7e") if locked else Color("30343b"))
	_centered(concept, size.y * 0.66, 14, Color("7b8595"))
	if locked:
		var at := Vector2(center_x - 36, size.y * 0.79)
		draw_rect(Rect2(at, Vector2(10, 9)), Color("717d91"), false, 1.3)
		draw_arc(at + Vector2(5, 0), 4, PI, TAU, 16, Color("717d91"), 1.3, true)
		_centered("未解锁", size.y * 0.84, 14, Color("717d91"), 9)
	else:
		_centered("已通关" if completed else "可挑战", size.y * 0.84, 14, Color("278776") if completed else circle_color)

func _centered(value: String, baseline: float, font_size: float, color: Color, offset: float = 0) -> void:
	var font := get_theme_default_font()
	var size_px := int(font_size)
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	draw_string(font, Vector2((size.x - width) * 0.5 + offset, baseline), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)
