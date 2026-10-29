extends SceneTree
const Repository = preload("res://scripts/core/level_repository.gd")
const Catalog = preload("res://scripts/core/formula_catalog.gd")
var failures: Array[String] = []
var assertions := 0
func _init() -> void:
	_run.call_deferred()
func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
func _run() -> void:
	var document = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))
	check(Repository.validate_document(document).is_empty(), "Official JSON validation")
	var broken: Dictionary = document.duplicate(true)
	broken.levels[1].id = broken.levels[0].id
	check(not Repository.validate_document(broken).is_empty(), "Duplicate IDs rejected")
	broken = document.duplicate(true)
	broken.levels[0].reference_formulas[0].parameters.a = "invalid"
	check(not Repository.validate_document(broken).is_empty(), "Malformed parameters rejected")
	check(not Repository.validate_document({"schema_version": 99}).is_empty(), "Unknown schema rejected")
	var levels := LevelData.all_levels()
	check(levels.size() == 7, "Seven progressive levels")
	check(document.levels[0].max_formulas == 1 and not bool(document.levels[0].tutorial.features.add_formula), "Tutorial one hides add")
	check(bool(document.levels[1].tutorial.features.add_formula) and not bool(document.levels[1].tutorial.features.template_picker), "Tutorial two unlocks add only")
	check(bool(document.levels[2].tutorial.features.template_picker) and document.levels[2].templates.size() == 2, "Tutorial three unlocks templates")
	for level in levels:
		check(LevelData.validate(level).ok, "Level validation: " + level.id)
		for formula in level.formulas:
			var segments := CurveSampler.sample(formula, level.boundary)
			check(not segments.is_empty(), "Nonempty track: " + level.id)
			for segment in segments:
				check(BoundaryClipper.point_inside(segment.a, level.boundary) and BoundaryClipper.point_inside(segment.b, level.boundary), "Clipped segment")
	var q := {"template": "quadratic", "parameters": {"a": 0.2, "h": 4.0, "k": 5.0}, "domain": Vector2(-8, 8)}
	var core := Catalog.to_core(q)
	var concept_level: Dictionary = levels.filter(func(level): return level.id == "quiet_valley")[0]
	check(is_equal_approx(core.parameters.b, -1.6) and is_equal_approx(core.parameters.c, 8.2), "Vertex conversion")
	check(FormulaValidator.validate([core], concept_level).ok, "Converted coefficients use numerical safety")
	for x in [-4.0, 0.0, 3.0]:
		check(is_equal_approx(FunctionEvaluator.evaluate(core, x), Catalog.evaluate("quadratic", q.parameters, x)), "Equivalent evaluation")
	q.parameters.a = 0.0
	core = Catalog.to_core(q)
	check(core.ui_source.parameters.h == 4.0 and is_equal_approx(FunctionEvaluator.evaluate(core, 2), 5), "a=0 preserves vertex parameters")
	var sine := Catalog.to_core({"template": "sine", "parameters": {"a": 2.0, "b": 0.3, "h": -4.0, "k": 0.0}, "domain": Vector2(-4, 12)})
	check(is_equal_approx(FunctionEvaluator.evaluate(sine, 1), 2 * sin(1.5)), "Sine evaluation")
	check(not FormulaValidator.validate([core, core, core, core], concept_level).ok, "Core enforces three formulas")
	var invalid := core.duplicate(true)
	invalid.x_range = "bad"
	invalid.erase("ui_source")
	check(not FormulaValidator.validate([invalid], concept_level).ok, "Malformed domain rejected")
	invalid = core.duplicate(true)
	invalid.ui_source = "bad"
	check(not FormulaValidator.validate([invalid], concept_level).ok, "Malformed source rejected")
	check(is_equal_approx(FormulaGameWorld.circle_contact(Vector2(-5,0), Vector2(5,0), Vector2.ZERO, 1), 0.4), "Fast swept circle")
	check(not is_finite(FormulaGameWorld.rect_contact(Vector2(-0.9,-0.9), Vector2(-0.8,-0.8), Rect2(0,0,2,2), 1)), "Rounded rectangle avoids false positive")
	check(is_finite(FormulaGameWorld.rect_contact(Vector2(-2,1), Vector2(4,1), Rect2(0,0,2,2), 0.28)), "Fast swept rectangle")
	_test_saves()
	await _test_events()
	for failure in failures:
		push_error(failure)
	print("CORE_SMOKE_TEST: %s (%d assertions)" % ["PASS" if failures.is_empty() else "FAIL", assertions])
	quit(0 if failures.is_empty() else 1)
func _test_saves() -> void:
	SaveManager.save_path = "user://integration-test-progress.json"
	if FileAccess.file_exists(SaveManager.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.save_path))
	check(SaveManager.mark_level_completed("first_line", 10, 3), "Initial save")
	check(SaveManager.mark_level_completed("first_line", 12, 1), "Replace existing save")
	var record: Dictionary = SaveManager.load_progress().completed_levels.first_line
	check(record.best_time == 10 and record.best_formula_count == 1, "Independent best records")
	var legacy := {"version": 1, "content_id": SaveManager.CONTENT_ID, "completed_levels": {"old": {"completed": true, "best_time": 4, "min_formulas": 2}}}
	check(SaveManager.migrate(legacy).completed_levels.old.best_formula_count == 2, "Version 1 migration")
	legacy.content_id = "demo"
	check(SaveManager.migrate(legacy).completed_levels.is_empty(), "Ignore demo saves")
	var future := SaveManager.empty_progress()
	future.version = 999
	var file := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(future))
	file.close()
	check(not SaveManager.mark_level_completed("first_line", 1, 1), "Reject future save overwrite")
	check(JSON.parse_string(FileAccess.get_file_as_string(SaveManager.save_path)).version == 999, "Future save preserved")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.save_path))
func _test_events() -> void:
	var controller = load("res://scenes/core_world.tscn").instantiate()
	root.add_child(controller)
	controller.save_enabled = false
	controller.configure_level(LevelData.get_level(0))
	var original: Array = controller.formulas.duplicate(true)
	check(controller.update_formula_x_range(0, -8.0, 8.0), "Legacy domain helper accepts valid range")
	check(controller.formulas[0].ui_source.domain == Vector2(-8, 8), "Domain helper keeps UI source consistent")
	check(not controller.update_formula_parameter(0, "unknown", 1), "Legacy helper rejects unknown coefficient")
	check(controller.update_formula_parameter(0, "a", -0.4), "Legacy coefficient helper edits core")
	check(controller.formulas[0].get("ui_source", {}).is_empty(), "Core edit clears stale UI source")
	check(not controller.add_formula("unknown"), "Unknown legacy module rejected")
	controller.set_formulas(original)
	var world: FormulaGameWorld = controller.game_world
	world.boundary = PackedVector2Array([Vector2(-10,-10), Vector2(10,-10), Vector2(10,10), Vector2(-10,10)])
	world.level.checkpoints = [{"position": Vector2(-2,0), "radius": 0.3}, {"position": Vector2(2,0), "radius": 0.3}]
	world.level.goal = {"position": Vector2(5,0), "radius": 0.5}
	world.level.hazards = []
	world.reset_ball()
	var wins := [0]
	var fails := [0]
	world.goal_reached.connect(func(): wins[0] += 1)
	world.world_failed.connect(func(_reason): fails[0] += 1)
	world.check_motion(Vector2(5,0), Vector2(6,0))
	check(wins[0] == 0, "Early goal ignored")
	world.check_motion(Vector2(3,0), Vector2(1,0))
	world.check_motion(Vector2(3,0), Vector2(1,0))
	check(world.reached == [false, true] and world.checkpoint_index == 1, "Any order and once")
	world.check_motion(Vector2(-3,0), Vector2(-1,0))
	world.check_motion(Vector2(4,0), Vector2(6,0))
	check(wins[0] == 1, "All checkpoints unlock goal")
	world.reset_ball()
	check(world.checkpoint_index == 0 and world.reached == [false,false], "Retry clears checkpoints")
	world.level.checkpoints = [{"position": Vector2(0.3,0), "radius": 0.1}]
	world.level.goal = {"position": Vector2.ZERO, "radius": 1.0}
	world.reset_ball()
	world.check_motion(Vector2(-5,0), Vector2(5,0))
	check(wins[0] == 2, "Last checkpoint inside goal during fast pass")
	world.level.checkpoints = []
	world.level.hazards = [{"position": Vector2.ZERO, "radius": 1.0}]
	world.reset_ball()
	world.check_motion(Vector2(-5,0), Vector2(5,0))
	check(fails[0] == 1 and wins[0] == 2, "Hazard priority over goal")
	world.level.hazards = []
	world.level.goal.position = Vector2(0,8)
	world.check_motion(Vector2(9,0), Vector2(11,0))
	check(fails[0] == 2, "Center exits boundary")
	controller.queue_free()
	await process_frame
