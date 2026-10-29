class_name MenuActionButton
extends Button

@export var index_text := "01"
@export var title_text := "菜单"
@export var caption_text := "MENU"
@export var accent := Color("6ee0c7")

var _hover := 0.0
var _mouse_hover := false
var _keyboard_focus := false
var _mono_font := SystemFont.new()

func _ready() -> void:
	text = ""
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_mono_font.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "DejaVu Sans Mono"])
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_keyboard_focus = false
		queue_redraw()
	elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_keyboard_focus = true
		queue_redraw()

func _process(delta: float) -> void:
	var target := 1.0 if _mouse_hover else 0.0
	var next := move_toward(_hover, target, delta * 7.0)
	if not is_equal_approx(next, _hover):
		_hover = next
		queue_redraw()

func _set_hover(value: bool) -> void:
	_mouse_hover = value
	queue_redraw()

func _draw() -> void:
	var font := get_theme_default_font()
	var active := _hover
	var center_y := size.y * 0.5
	if active > 0.01:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.035 * active))
		draw_rect(Rect2(0, 10, 3, size.y - 20), Color(accent, 0.8 * active))
	if has_focus() and _keyboard_focus:
		draw_rect(Rect2(Vector2.ZERO, size), Color(accent, 0.42), false, 1.0)
	var line_color := Color(0.82, 0.90, 0.92, 0.10 + active * 0.16)
	draw_line(Vector2(0, size.y - 1), Vector2(size.x, size.y - 1), line_color, 1.0, true)

	var index_size := 12
	var title_size := 25
	var caption_size := 10
	draw_string(_mono_font, Vector2(18, center_y + 4), index_text, HORIZONTAL_ALIGNMENT_LEFT, -1, index_size, Color(accent, 0.62 + active * 0.38))
	draw_string(font, Vector2(58, _baseline(font, center_y, title_size)), title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color("f2eee4"))
	var caption_width := _mono_font.get_string_size(caption_text, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size).x
	draw_string(_mono_font, Vector2(size.x - caption_width - 34, center_y + 3), caption_text, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size, Color(0.59, 0.65, 0.72, 0.55 + active * 0.4))
	var arrow_color := Color(accent, 0.25 + active * 0.75)
	var arrow_x := size.x - 18
	draw_line(Vector2(arrow_x - 9, center_y), Vector2(arrow_x, center_y), arrow_color, 1.4, true)
	draw_line(Vector2(arrow_x - 4, center_y - 5), Vector2(arrow_x, center_y), arrow_color, 1.4, true)
	draw_line(Vector2(arrow_x - 4, center_y + 5), Vector2(arrow_x, center_y), arrow_color, 1.4, true)

func _baseline(font: Font, center_y: float, font_size: int) -> float:
	return center_y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
