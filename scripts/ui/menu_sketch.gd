extends Control

const BG_TOP := Color("07101a")
const BG_BOTTOM := Color("0d1825")
const PAPER := Color("f2eee4")
const MUTED := Color("8593a5")
const ACCENT := Color("6ee0c7")
const CORAL := Color("ff7863")

var elapsed := 0.0
var _mono_font := SystemFont.new()
var _math_font := SystemFont.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mono_font.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "DejaVu Sans Mono"])
	_math_font.font_names = PackedStringArray(["Cambria Math", "STIX Two Math", "Times New Roman"])

func _process(delta: float) -> void:
	if is_visible_in_tree():
		elapsed += delta
		queue_redraw()

func _draw() -> void:
	if size.x < 20.0 or size.y < 20.0:
		return
	_draw_backdrop()
	var stage := _stage_rect()
	_draw_stage_surface(stage)
	_draw_track(stage)
	_draw_hud(stage)
	_draw_viewport_frame()

func _stage_rect() -> Rect2:
	var left := maxf(size.x * 0.54, 590.0)
	var right_margin := maxf(54.0, size.x * 0.055)
	return Rect2(Vector2(left, size.y * 0.13), Vector2(maxf(320.0, size.x - right_margin - left), size.y * 0.70))

func _draw_backdrop() -> void:
	var strips := 36
	var strip_height := size.y / float(strips)
	for index in range(strips):
		var amount := float(index) / float(strips - 1)
		draw_rect(Rect2(0, index * strip_height, size.x, strip_height + 1.0), BG_TOP.lerp(BG_BOTTOM, amount))
	draw_circle(Vector2(size.x * 0.80, size.y * 0.35), size.y * 0.34, Color(0.18, 0.69, 0.59, 0.028))
	draw_circle(Vector2(size.x * 0.91, size.y * 0.82), size.y * 0.25, Color(1.0, 0.39, 0.30, 0.018))
	draw_colored_polygon(PackedVector2Array([
		Vector2(size.x * 0.52, 0),
		Vector2(size.x * 0.79, 0),
		Vector2(size.x, size.y * 0.58),
		Vector2(size.x, size.y),
		Vector2(size.x * 0.73, size.y),
	]), Color(0.36, 0.58, 0.68, 0.025))
	for index in range(8):
		var y := size.y * (0.18 + index * 0.09)
		draw_line(Vector2(size.x * 0.52, y), Vector2(size.x, y - size.y * 0.11), Color(0.48, 0.63, 0.73, 0.035), 1.0, true)

func _draw_stage_surface(stage: Rect2) -> void:
	draw_rect(stage, Color(0.02, 0.04, 0.06, 0.20))
	for index in range(11):
		var x := stage.position.x + stage.size.x * float(index) / 10.0
		draw_line(Vector2(x, stage.position.y), Vector2(x, stage.end.y), Color(0.38, 0.53, 0.64, 0.075), 1.0, true)
	for index in range(9):
		var y := stage.position.y + stage.size.y * float(index) / 8.0
		draw_line(Vector2(stage.position.x, y), Vector2(stage.end.x, y), Color(0.38, 0.53, 0.64, 0.065), 1.0, true)
	var center := stage.position + Vector2(stage.size.x * 0.56, stage.size.y * 0.46)
	var radius := minf(stage.size.x, stage.size.y) * 0.47
	draw_arc(center, radius, 0, TAU, 96, Color(ACCENT, 0.13), 1.0, true)
	draw_arc(center, radius * 0.72, -0.7, 3.8, 72, Color(CORAL, 0.11), 1.0, true)
	draw_line(center - Vector2(radius + 13, 0), center + Vector2(radius + 13, 0), Color(ACCENT, 0.14), 1.0, true)
	draw_line(center - Vector2(0, radius + 13), center + Vector2(0, radius + 13), Color(ACCENT, 0.14), 1.0, true)
	var ghost_size := int(minf(250.0, stage.size.y * 0.42))
	draw_string(get_theme_default_font(), Vector2(stage.position.x + stage.size.x * 0.58, stage.position.y + stage.size.y * 0.86), "07", HORIZONTAL_ALIGNMENT_LEFT, -1, ghost_size, Color(1, 1, 1, 0.025))

func _draw_track(stage: Rect2) -> void:
	var points := PackedVector2Array()
	for index in range(121):
		points.append(_curve_point(stage, float(index) / 120.0))
	draw_polyline(points, Color(0, 0, 0, 0.42), 17.0, true)
	draw_polyline(points, Color(ACCENT, 0.055), 15.0, true)
	draw_polyline(points, Color(ACCENT, 0.12), 9.0, true)
	draw_polyline(points, Color(0.43, 0.82, 0.78, 0.95), 2.8, true)
	draw_polyline(points, Color(0.94, 1.0, 0.96, 0.65), 1.0, true)
	for index in range(1, 12):
		var t := float(index) / 12.0
		var point := _curve_point(stage, t)
		var tangent := (_curve_point(stage, minf(1.0, t + 0.002)) - point).normalized()
		var normal := tangent.orthogonal()
		draw_line(point - normal * 3.0, point + normal * 3.0, Color(PAPER, 0.24), 1.0, true)
	_draw_checkpoint(stage, 0.33, 0.0, "01")
	_draw_checkpoint(stage, 0.66, 0.0, "02")
	_draw_start(stage)
	var cycle := fmod(elapsed, 7.2)
	var travel := clampf(cycle / 5.2, 0.0, 1.0)
	var ball_t := 1.0 - pow(1.0 - travel, 3.0)
	var ball_alpha := 1.0 - clampf((cycle - 6.35) / 0.65, 0.0, 1.0)
	_draw_ball(stage, ball_t, ball_alpha)
	_draw_goal(stage, ball_t)

func _draw_start(stage: Rect2) -> void:
	var point := _curve_point(stage, 0.0)
	draw_circle(point, 15.0, Color(ACCENT, 0.055))
	draw_arc(point, 9.0, 0, TAU, 32, Color(ACCENT, 0.8), 1.4, true)
	draw_circle(point, 3.0, PAPER)
	draw_string(_mono_font, point + Vector2(-4, -18), "S", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(ACCENT, 0.72))

func _draw_checkpoint(stage: Rect2, t: float, _unused: float, label: String) -> void:
	var point := _curve_point(stage, t)
	draw_circle(point, 7.0, Color(0.05, 0.10, 0.13, 0.8))
	draw_arc(point, 7.0, 0, TAU, 28, Color(PAPER, 0.52), 1.2, true)
	draw_string(_mono_font, point + Vector2(11, -8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(MUTED, 0.55))

func _draw_goal(stage: Rect2, ball_t: float) -> void:
	var point := _curve_point(stage, 1.0)
	var reached := ball_t > 0.985
	var glow := 0.06 + (0.06 if reached else 0.0)
	draw_circle(point, 22.0, Color(CORAL, glow))
	draw_arc(point, 14.0, 0, TAU, 40, Color(CORAL, 0.92), 1.8, true)
	draw_arc(point, 8.0, 0, TAU, 32, Color(CORAL, 0.52), 1.0, true)
	draw_line(point + Vector2(-20, 0), point + Vector2(20, 0), Color(CORAL, 0.36), 1.0, true)
	draw_line(point + Vector2(0, -20), point + Vector2(0, 20), Color(CORAL, 0.36), 1.0, true)
	draw_circle(point, 2.4 if not reached else 4.0, CORAL)
	draw_string(_mono_font, point + Vector2(-16, 31), "GOAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(CORAL, 0.7))

func _draw_ball(stage: Rect2, t: float, alpha: float) -> void:
	if alpha <= 0.01:
		return
	var point := _curve_point(stage, t)
	var radius := clampf(stage.size.x * 0.019, 8.0, 13.0)
	for index in range(18, 0, -1):
		var trail_t := maxf(0.0, t - float(index) * 0.008)
		var trail_point := _curve_point(stage, trail_t)
		var trail_alpha := (1.0 - float(index) / 19.0) * 0.18 * alpha
		draw_circle(trail_point, radius * (1.0 - float(index) / 28.0), Color(ACCENT, trail_alpha))
	draw_circle(point + Vector2(0, radius * 0.42), radius + 6.0, Color(0, 0, 0, 0.24 * alpha))
	draw_circle(point, radius + 12.0, Color(ACCENT, 0.055 * alpha))
	draw_circle(point, radius + 5.0, Color(ACCENT, 0.10 * alpha))
	draw_circle(point, radius + 1.5, Color(PAPER, alpha))
	draw_circle(point, radius, Color(0.31, 0.77, 0.70, alpha))
	draw_circle(point + Vector2(-radius * 0.30, -radius * 0.32), radius * 0.31, Color(1, 1, 1, 0.75 * alpha))

func _draw_hud(stage: Rect2) -> void:
	var top_y := stage.position.y - 17.0
	draw_string(_mono_font, Vector2(stage.position.x, top_y), "FUNCTION TRACK   /   f(x)", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(MUTED, 0.76))
	draw_circle(Vector2(stage.end.x - 37, top_y - 3), 2.6, ACCENT)
	draw_string(_mono_font, Vector2(stage.end.x - 28, top_y), "LIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(ACCENT, 0.8))
	var bottom_y := stage.end.y + 29.0
	draw_string(_math_font, Vector2(stage.position.x, bottom_y), "y = 0.12x² − 0.60x + 0.10", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(PAPER, 0.68))
	var rate := "120 HZ"
	var rate_width := _mono_font.get_string_size(rate, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_string(_mono_font, Vector2(stage.end.x - rate_width, bottom_y), rate, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(MUTED, 0.7))
	_draw_corner_marks(stage)
	draw_set_transform(Vector2(stage.end.x + 28, stage.end.y), -PI * 0.5)
	draw_string(_mono_font, Vector2.ZERO, "S H U W E I   P I N B A L L   /   E X P E R I M E N T   0 7", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(MUTED, 0.48))
	draw_set_transform(Vector2.ZERO)

func _draw_corner_marks(stage: Rect2) -> void:
	var length := 18.0
	var color := Color(ACCENT, 0.45)
	for corner in [stage.position, Vector2(stage.end.x, stage.position.y), Vector2(stage.position.x, stage.end.y), stage.end]:
		var horizontal := 1.0 if corner.x == stage.position.x else -1.0
		var vertical := 1.0 if corner.y == stage.position.y else -1.0
		draw_line(corner, corner + Vector2(length * horizontal, 0), color, 1.0, true)
		draw_line(corner, corner + Vector2(0, length * vertical), color, 1.0, true)

func _draw_viewport_frame() -> void:
	var frame := Rect2(24, 24, size.x - 48, size.y - 48)
	draw_rect(frame, Color(0.78, 0.88, 0.90, 0.08), false, 1.0)
	for corner in [frame.position, Vector2(frame.end.x, frame.position.y), Vector2(frame.position.x, frame.end.y), frame.end]:
		var horizontal := 1.0 if corner.x == frame.position.x else -1.0
		var vertical := 1.0 if corner.y == frame.position.y else -1.0
		draw_line(corner, corner + Vector2(22 * horizontal, 0), Color(ACCENT, 0.55), 1.0, true)
		draw_line(corner, corner + Vector2(0, 22 * vertical), Color(ACCENT, 0.55), 1.0, true)
	draw_circle(Vector2(size.x - 40, 40), 3.0, CORAL)

func _curve_point(stage: Rect2, t: float) -> Vector2:
	var p0 := stage.position + Vector2(stage.size.x * 0.035, stage.size.y * 0.30)
	var p1 := stage.position + Vector2(stage.size.x * 0.25, stage.size.y * -0.08)
	var p2 := stage.position + Vector2(stage.size.x * 0.67, stage.size.y * 1.08)
	var p3 := stage.position + Vector2(stage.size.x * 0.975, stage.size.y * 0.50)
	var u := 1.0 - t
	return p0 * pow(u, 3.0) + p1 * (3.0 * u * u * t) + p2 * (3.0 * u * t * t) + p3 * pow(t, 3.0)
