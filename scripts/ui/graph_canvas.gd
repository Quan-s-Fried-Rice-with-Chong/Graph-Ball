extends Control

signal view_changed(zoom: float)
signal cursor_moved(world_position: Vector2)

const SURFACE := Color("09131e")
const INK := Color("f2eee4")
const MUTED := Color("8294a7")
const BLUE := Color("5b8fe8")
const GREEN := Color("6ee0c7")
const GOLD := Color("f0c366")
const DANGER := Color("ff7863")
const DANGER_FILL := Color("29161a")

var level: Dictionary = {}
var bounds := Rect2(-9, -4, 20, 12)
var center := Vector2(1, 2)
var zoom_factor := 1.0
var _base_scale := 40.0
var _segments: Array = []
var _history: Array = []
var _ball := Vector2.ZERO
var _reached: Array = []
var _trail := PackedVector2Array()
var _dragging := false
var view_locked := false

func _ready() -> void:
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	resized.connect(fit_view)
	fit_view.call_deferred()

func set_level(data: Dictionary) -> void:
	level = data
	bounds = data.bounds
	_ball = data.start
	_reached = []
	_history = []
	_trail = PackedVector2Array()
	fit_view()

func set_curve(segments: Array) -> void:
	_segments = segments
	queue_redraw()

func remember_curve() -> void:
	_history = _segments.duplicate(true)
	_trail = PackedVector2Array()
	queue_redraw()

func clear_history() -> void:
	_history = []
	_trail = PackedVector2Array()
	queue_redraw()

func set_ball(point: Vector2, _elapsed: float) -> void:
	_ball = point
	if _trail.is_empty() or _trail[-1].distance_to(point) > 0.07:
		_trail.append(point)
		if _trail.size() > 900:
			_trail.remove_at(0)
	queue_redraw()

func reset_trail() -> void:
	_trail = PackedVector2Array()
	queue_redraw()

func set_checkpoints(reached: Array) -> void:
	_reached = reached
	queue_redraw()

func fit_view() -> void:
	if view_locked:
		return
	if size.x < 1.0 or size.y < 1.0:
		return
	_base_scale = maxf(8.0, minf((size.x - 84.0) / bounds.size.x, (size.y - 100.0) / bounds.size.y))
	zoom_factor = 1.0
	center = bounds.get_center()
	view_changed.emit(zoom_factor)
	queue_redraw()

func world_to_screen(point: Vector2) -> Vector2:
	var relative := point - center
	return size * 0.5 + Vector2(relative.x, -relative.y) * _scale()

func world_rect_to_global(rect: Rect2) -> Rect2:
	var local := Rect2(world_to_screen(Vector2(rect.position.x, rect.end.y)), rect.size * _scale())
	return Rect2(get_global_rect().position + local.position, local.size)

func screen_to_world(point: Vector2) -> Vector2:
	var relative := (point - size * 0.5) / _scale()
	return center + Vector2(relative.x, -relative.y)

func zoom_at(multiplier: float, anchor: Vector2) -> void:
	if view_locked:
		return
	var before := screen_to_world(anchor)
	zoom_factor = clampf(zoom_factor * multiplier, 0.65, 3.0)
	center += before - screen_to_world(anchor)
	_clamp_center()
	view_changed.emit(zoom_factor)
	queue_redraw()

func _scale() -> float:
	return _base_scale * zoom_factor

func _clamp_center() -> void:
	center.x = clampf(center.x, bounds.position.x, bounds.end.x)
	center.y = clampf(center.y, bounds.position.y, bounds.end.y)

func _gui_input(event: InputEvent) -> void:
	if view_locked:
		_dragging = false
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = event.pressed
			mouse_default_cursor_shape = Control.CURSOR_DRAG if _dragging else Control.CURSOR_CROSS
			accept_event()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var direction := 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
			if event.ctrl_pressed:
				zoom_at(pow(1.15, direction), event.position)
			elif event.shift_pressed:
				center.x += direction * 52.0 / _scale()
			else:
				center.y += direction * 52.0 / _scale()
			_clamp_center()
			queue_redraw()
			accept_event()
	elif event is InputEventMouseMotion:
		cursor_moved.emit(screen_to_world(event.position))
		if _dragging:
			center += Vector2(-event.relative.x, event.relative.y) / _scale()
			_clamp_center()
			queue_redraw()
			accept_event()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SURFACE)
	var region := Rect2(world_to_screen(Vector2(bounds.position.x, bounds.end.y)), bounds.size * _scale())
	_draw_grid()
	draw_rect(region, Color("355168"), false, 1.2)
	_text(region.position + Vector2(8, -9), "作图区", Color(MUTED, 0.9), 12)
	if level.is_empty():
		return
	for obstacle in level.obstacles:
		_draw_obstacle(obstacle)
	for hazard in level.get("circle_hazards", []):
		_draw_circle_hazard(hazard)
	_draw_curves(_history, Color(0.54, 0.68, 0.80, 0.22), 2.0)
	_draw_curves(_segments, BLUE, GameConstants.TRACK_HALF_THICKNESS * 2 * _scale(), true)
	_draw_ball_trail()
	for i in range(level.checkpoints.size()):
		_draw_checkpoint(i)
	_draw_start()
	_draw_goal()
	_draw_ball()

func _draw_obstacle(obstacle: Rect2) -> void:
	var screen_rect := Rect2(world_to_screen(Vector2(obstacle.position.x, obstacle.end.y)), obstacle.size * _scale())
	if screen_rect.size.x < 1.0 or screen_rect.size.y < 1.0:
		return
	draw_rect(screen_rect, DANGER_FILL)
	_draw_diagonal_hatching(screen_rect)
	draw_rect(screen_rect, DANGER, false, 1.5, true)
	if screen_rect.size.x >= 48.0 and screen_rect.size.y >= 34.0:
		_draw_warning_icon(screen_rect.get_center(), 9.0)

func _draw_diagonal_hatching(rect: Rect2) -> void:
	var step := 12.0
	var first := int(ceil((rect.position.x + rect.position.y) / step))
	var last := int(floor((rect.end.x + rect.end.y) / step))
	for index in range(first, last + 1):
		var diagonal := index * step
		var x_a := clampf(diagonal - rect.end.y, rect.position.x, rect.end.x)
		var y_a := diagonal - x_a
		var x_b := clampf(diagonal - rect.position.y, rect.position.x, rect.end.x)
		var y_b := diagonal - x_b
		draw_line(Vector2(x_a, y_a), Vector2(x_b, y_b), Color(DANGER, 0.12), 1.0, true)

func _draw_circle_hazard(hazard: Array) -> void:
	var point := world_to_screen(Vector2(hazard[0], hazard[1]))
	var radius := float(hazard[2]) * _scale()
	if radius < 1.0:
		return
	draw_circle(point, radius + 4.0, Color(DANGER, 0.055))
	draw_circle(point, radius, DANGER_FILL)
	draw_arc(point, radius, 0, TAU, 48, DANGER, 1.7, true)
	draw_arc(point, maxf(2.0, radius - 5.0), 0, TAU, 40, Color(DANGER, 0.24), 1.0, true)
	_draw_warning_icon(point, minf(9.0, radius * 0.34))
	_draw_pill_label(point + Vector2(0, -radius - 14), "危险区", DANGER, Color("241418"), 11)

func _draw_warning_icon(anchor: Vector2, icon_size: float) -> void:
	draw_circle(anchor, icon_size + 3.0, Color("2a171b"))
	draw_arc(anchor, icon_size + 2.0, 0, TAU, 24, Color(DANGER, 0.45), 1.0, true)
	var triangle := PackedVector2Array([
		anchor + Vector2(0, -icon_size),
		anchor + Vector2(icon_size * 0.9, icon_size * 0.72),
		anchor + Vector2(-icon_size * 0.9, icon_size * 0.72),
	])
	draw_colored_polygon(triangle, DANGER)
	_centered_text(anchor + Vector2(0, icon_size * 0.16), "!", Color("fff4ef"), maxi(9, int(icon_size * 1.15)))

func _draw_checkpoint(index: int) -> void:
	var point := world_to_screen(level.checkpoints[index])
	var done: bool = index < _reached.size() and _reached[index]
	var color: Color = GREEN if done else GOLD
	var radius := float(level.checkpoint_radius) * _scale()
	draw_circle(point, radius + 7.0, Color(color, 0.06))
	draw_circle(point, radius + 2.0, Color("0d1a26"))
	draw_circle(point, maxf(1.0, radius - 3.0), Color(color, 0.09))
	draw_arc(point, radius, 0, TAU, 48, color, 2.2, true)
	draw_arc(point, maxf(1.0, radius - 5.0), 0, TAU, 36, Color(color, 0.26), 1.0, true)
	if done:
		_centered_text(point, "✓", color, maxi(11, int(radius * 0.8)))
	else:
		_centered_text(point, str(index + 1), color, maxi(10, int(radius * 0.72)))

func _draw_start() -> void:
	var point := world_to_screen(level.start)
	draw_circle(point, 14.0, Color(GREEN, 0.07))
	draw_circle(point, 12.0, Color("0c1c22"))
	draw_circle(point, 9.0, Color(GREEN, 0.08))
	draw_arc(point, 11.5, 0, TAU, 40, GREEN, 2.0, true)
	draw_circle(point, 3.5, GREEN)
	_text(point + Vector2(-31, 33), "(%.1f, %.1f)" % [level.start.x, level.start.y], MUTED, 12)

func _draw_goal() -> void:
	var point := world_to_screen(level.goal)
	var radius: float = float(level.goal_radius) * _scale()
	draw_circle(point, radius + 10.0, Color(GREEN, 0.055))
	draw_circle(point, radius + 2.0, Color("0c1c22"))
	draw_circle(point, maxf(1.0, radius - 4.0), Color(GREEN, 0.055))
	draw_arc(point, radius, 0, TAU, 48, GREEN, 2.4, true)
	draw_arc(point, maxf(2.0, radius * 0.66), 0, TAU, 40, Color(GREEN, 0.48), 1.2, true)
	draw_line(point + Vector2(-3, 8), point + Vector2(-3, -9), GREEN, 2.2, true)
	draw_colored_polygon(PackedVector2Array([
		point + Vector2(-2, -9),
		point + Vector2(8, -4.5),
		point + Vector2(-2, 0),
	]), GREEN)
	_text(point + Vector2(-31, radius + 30), "(%.1f, %.1f)" % [level.goal.x, level.goal.y], MUTED, 12)

func _draw_ball() -> void:
	var point := world_to_screen(_ball)
	var radius: float = maxf(4.0, float(level.ball_radius) * _scale())
	draw_circle(point + Vector2(0, 4), radius + 4.0, Color(0, 0, 0, 0.36))
	draw_circle(point, radius + 5.0, Color(BLUE, 0.12))
	draw_circle(point, radius + 2.5, Color("dcecff"))
	draw_circle(point, radius + 1.2, Color("17345c"))
	draw_circle(point, radius, Color("347bdd"))
	draw_circle(point + Vector2(-radius * 0.12, -radius * 0.16), radius * 0.72, Color("70b2ff"))
	draw_arc(point, radius * 0.82, deg_to_rad(28), deg_to_rad(148), 20, Color(1, 1, 1, 0.24), 1.2, true)
	draw_circle(point + Vector2(-radius * 0.34, -radius * 0.4), radius * 0.2, Color(1, 1, 1, 0.92))
	draw_circle(point + Vector2(radius * 0.34, radius * 0.28), radius * 0.09, Color(1, 1, 1, 0.35))

func _draw_ball_trail() -> void:
	if _trail.size() < 2:
		return
	var stride := maxi(1, int(ceil(float(_trail.size()) / 120.0)))
	var previous := world_to_screen(_trail[0])
	for index in range(stride, _trail.size(), stride):
		var next := world_to_screen(_trail[index])
		var amount := float(index) / float(_trail.size() - 1)
		draw_line(previous, next, Color(0.36, 0.65, 0.96, 0.025 + amount * 0.16), 1.0 + amount * 4.5, true)
		previous = next

func _draw_pill_label(anchor: Vector2, value: String, color: Color, background: Color, font_size: int) -> void:
	var font := get_theme_default_font()
	var text_size := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var rect := Rect2(anchor - Vector2(text_size.x * 0.5 + 7.0, text_size.y * 0.5 + 4.0), Vector2(text_size.x + 14.0, text_size.y + 8.0))
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color(color, 0.22)
	style.set_border_width_all(1)
	style.set_corner_radius_all(int(rect.size.y * 0.5))
	draw_style_box(style, rect)
	_centered_text(anchor, value, color, font_size)

func _draw_curves(segments: Array, color: Color, width: float, decorated: bool = false) -> void:
	var points := PackedVector2Array()
	var run_color := color
	var run_key := ""
	var last_end := Vector2.ZERO
	for segment in segments:
		if segment is Dictionary:
			var actual_color: Color = segment.color if color.a > 0.9 else color
			var key := String(segment.get("formula_id", segment.get("type", "")))
			var from := world_to_screen(segment.a)
			var to := world_to_screen(segment.b)
			if points.is_empty():
				points.append(from)
				points.append(to)
				run_color = actual_color
				run_key = key
			elif key == run_key and actual_color == run_color and last_end.distance_squared_to(from) <= 0.01:
				points.append(to)
			else:
				_flush_curve(points, run_color, width, decorated)
				points = PackedVector2Array([from, to])
				run_color = actual_color
				run_key = key
			last_end = to
			continue
		_flush_curve(points, run_color, width, decorated)
		points = PackedVector2Array()
		if segment.size() < 2:
			continue
		var screen_points := PackedVector2Array()
		for i in range(segment.size() - 1):
			var clipped := clip_segment_to_bounds(segment[i], segment[i + 1])
			if clipped.is_empty():
				if screen_points.size() > 1:
					draw_polyline(screen_points, color, width, true)
				screen_points = PackedVector2Array()
				continue
			var from := world_to_screen(clipped[0])
			var to := world_to_screen(clipped[1])
			if not screen_points.is_empty() and screen_points[-1].distance_to(from) > 0.1:
				if screen_points.size() > 1:
					draw_polyline(screen_points, color, width, true)
				screen_points = PackedVector2Array()
			if screen_points.is_empty():
				screen_points.append(from)
			screen_points.append(to)
		if screen_points.size() > 1:
			draw_polyline(screen_points, color, width, true)
	if points.size() > 1:
		_flush_curve(points, run_color, width, decorated)

func _flush_curve(points: PackedVector2Array, color: Color, width: float, decorated: bool = false) -> void:
	if points.size() < 2:
		return
	if decorated:
		var glow := Color(color, 0.10)
		draw_polyline(points, glow, width + 6.0, true)
		draw_circle(points[0], (width + 6.0) * 0.5, glow)
		draw_circle(points[-1], (width + 6.0) * 0.5, glow)
	draw_polyline(points, color, width, true)
	# Capsules use round ends; keep the silhouette without per-segment circles.
	draw_circle(points[0], width * 0.5, color)
	draw_circle(points[-1], width * 0.5, color)
	if decorated:
		var sheen := Color(color.lightened(0.42), 0.44)
		var sheen_width := maxf(1.0, width * 0.16)
		draw_polyline(points, sheen, sheen_width, true)

func clip_segment_to_bounds(from: Vector2, to: Vector2) -> PackedVector2Array:
	var delta := to - from
	var p: Array[float] = [-delta.x, delta.x, -delta.y, delta.y]
	var q: Array[float] = [from.x - bounds.position.x, bounds.end.x - from.x, from.y - bounds.position.y, bounds.end.y - from.y]
	var lower := 0.0
	var upper := 1.0
	for i in range(4):
		if absf(p[i]) < 0.000001:
			if q[i] < 0:
				return PackedVector2Array()
		else:
			var ratio: float = q[i] / p[i]
			if p[i] < 0:
				lower = maxf(lower, ratio)
			else:
				upper = minf(upper, ratio)
			if lower > upper:
				return PackedVector2Array()
	return PackedVector2Array([from + delta * lower, from + delta * upper])

func _draw_grid() -> void:
	var raw_step := 42.0 / _scale()
	var magnitude := pow(10.0, floor(log(raw_step) / log(10.0)))
	var normalized := raw_step / magnitude
	var major := magnitude * (1.0 if normalized <= 1.0 else (2.0 if normalized <= 2.0 else (5.0 if normalized <= 5.0 else 10.0)))
	var minor := major / 2.0
	var axis_y := world_to_screen(Vector2.ZERO).y
	var axis_x := world_to_screen(Vector2.ZERO).x
	var view_min := screen_to_world(Vector2(0, size.y))
	var view_max := screen_to_world(Vector2(size.x, 0))
	var x := ceilf(view_min.x / minor) * minor
	while x <= view_max.x + 0.0001:
		var is_major := absf(x / major - roundf(x / major)) < 0.01
		var from := Vector2(world_to_screen(Vector2(x, 0)).x, size.y)
		var to := Vector2(from.x, 0)
		draw_line(from, to, Color("26394a") if is_major else Color("172838"), 1.0)
		if is_major and absf(x) > 0.001:
			_text(Vector2(from.x + 4, clampf(axis_y + 18, 20, size.y - 14)), _number(x), MUTED, 12)
		x += minor
	var y := ceilf(view_min.y / minor) * minor
	while y <= view_max.y + 0.0001:
		var is_major := absf(y / major - roundf(y / major)) < 0.01
		var from := Vector2(0, world_to_screen(Vector2(0, y)).y)
		var to := Vector2(size.x, from.y)
		draw_line(from, to, Color("26394a") if is_major else Color("172838"), 1.0)
		if is_major and absf(y) > 0.001:
			_text(Vector2(clampf(axis_x + 7, 8, size.x - 30), from.y - 5), _number(y), MUTED, 12)
		y += minor
	draw_line(Vector2(0, axis_y), Vector2(size.x, axis_y), Color("4b6479"), 1.3, true)
	draw_line(Vector2(axis_x, 0), Vector2(axis_x, size.y), Color("4b6479"), 1.3, true)
	_text(Vector2(axis_x + 7, axis_y + 18), "0", MUTED, 12)
	_text(Vector2(size.x - 16, axis_y - 10), "x", MUTED, 14)
	_text(Vector2(axis_x - 16, 18), "y", MUTED, 14)

func _number(value: float) -> String:
	return str(int(roundf(value))) if is_equal_approx(value, roundf(value)) else "%.1f" % value

func _text(at: Vector2, value: String, color: Color, font_size: int) -> void:
	draw_string(get_theme_default_font(), at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _centered_text(anchor: Vector2, value: String, color: Color, font_size: int) -> void:
	var font := get_theme_default_font()
	var text_size := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := anchor.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	draw_string(font, Vector2(anchor.x - text_size.x * 0.5, baseline), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
