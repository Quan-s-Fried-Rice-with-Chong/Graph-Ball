extends Control

signal view_changed(zoom: float)
signal cursor_moved(world_position: Vector2)

const INK := Color("30343b")
const MUTED := Color("8a8d94")
const BLUE := Color("4968b5")
const GREEN := Color("187a6b")
const GOLD := Color("d99a36")

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
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
	var region := Rect2(world_to_screen(Vector2(bounds.position.x, bounds.end.y)), bounds.size * _scale())
	_draw_grid()
	draw_rect(region, Color("aeb8c8"), false, 1.2)
	_text(region.position + Vector2(8, -9), "作图区", Color("959cab"), 12)
	if level.is_empty():
		return
	for obstacle in level.obstacles:
		var screen_rect := Rect2(world_to_screen(Vector2(obstacle.position.x, obstacle.end.y)), obstacle.size * _scale())
		draw_rect(screen_rect, Color("fce9e7"))
		draw_rect(screen_rect, Color("d97870"), false, 1.5)
		if screen_rect.size.x > 60 and screen_rect.size.y > 30:
			_text(screen_rect.get_center() + Vector2(-14, 5), "障碍", Color("bb6a64"), 13)
	for hazard in level.get("circle_hazards", []):
		var point := world_to_screen(Vector2(hazard[0], hazard[1]))
		draw_circle(point, float(hazard[2]) * _scale(), Color("fce9e7"))
		draw_arc(point, float(hazard[2]) * _scale(), 0, TAU, 48, Color("d97870"), 1.5, true)
	_draw_curves(_history, Color(0.55, 0.62, 0.71, 0.32), 2.0)
	_draw_curves(_segments, BLUE, GameConstants.TRACK_HALF_THICKNESS * 2 * _scale())
	if _trail.size() > 1:
		_draw_curves([_trail], Color(0.18, 0.35, 0.65, 0.28), 5.0)
	for i in range(level.checkpoints.size()):
		var point: Vector2 = world_to_screen(level.checkpoints[i])
		var done: bool = i < _reached.size() and _reached[i]
		var color: Color = GREEN if done else GOLD
		var radius := float(level.checkpoint_radius) * _scale()
		draw_circle(point, radius + 5, Color(color, 0.08))
		draw_circle(point, radius - 1, Color.WHITE)
		draw_arc(point, radius, 0, TAU, 40, color, 2.0, true)
		if done:
			_text(point + Vector2(-4, 5), "✓", color, 13)
	var start: Vector2 = world_to_screen(level.start)
	draw_circle(start, 13, Color(GREEN, 0.09))
	draw_arc(start, 10, 0, TAU, 40, GREEN, 2, true)
	_text(start + Vector2(-17, -21), "起点", GREEN, 14)
	_text(start + Vector2(-32, 34), "(%.1f, %.1f)" % [level.start.x, level.start.y], MUTED, 12)
	var goal: Vector2 = world_to_screen(level.goal)
	var goal_radius: float = float(level.goal_radius) * _scale()
	draw_circle(goal, goal_radius + 5, Color(GREEN, 0.08))
	draw_arc(goal, goal_radius, 0, TAU, 48, GREEN, 2.2, true)
	draw_line(goal + Vector2(-3, 7), goal + Vector2(-3, -8), GREEN, 2, true)
	draw_colored_polygon(PackedVector2Array([goal + Vector2(-2, -8), goal + Vector2(8, -4), goal + Vector2(-2, 0)]), GREEN)
	_text(goal + Vector2(-17, -goal_radius - 13), "终点", GREEN, 14)
	_text(goal + Vector2(-32, goal_radius + 21), "(%.1f, %.1f)" % [level.goal.x, level.goal.y], MUTED, 12)
	var ball_screen := world_to_screen(_ball)
	var ball_radius := float(level.ball_radius) * _scale()
	draw_circle(ball_screen + Vector2(0, 3), ball_radius + 2, Color(0.13, 0.2, 0.3, 0.1))
	draw_circle(ball_screen, ball_radius + 2.0, Color.WHITE)
	draw_circle(ball_screen, ball_radius, INK)
	draw_circle(ball_screen + Vector2(-ball_radius * 0.25, -ball_radius * 0.25), ball_radius * 0.24, Color("a6bfdc"))

func _draw_curves(segments: Array, color: Color, width: float) -> void:
	for segment in segments:
		if segment is Dictionary:
			var actual_color: Color = segment.color if color.a > 0.9 else color
			draw_line(world_to_screen(segment.a), world_to_screen(segment.b), actual_color, width, true)
			# Capsules use round ends; match the collider silhouette.
			draw_circle(world_to_screen(segment.a), width * 0.5, actual_color)
			draw_circle(world_to_screen(segment.b), width * 0.5, actual_color)
			continue
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
		draw_line(from, to, Color("e1e3e7") if is_major else Color("f0f1f3"), 1.0)
		if is_major and absf(x) > 0.001:
			_text(Vector2(from.x + 4, clampf(axis_y + 18, 20, size.y - 14)), _number(x), MUTED, 12)
		x += minor
	var y := ceilf(view_min.y / minor) * minor
	while y <= view_max.y + 0.0001:
		var is_major := absf(y / major - roundf(y / major)) < 0.01
		var from := Vector2(0, world_to_screen(Vector2(0, y)).y)
		var to := Vector2(size.x, from.y)
		draw_line(from, to, Color("e1e3e7") if is_major else Color("f0f1f3"), 1.0)
		if is_major and absf(y) > 0.001:
			_text(Vector2(clampf(axis_x + 7, 8, size.x - 30), from.y - 5), _number(y), MUTED, 12)
		y += minor
	draw_line(Vector2(0, axis_y), Vector2(size.x, axis_y), Color("9da1a8"), 1.3, true)
	draw_line(Vector2(axis_x, 0), Vector2(axis_x, size.y), Color("9da1a8"), 1.3, true)
	_text(Vector2(axis_x + 7, axis_y + 18), "0", MUTED, 12)
	_text(Vector2(size.x - 16, axis_y - 10), "x", MUTED, 14)
	_text(Vector2(axis_x - 16, 18), "y", MUTED, 14)

func _number(value: float) -> String:
	return str(int(roundf(value))) if is_equal_approx(value, roundf(value)) else "%.1f" % value

func _text(at: Vector2, value: String, color: Color, font_size: int) -> void:
	draw_string(get_theme_default_font(), at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
