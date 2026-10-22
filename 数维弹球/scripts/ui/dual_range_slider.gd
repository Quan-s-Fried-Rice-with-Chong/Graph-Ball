extends Control

signal range_changed(low: float, high: float)

const HANDLE_RADIUS := 7.0
const SIDE_PADDING := 12.0
const TRACK_COLOR := Color("dfe3ea")
const ACTIVE_COLOR := Color("8e9fc9")
const HANDLE_COLOR := Color("ffffff")
const HANDLE_BORDER := Color("4968b5")
const DISABLED_COLOR := Color("c6ccd6")

var min_value := -9.0
var max_value := 11.0
var step := 0.1
var value_low := -9.0
var value_high := 11.0
var editable := true:
	set(value):
		editable = value
		mouse_default_cursor_shape = Control.CURSOR_HSIZE if value else Control.CURSOR_ARROW
		queue_redraw()
var _dragging := -1
var _hovered := -1

func _ready() -> void:
	custom_minimum_size = Vector2(0, 30)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_HSIZE

func set_range_limits(low: float, high: float, next_step: float = 0.1) -> void:
	min_value = low
	max_value = maxf(low + next_step, high)
	step = maxf(0.001, next_step)
	value_low = clampf(value_low, min_value, max_value)
	value_high = clampf(value_high, min_value, max_value)
	if value_low > value_high:
		var swap := value_low
		value_low = value_high
		value_high = swap
	queue_redraw()

func set_values(low: float, high: float) -> void:
	value_low = clampf(_snap(low), min_value, max_value)
	value_high = clampf(_snap(high), min_value, max_value)
	if value_low > value_high:
		var swap := value_low
		value_low = value_high
		value_high = swap
	queue_redraw()

func set_values_no_signal(low: float, high: float) -> void:
	set_values(low, high)

func _snap(value: float) -> float:
	return snappedf(value, step)

func _track_rect() -> Rect2:
	return Rect2(Vector2(SIDE_PADDING, size.y * 0.5 - 2.0), Vector2(maxf(1.0, size.x - SIDE_PADDING * 2.0), 4.0))

func _value_to_x(value: float) -> float:
	var ratio := inverse_lerp(min_value, max_value, clampf(value, min_value, max_value))
	return lerpf(SIDE_PADDING, size.x - SIDE_PADDING, ratio)

func _x_to_value(x: float) -> float:
	var ratio := clampf(inverse_lerp(SIDE_PADDING, size.x - SIDE_PADDING, x), 0.0, 1.0)
	return _snap(lerpf(min_value, max_value, ratio))

func _gui_input(event: InputEvent) -> void:
	if not editable:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			grab_focus()
			var low_x := _value_to_x(value_low)
			var high_x := _value_to_x(value_high)
			_dragging = 0 if absf(event.position.x - low_x) <= absf(event.position.x - high_x) else 1
			_move_handle(_dragging, event.position.x)
			accept_event()
		elif _dragging >= 0:
			_dragging = -1
			accept_event()
	elif event is InputEventMouseMotion:
		_hovered = -1
		if absf(event.position.x - _value_to_x(value_low)) <= absf(event.position.x - _value_to_x(value_high)):
			if absf(event.position.x - _value_to_x(value_low)) <= HANDLE_RADIUS + 3.0:
				_hovered = 0
		elif absf(event.position.x - _value_to_x(value_high)) <= HANDLE_RADIUS + 3.0:
			_hovered = 1
		mouse_default_cursor_shape = Control.CURSOR_HSIZE
		if _dragging >= 0:
			_move_handle(_dragging, event.position.x)
			accept_event()
		else:
			queue_redraw()

func _move_handle(handle: int, mouse_x: float) -> void:
	var proposed := _x_to_value(mouse_x)
	if handle == 0:
		value_low = clampf(minf(proposed, value_high - step), min_value, max_value)
	else:
		value_high = clampf(maxf(proposed, value_low + step), min_value, max_value)
	_emit_if_changed()
	queue_redraw()

func _emit_if_changed() -> void:
	range_changed.emit(value_low, value_high)

func _draw() -> void:
	var track := _track_rect()
	var low_x := _value_to_x(value_low)
	var high_x := _value_to_x(value_high)
	draw_rect(track, TRACK_COLOR)
	var active := Color(ACTIVE_COLOR, 1.0) if editable else DISABLED_COLOR
	draw_rect(Rect2(Vector2(low_x, track.position.y), Vector2(maxf(1.0, high_x - low_x), track.size.y)), active)
	var border := HANDLE_BORDER if editable else DISABLED_COLOR
	for i in range(2):
		var point := Vector2(low_x if i == 0 else high_x, track.get_center().y)
		var radius := HANDLE_RADIUS + (1.5 if _hovered == i or _dragging == i else 0.0)
		draw_circle(point + Vector2(0, 1), radius + 1.0, Color(0.18, 0.22, 0.29, 0.12))
		draw_circle(point, radius, HANDLE_COLOR)
		draw_arc(point, radius, 0, TAU, 28, border, 2.0, true)
	if has_focus():
		draw_arc(Vector2(low_x, track.get_center().y), HANDLE_RADIUS + 4.0, 0, TAU, 28, Color(HANDLE_BORDER, 0.35), 1.2, true)
