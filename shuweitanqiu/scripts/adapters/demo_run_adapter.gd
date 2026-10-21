extends Node
## Replace this node's script with A's adapter, preserving the documented API.
## This prototype moves at constant arc-length speed: no gravity or bounce.

signal curve_changed(segments: Array)
signal ball_moved(position: Vector2, elapsed: float)
signal checkpoints_changed(reached: Array)
signal state_changed(state: String)
signal run_finished(result: Dictionary)

const Catalog = preload("res://scripts/core/formula_catalog.gd")
const MODE_LABEL := "演示运动 · 匀速沿轨道"
const SPEED := 5.0
const PATH_STEP := 0.02

var level: Dictionary = {}
var template_id := "linear"
var parameters: Dictionary = {}
var formulas: Array = []
var state := "editing"
var elapsed := 0.0
var ball_position := Vector2.ZERO
var reached: Array = []
var last_result: Dictionary = {}
var _path := PackedVector2Array()
var _path_index := 0
var _generation := 0
var _path_error := ""

func configure(data: Dictionary, next_template: String, next_parameters: Dictionary) -> void:
	var domain := Vector2(data.bounds.position.x, data.bounds.end.x)
	configure_formulas(data, [{"template": next_template, "parameters": next_parameters.duplicate(true), "domain": domain}])

func configure_formulas(data: Dictionary, next_formulas: Array) -> void:
	level = data.duplicate(true)
	_set_formulas(next_formulas)
	_reset_run()
	_refresh_curve()

func update_formula(next_template: String, next_parameters: Dictionary) -> void:
	if state in ["running", "paused"]:
		return
	var domain := Vector2(level.bounds.position.x, level.bounds.end.x)
	update_formulas([{"template": next_template, "parameters": next_parameters.duplicate(true), "domain": domain}])

func update_formulas(next_formulas: Array) -> void:
	if state in ["running", "paused"]:
		return
	_set_formulas(next_formulas)
	_reset_run()
	_refresh_curve()

func _set_formulas(next_formulas: Array) -> void:
	formulas = []
	for item in next_formulas:
		if not item is Dictionary:
			continue
		var formula_template: String = item.get("template", "linear")
		var formula_parameters: Dictionary = item.get("parameters", {}).duplicate(true)
		var domain: Variant = item.get("domain", Vector2(level.bounds.position.x, level.bounds.end.x))
		formulas.append({"template": formula_template, "parameters": formula_parameters, "domain": _as_domain(domain)})
	if formulas.is_empty():
		formulas.append({"template": "linear", "parameters": {"a": 0.0, "b": 0.0}, "domain": Vector2(level.bounds.position.x, level.bounds.end.x)})
	template_id = formulas[0].template
	parameters = formulas[0].parameters.duplicate(true)

func _as_domain(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2(level.bounds.position.x, level.bounds.end.x)

func _refresh_curve() -> void:
	var segments: Array = []
	for formula in formulas:
		segments.append_array(Catalog.sample(formula.template, formula.parameters, level.bounds, formula.domain))
	curve_changed.emit(segments)

func _reset_run() -> void:
	_generation += 1
	elapsed = 0.0
	last_result = {}
	ball_position = level.start
	reached = []
	for _point in level.checkpoints:
		reached.append(false)
	_path_index = 0
	_path_error = ""
	_set_state("editing")
	checkpoints_changed.emit(reached.duplicate())
	ball_moved.emit(ball_position, elapsed)

func retry() -> void:
	_reset_run()

func start() -> void:
	if state != "editing":
		return
	for formula in formulas:
		var error := Catalog.validate(formula.template, formula.parameters)
		if not error.is_empty():
			_finish(false, error)
			return
		error = Catalog.validate_domain(formula.domain, level.bounds)
		if not error.is_empty():
			_finish(false, error)
			return
	var start_y := _curve_y_at(level.start.x)
	if is_nan(start_y):
		_finish(false, "轨道没有覆盖起点。调整定义域，让函数接到起点圆环。")
		return
	if Vector2(level.start.x, start_y).distance_to(level.start) > float(level.start_tolerance):
		_finish(false, "轨道还没有接到起点。调整参数，让蓝线穿过起点圆环。")
		return
	_path = _build_path()
	if _path.is_empty():
		_finish(false, _path_error)
		return
	_path_index = 1
	_set_state("running")

func _build_path() -> PackedVector2Array:
	_path_error = ""
	var from_x: float = level.start.x
	var to_x: float = level.goal.x
	var span := to_x - from_x
	if absf(span) < 0.0001:
		return PackedVector2Array([level.start])
	var steps := maxi(2, ceili(absf(span) / PATH_STEP))
	var points := PackedVector2Array([level.start])
	for i in range(1, steps + 1):
		var x: float = lerpf(from_x, to_x, float(i) / float(steps))
		var y: float = _curve_y_at(x)
		if is_nan(y):
			_path_error = "轨道没有覆盖从起点到终点的 x 范围。调整定义域，让几条函数首尾相接。"
			return PackedVector2Array()
		points.append(Vector2(x, y))
	return points

func _curve_y_at(x: float) -> float:
	for formula in formulas:
		var domain: Vector2 = formula.domain
		if x >= domain.x - 0.0001 and x <= domain.y + 0.0001:
			var y: float = Catalog.evaluate(formula.template, formula.parameters, x)
			if is_finite(y):
				return y
	return NAN

func pause_or_resume() -> void:
	if state == "running":
		_set_state("paused")
	elif state == "paused":
		_set_state("running")

func _physics_process(delta: float) -> void:
	if state == "running":
		advance(delta)

func advance(delta: float) -> void:
	if state != "running" or delta <= 0.0:
		return
	elapsed += delta
	if elapsed >= float(level.time_limit):
		_finish(false, "时间到了。重试会保留刚才的参数。")
		return
	var remaining := SPEED * delta
	while remaining > 0.00001 and _path_index < _path.size() and state == "running":
		var target: Vector2 = _path[_path_index]
		var distance := ball_position.distance_to(target)
		var next_position := ball_position.move_toward(target, remaining)
		_check_segment(ball_position, next_position)
		ball_position = next_position
		remaining -= minf(distance, remaining)
		if distance < 0.00001 or ball_position.distance_to(target) < 0.00001:
			_path_index += 1
	ball_moved.emit(ball_position, elapsed)
	if state == "running" and _path_index >= _path.size():
		var reason := "小球错过了终点。调整曲线，让它穿过绿色终点区域。"
		if false in reached:
			reason = "还有检查点没有经过。观察黄色圆环，再调整曲线。"
		_finish(false, reason)

func _check_segment(from: Vector2, to: Vector2) -> void:
	var bounds: Rect2 = level.bounds
	if not bounds.grow(-float(level.ball_radius)).has_point(to):
		_finish(false, "小球离开了关卡边界。试着减小曲线的起伏。")
		return
	for obstacle in level.obstacles:
		if _segment_hits_rect(from, to, obstacle.grow(float(level.ball_radius))):
			_finish(false, "小球碰到了红色障碍。调整轨道，留出小球通过的空间。")
			return
	var changed := false
	for i in range(reached.size()):
		if not reached[i] and _segment_distance(level.checkpoints[i], from, to) <= float(level.checkpoint_radius) + float(level.ball_radius):
			reached[i] = true
			changed = true
	if changed:
		checkpoints_changed.emit(reached.duplicate())
	if _segment_distance(level.goal, from, to) <= float(level.goal_radius) + float(level.ball_radius) and not false in reached:
		_finish(true, "每一个检查点，都在你的轨道上。")

func _segment_distance(point: Vector2, from: Vector2, to: Vector2) -> float:
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, from, to))

func _segment_hits_rect(from: Vector2, to: Vector2, rect: Rect2) -> bool:
	if rect.has_point(from) or rect.has_point(to):
		return true
	var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in range(4):
		if Geometry2D.segment_intersects_segment(from, to, corners[i], corners[(i + 1) % 4]) != null:
			return true
	return false

func _set_state(value: String) -> void:
	state = value
	state_changed.emit(state)

func _finish(success: bool, reason: String) -> void:
	last_result = {"success": success, "reason": reason, "elapsed": elapsed, "reached": reached.count(true), "total": reached.size(), "formula_count": formulas.size(), "mode": "demo"}
	_set_state("success" if success else "failed")
	# Deferred delivery lets the final ball position reach the canvas first.
	_deliver_result.call_deferred(last_result.duplicate(), _generation)

func _deliver_result(result: Dictionary, generation: int) -> void:
	if generation == _generation and state in ["success", "failed"] and result == last_result:
		run_finished.emit(result)
