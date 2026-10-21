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

var level: Dictionary = {}
var template_id := "linear"
var parameters: Dictionary = {}
var state := "editing"
var elapsed := 0.0
var ball_position := Vector2.ZERO
var reached: Array = []
var last_result: Dictionary = {}
var _path := PackedVector2Array()
var _path_index := 0
var _generation := 0

func configure(data: Dictionary, next_template: String, next_parameters: Dictionary) -> void:
	level = data.duplicate(true)
	template_id = next_template
	parameters = next_parameters.duplicate()
	_reset_run()
	_refresh_curve()

func update_formula(next_template: String, next_parameters: Dictionary) -> void:
	if state in ["running", "paused"]:
		return
	template_id = next_template
	parameters = next_parameters.duplicate()
	_reset_run()
	_refresh_curve()

func _refresh_curve() -> void:
	curve_changed.emit(Catalog.sample(template_id, parameters, level.bounds))

func _reset_run() -> void:
	_generation += 1
	elapsed = 0.0
	last_result = {}
	ball_position = level.start
	reached = []
	for _point in level.checkpoints:
		reached.append(false)
	_path_index = 0
	_set_state("editing")
	checkpoints_changed.emit(reached.duplicate())
	ball_moved.emit(ball_position, elapsed)

func retry() -> void:
	_reset_run()

func start() -> void:
	if state != "editing":
		return
	var error := Catalog.validate(template_id, parameters)
	if not error.is_empty():
		_finish(false, error)
		return
	var start_point := Vector2(level.start.x, Catalog.evaluate(template_id, parameters, level.start.x))
	if start_point.distance_to(level.start) > float(level.start_tolerance):
		_finish(false, "轨道还没有接到起点。调整参数，让蓝线穿过起点圆环。")
		return
	_path = PackedVector2Array([level.start])
	for i in range(601):
		var x: float = lerpf(level.start.x, level.goal.x + 0.75, float(i) / 600.0)
		var y: float = Catalog.evaluate(template_id, parameters, x)
		if not is_finite(y):
			_finish(false, "轨道出现了无效数值，请调整参数。")
			return
		_path.append(Vector2(x, y))
	_path_index = 1
	_set_state("running")

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
	last_result = {"success": success, "reason": reason, "elapsed": elapsed, "reached": reached.count(true), "total": reached.size(), "formula_count": 1, "mode": "demo"}
	_set_state("success" if success else "failed")
	# Deferred delivery lets the final ball position reach the canvas first.
	_deliver_result.call_deferred(last_result.duplicate(), _generation)

func _deliver_result(result: Dictionary, generation: int) -> void:
	if generation == _generation and state in ["success", "failed"] and result == last_result:
		run_finished.emit(result)
