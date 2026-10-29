class_name LevelController
extends Node

signal level_loaded(level: Dictionary)
signal formula_list_changed(formulas: Array)
signal curve_points_updated(tracks: Array)
signal simulation_updated(ball_position: Vector2, ball_state: Dictionary, checkpoint_index: int)
signal run_finished(success: bool, reason: String, elapsed_time: float)
signal validation_failed(errors: Array)
signal editing_lock_changed(locked: bool)
signal status_changed(status: String)

enum RunState { EDITING, RUNNING, PAUSED, SUCCESS, FAILED }

var current_level_index := 0
var current_level: Dictionary = {}
var formulas: Array = []
var state := RunState.EDITING
var elapsed_time := 0.0
var time_left := 0.0
var failure_reason := ""
var save_enabled := true
var last_save_ok := true

@onready var game_world: FormulaGameWorld = $GameWorld

func _ready() -> void:
	game_world.checkpoint_reached.connect(_on_checkpoint_reached)
	game_world.goal_reached.connect(_on_goal_reached)
	game_world.world_failed.connect(_on_world_failed)
	game_world.ball_state_changed.connect(_on_ball_state_changed)
	game_world.track_builder.tracks_rebuilt.connect(_on_tracks_rebuilt)

func _physics_process(delta: float) -> void:
	if state != RunState.RUNNING:
		return
	elapsed_time += delta
	time_left = maxf(0.0, float(current_level.get("time_limit", 0.0)) - elapsed_time)
	if time_left <= 0.0:
		finish_run(false, "时间耗尽")

func load_level(index: int) -> bool:
	var level_count := LevelData.all_levels().size()
	if level_count == 0:
		return false
	current_level_index = clampi(index, 0, level_count - 1)
	var candidate := LevelData.get_level(current_level_index)
	return configure_level(candidate)

func configure_level(candidate: Dictionary, build_colliders: bool = true) -> bool:
	var level_result := LevelData.validate(candidate)
	if not level_result["ok"]:
		validation_failed.emit(level_result["errors"])
		return false
	current_level = candidate
	formulas = current_level["formulas"].duplicate(true)
	state = RunState.EDITING
	elapsed_time = 0.0
	time_left = float(current_level["time_limit"])
	failure_reason = ""
	game_world.configure_level(current_level, formulas, build_colliders)
	level_loaded.emit(current_level.duplicate(true))
	formula_list_changed.emit(formulas.duplicate(true))
	status_changed.emit(status_name())
	editing_lock_changed.emit(false)
	return true

func set_formulas(next_formulas: Array, build_colliders: bool = true, update_tracks: bool = true) -> bool:
	if state != RunState.EDITING:
		return false
	var result := FormulaValidator.validate(next_formulas, current_level)
	if not result["ok"]:
		validation_failed.emit(result["errors"])
		return false
	formulas = result["formulas"]
	if update_tracks:
		if build_colliders:
			game_world.rebuild_tracks(formulas)
		else:
			game_world.preview_tracks(formulas)
	formula_list_changed.emit(formulas.duplicate(true))
	return true

func update_formula_parameter(index: int, key: String, value: float) -> bool:
	if index < 0 or index >= formulas.size() or state != RunState.EDITING:
		return false
	var next_formulas := formulas.duplicate(true)
	# Legacy helper edits core coefficients. The UI submits its original sources
	# through the adapter; never keep a stale source attached to edited coefficients.
	next_formulas[index].erase("ui_source")
	var parameters: Dictionary = next_formulas[index]["parameters"]
	if not parameters.has(key):
		return false
	parameters[key] = value
	return set_formulas(next_formulas)

func update_formula_x_range(index: int, x_min: float, x_max: float) -> bool:
	if index < 0 or index >= formulas.size() or state != RunState.EDITING:
		return false
	var next_formulas := formulas.duplicate(true)
	next_formulas[index]["x_range"] = Vector2(x_min, x_max)
	if not next_formulas[index].get("ui_source", {}).is_empty():
		next_formulas[index].ui_source.domain = Vector2(x_min, x_max)
	return set_formulas(next_formulas)

func add_formula(module_type: String) -> bool:
	if state != RunState.EDITING or formulas.size() >= int(current_level.get("max_functions", GameConstants.MAX_FORMULAS)):
		return false
	var next_formulas := formulas.duplicate(true)
	var id := "%s-%d" % [module_type, Time.get_ticks_msec()]
	if module_type == GameConstants.MODULE_QUADRATIC:
		next_formulas.append(FormulaModel.create_quadratic(id, -0.2, 0.0, 1.0))
	elif module_type == GameConstants.MODULE_LINE:
		next_formulas.append(FormulaModel.create_line(id, -0.2, 0.0))
	elif module_type == GameConstants.MODULE_SINE:
		next_formulas.append({"id": id, "type": "sine", "parameters": {"a": 1.0, "b": 0.3, "h": 0.0, "k": 0.0}, "x_range": Vector2(-4, 8)})
	else:
		return false
	return set_formulas(next_formulas)

func remove_formula(index: int) -> bool:
	if state != RunState.EDITING or index < 0 or index >= formulas.size():
		return false
	var next_formulas := formulas.duplicate(true)
	next_formulas.remove_at(index)
	return set_formulas(next_formulas)

func start_run() -> bool:
	if state != RunState.EDITING and state != RunState.FAILED and state != RunState.SUCCESS:
		return false
	var result := FormulaValidator.validate(formulas, current_level)
	if not result["ok"]:
		validation_failed.emit(result["errors"])
		return false
	if state != RunState.EDITING:
		reset_run()
	state = RunState.RUNNING
	elapsed_time = 0.0
	time_left = float(current_level["time_limit"])
	failure_reason = ""
	game_world.rebuild_tracks(formulas)
	game_world.start_simulation()
	status_changed.emit(status_name())
	editing_lock_changed.emit(true)
	return true

func reset_run() -> void:
	state = RunState.EDITING
	elapsed_time = 0.0
	time_left = float(current_level.get("time_limit", 0.0))
	failure_reason = ""
	game_world.reset_ball()
	status_changed.emit(status_name())
	editing_lock_changed.emit(false)

func toggle_pause() -> void:
	if state == RunState.RUNNING:
		state = RunState.PAUSED
		game_world.set_simulation_paused(true)
	elif state == RunState.PAUSED:
		state = RunState.RUNNING
		game_world.set_simulation_paused(false)
	else:
		return
	status_changed.emit(status_name())

func finish_run(success: bool, reason: String) -> void:
	if state != RunState.RUNNING and state != RunState.PAUSED:
		return
	state = RunState.SUCCESS if success else RunState.FAILED
	failure_reason = reason
	game_world.stop_simulation()
	if success:
		last_save_ok = SaveManager.mark_level_completed(String(current_level.get("id", "")), elapsed_time, formulas.size()) if save_enabled else true
	status_changed.emit(status_name())
	run_finished.emit(success, reason, elapsed_time)

func status_name() -> String:
	return RunState.keys()[state]

func snapshot() -> Dictionary:
	return {
		"status": status_name(),
		"level_index": current_level_index,
		"level_id": current_level.get("id", ""),
		"ball_position": game_world.ball_world_position(),
		"ball_velocity": game_world.ball.world_velocity(),
		"checkpoint_index": game_world.checkpoint_index,
		"time_left": time_left,
		"elapsed_time": elapsed_time,
		"failure_reason": failure_reason,
	}

func _on_checkpoint_reached(_index: int) -> void:
	pass

func _on_goal_reached() -> void:
	if state != RunState.RUNNING:
		return
	finish_run(true, "通关")

func _on_world_failed(reason: String) -> void:
	if state != RunState.RUNNING and state != RunState.PAUSED:
		return
	finish_run(false, reason)

func _on_ball_state_changed(position_value: Vector2, velocity: Vector2) -> void:
	simulation_updated.emit(position_value, {
		"velocity": velocity,
		"status": status_name(),
		"time_left": time_left,
	}, game_world.checkpoint_index)

func _on_tracks_rebuilt(segments: Array) -> void:
	curve_points_updated.emit(segments)
