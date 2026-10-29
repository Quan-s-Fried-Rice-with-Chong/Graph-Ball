class_name ArtTitle
extends Control

const PAPER := Color("f2eee4")
const ACCENT := Color("6ee0c7")
const CORAL := Color("ff7863")
const SHADOW := Color(0, 0, 0, 0.36)

var _display_font := SystemFont.new()
var _mono_font := SystemFont.new()
var _elapsed := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_display_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "Noto Sans"])
	_display_font.font_weight = 800
	_mono_font.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "DejaVu Sans Mono"])

func _process(delta: float) -> void:
	if is_visible_in_tree():
		_elapsed = fmod(_elapsed + delta, 6.4)
		queue_redraw()

func _draw() -> void:
	var font_size := clampi(int(size.y * 0.42), 72, 102)
	var first_baseline := float(font_size) + 4.0
	var second_baseline := first_baseline + float(font_size) + 6.0
	_draw_orbit(first_baseline)
	draw_string(_display_font, Vector2(2, first_baseline + 5), "数维", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, SHADOW)
	draw_string(_display_font, Vector2(44, second_baseline + 5), "弹球", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, SHADOW)
	draw_string(_display_font, Vector2(0, first_baseline), "数维", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, PAPER)
	draw_string(_display_font, Vector2(42, second_baseline), "弹球", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, PAPER)
	draw_line(Vector2(0, first_baseline + 10), Vector2(236, first_baseline + 10), Color(ACCENT, 0.38), 1.0, true)
	draw_line(Vector2(42, second_baseline + 10), Vector2(286, second_baseline + 10), Color(PAPER, 0.13), 1.0, true)
	draw_string(_mono_font, Vector2(44, second_baseline + 30), "FUNCTION / PINBALL", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(PAPER, 0.42))

func _draw_orbit(first_baseline: float) -> void:
	var p0 := Vector2(215, 4)
	var p1 := Vector2(352, -8)
	var p2 := Vector2(430, 124)
	var p3 := Vector2(316, second_line_y(first_baseline) + 18)
	var points := PackedVector2Array()
	for index in range(61):
		points.append(_bezier(p0, p1, p2, p3, float(index) / 60.0))
	draw_polyline(points, Color(PAPER, 0.10), 1.2, true)
	draw_polyline(points.slice(0, 18), Color(ACCENT, 0.18), 1.4, true)
	var t := 0.2 + 0.58 * (0.5 - 0.5 * cos(_elapsed / 6.4 * TAU))
	var ball := _bezier(p0, p1, p2, p3, t)
	draw_circle(ball, 10.0, Color(ACCENT, 0.08))
	draw_circle(ball, 5.0, ACCENT)
	draw_circle(ball + Vector2(-1.5, -1.5), 1.6, Color(1, 1, 1, 0.8))
	draw_circle(_bezier(p0, p1, p2, p3, 0.78), 2.0, CORAL)

func second_line_y(first_baseline: float) -> float:
	return first_baseline + float(clampi(int(size.y * 0.42), 72, 102)) + 6.0

func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return p0 * pow(u, 3.0) + p1 * (3.0 * u * u * t) + p2 * (3.0 * u * t * t) + p3 * pow(t, 3.0)
