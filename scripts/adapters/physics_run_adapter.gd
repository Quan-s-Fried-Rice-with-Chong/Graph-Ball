extends Node

signal curve_changed(segments: Array)
signal ball_moved(point: Vector2, elapsed_time: float)
signal checkpoints_changed(reached: Array)
signal state_changed(state: String)
signal run_finished(result: Dictionary)
signal validation_failed(message: String)

const Catalog = preload("res://scripts/core/formula_catalog.gd")
const CoreScene = preload("res://scenes/core_world.tscn")
const UI_UPDATE_INTERVAL := 1.0 / 60.0
var core: LevelController
var level: Dictionary = {}
var formulas: Array = []
var state := "editing"
var elapsed := 0.0
var reached: Array = []
var ball_position := Vector2.ZERO
var last_result: Dictionary = {}
var _generation := 0
var _pending_sources: Array = []
var _pending_core_formulas: Array = []
var _preview_pending := false
var _simulation_dirty := false
var _ui_accumulator := 0.0
var ui_update_count := 0
var formula_flush_count := 0

func _ready() -> void:
	core = CoreScene.instantiate()
	add_child(core)
	core.curve_points_updated.connect(func(segments: Array): curve_changed.emit(segments))
	core.status_changed.connect(_sync_state)
	core.simulation_updated.connect(_on_simulation)
	core.run_finished.connect(_on_finished)
	core.validation_failed.connect(func(errors: Array): validation_failed.emit("\n".join(errors)))

func _process(delta: float) -> void:
	if _preview_pending:
		_flush_pending_formulas(false)
	if not _simulation_dirty:
		return
	_ui_accumulator += delta
	if state != "running" or _ui_accumulator >= UI_UPDATE_INTERVAL:
		_flush_simulation_update()

func configure_formulas(data: Dictionary, sources: Array) -> void:
	_generation += 1
	level = data.duplicate(true)
	formulas = sources.duplicate(true)
	last_result = {}
	_pending_sources = []
	_pending_core_formulas = []
	_preview_pending = false
	_simulation_dirty = false
	_ui_accumulator = 0.0
	var converted := LevelData.from_ui(level)
	converted.formulas = Catalog.to_core_list(formulas)
	if core.configure_level(converted, false):
		_sync_ball(true)

func update_formulas(sources: Array) -> bool:
	if state in ["running", "paused"]:
		return false
	if state != "editing":
		retry()
	var next := Catalog.to_core_list(sources)
	var result := FormulaValidator.validate(next, core.current_level)
	if not result["ok"]:
		validation_failed.emit("\n".join(result["errors"]))
		return false
	_pending_sources = sources.duplicate(true)
	_pending_core_formulas = result["formulas"]
	_preview_pending = true
	return true

func start() -> bool:
	if state != "editing":
		return false
	if not _flush_pending_formulas(true):
		return false
	last_result = {}
	var ok := core.start_run()
	_sync_ball(true)
	return ok

func retry() -> void:
	_generation += 1
	last_result = {}
	_pending_sources = []
	_pending_core_formulas = []
	_preview_pending = false
	_simulation_dirty = false
	_ui_accumulator = 0.0
	core.reset_run()
	_sync_ball(true)

func pause_or_resume() -> void:
	core.toggle_pause()

func _sync_state(value: String) -> void:
	state = value.to_lower()
	if state != "running" and _simulation_dirty:
		_flush_simulation_update()
	state_changed.emit(state)

func _sync_ball(force_checkpoints: bool = false) -> void:
	elapsed = core.elapsed_time
	ball_position = core.game_world.ball_world_position()
	var next_reached: Array = core.game_world.reached.duplicate()
	if force_checkpoints or next_reached != reached:
		reached = next_reached
		checkpoints_changed.emit(reached)
	ball_moved.emit(ball_position, elapsed)
	ui_update_count += 1

func _flush_pending_formulas(for_start: bool) -> bool:
	if not _preview_pending:
		return true
	_preview_pending = false
	var next_sources := _pending_sources.duplicate(true)
	var next_core := _pending_core_formulas.duplicate(true)
	_pending_sources = []
	_pending_core_formulas = []
	if not core.set_formulas(next_core, false, not for_start):
		return false
	formulas = next_sources
	formula_flush_count += 1
	return true

func _flush_simulation_update() -> void:
	if not _simulation_dirty:
		return
	_simulation_dirty = false
	_ui_accumulator = fmod(_ui_accumulator, UI_UPDATE_INTERVAL)
	_sync_ball()

func _on_simulation(_position: Vector2, _ball_state: Dictionary, _count: int) -> void:
	_simulation_dirty = true

func _on_finished(success: bool, reason: String, time: float) -> void:
	_simulation_dirty = false
	_ui_accumulator = 0.0
	_sync_ball(true)
	last_result = {"success": success, "reason": reason, "elapsed": time,
		"reached": reached.count(true), "total": reached.size(), "formula_count": formulas.size(), "saved": core.last_save_ok,
		"record": SaveManager.load_progress().completed_levels.get(level.get("id", ""), {})}
	# Defer modal construction until physics query flushing is complete.
	_deliver_result.call_deferred(_generation, last_result.duplicate(true))

func _deliver_result(generation: int, result: Dictionary) -> void:
	if generation == _generation and state in ["success", "failed"]:
		run_finished.emit(result)
