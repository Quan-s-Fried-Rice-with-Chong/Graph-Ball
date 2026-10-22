extends Node

signal curve_changed(segments: Array)
signal ball_moved(point: Vector2, elapsed_time: float)
signal checkpoints_changed(reached: Array)
signal state_changed(state: String)
signal run_finished(result: Dictionary)
signal validation_failed(message: String)

const Catalog = preload("res://scripts/core/formula_catalog.gd")
const CoreScene = preload("res://scenes/core_world.tscn")
var core: LevelController
var level: Dictionary = {}
var formulas: Array = []
var state := "editing"
var elapsed := 0.0
var reached: Array = []
var ball_position := Vector2.ZERO
var last_result: Dictionary = {}
var _generation := 0

func _ready() -> void:
	core = CoreScene.instantiate()
	add_child(core)
	core.curve_points_updated.connect(func(segments: Array): curve_changed.emit(segments))
	core.status_changed.connect(_sync_state)
	core.simulation_updated.connect(_on_simulation)
	core.run_finished.connect(_on_finished)
	core.validation_failed.connect(func(errors: Array): validation_failed.emit("\n".join(errors)))

func configure_formulas(data: Dictionary, sources: Array) -> void:
	_generation += 1
	level = data.duplicate(true)
	formulas = sources.duplicate(true)
	last_result = {}
	var converted := LevelData.from_ui(level)
	converted.formulas = Catalog.to_core_list(formulas)
	if core.configure_level(converted):
		_sync_ball()

func update_formulas(sources: Array) -> bool:
	if state in ["running", "paused"]:
		return false
	if state != "editing":
		retry()
	var next := Catalog.to_core_list(sources)
	if not core.set_formulas(next):
		return false
	formulas = sources.duplicate(true)
	return true

func start() -> bool:
	if state != "editing":
		return false
	last_result = {}
	var ok := core.start_run()
	_sync_ball()
	return ok

func retry() -> void:
	_generation += 1
	last_result = {}
	core.reset_run()
	_sync_ball()

func pause_or_resume() -> void:
	core.toggle_pause()

func _sync_state(value: String) -> void:
	state = value.to_lower()
	state_changed.emit(state)

func _sync_ball() -> void:
	elapsed = core.elapsed_time
	ball_position = core.game_world.ball_world_position()
	reached = core.game_world.reached.duplicate()
	checkpoints_changed.emit(reached)
	ball_moved.emit(ball_position, elapsed)

func _on_simulation(_position: Vector2, _ball_state: Dictionary, _count: int) -> void:
	_sync_ball()

func _on_finished(success: bool, reason: String, time: float) -> void:
	_sync_ball()
	last_result = {"success": success, "reason": reason, "elapsed": time,
		"reached": reached.count(true), "total": reached.size(), "formula_count": formulas.size(), "saved": core.last_save_ok,
		"record": SaveManager.load_progress().completed_levels.get(level.get("id", ""), {})}
	# Defer modal construction until physics query flushing is complete.
	_deliver_result.call_deferred(_generation, last_result.duplicate(true))

func _deliver_result(generation: int, result: Dictionary) -> void:
	if generation == _generation and state in ["success", "failed"]:
		run_finished.emit(result)
