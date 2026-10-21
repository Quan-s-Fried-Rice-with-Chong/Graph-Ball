extends SceneTree

const Catalog = preload("res://scripts/core/formula_catalog.gd")
const Repository = preload("res://scripts/core/level_repository.gd")
const Demo = preload("res://scripts/adapters/demo_run_adapter.gd")
const SOLUTIONS = [
	{"template": "linear", "parameters": {"a": -0.4, "b": 2.2}},
	{"template": "quadratic", "parameters": {"a": 0.07, "h": 1.0, "k": -1.0}},
	{"template": "sine", "parameters": {"a": 1.5, "b": 0.65, "h": 0.0, "k": 1.0}},
	{"template": "sine", "parameters": {"a": 2.0, "b": 0.5, "h": 1.0, "k": 1.0}}
]

var failures: Array = []
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: " + description)

func _run() -> void:
	var levels := Repository.load_levels()
	check(levels.size() == 4, "four candidate levels load")
	check(not Catalog.validate("unknown", {}).is_empty(), "unknown template rejected")
	check(not Catalog.validate("linear", {"a": NAN, "b": 2.2}).is_empty(), "invalid numeric input rejected")
	for i in range(levels.size()):
		var adapter := Demo.new()
		root.add_child(adapter)
		adapter.set_physics_process(false)
		var data: Dictionary = levels[i]
		adapter.configure(data, data.initial_template, data.initial_parameters[data.initial_template])
		adapter.start()
		for _frame in range(1700):
			adapter.advance(1.0 / 120.0)
			if adapter.state != "running":
				break
		check(adapter.state == "failed" and not adapter.last_result.reason.is_empty(), "level %d initial attempt gives useful feedback" % (i + 1))
		var solution: Dictionary = SOLUTIONS[i]
		adapter.configure(data, solution.template, solution.parameters)
		adapter.start()
		check(adapter.state == "running", "level %d reference connects to start" % (i + 1))
		adapter.pause_or_resume()
		var elapsed: float = adapter.elapsed
		adapter.advance(1.0)
		check(adapter.state == "paused" and adapter.elapsed == elapsed, "level %d pause freezes motion" % (i + 1))
		adapter.pause_or_resume()
		for _frame in range(1700):
			adapter.advance(1.0 / 120.0)
			if adapter.state != "running":
				break
		check(adapter.state == "success", "level %d reference succeeds in DEMO mode" % (i + 1))
		check(not false in adapter.reached, "level %d all checkpoints reached" % (i + 1))
		adapter.retry()
		check(adapter.parameters == solution.parameters and adapter.elapsed == 0 and adapter.state == "editing", "level %d retry preserves parameters and clears run" % (i + 1))
		adapter.queue_free()
	var runner := Demo.new()
	root.add_child(runner)
	runner.set_physics_process(false)
	var blocked: Dictionary = levels[0].duplicate(true)
	blocked.obstacles = [Rect2(-0.01, 1.5, 0.02, 1.5)]
	runner.configure(blocked, "linear", SOLUTIONS[0].parameters)
	runner.start()
	runner.advance(3.0)
	check(runner.state == "failed" and "障碍" in runner.last_result.reason, "large time step cannot tunnel through a thin obstacle")
	var missing: Dictionary = levels[0].duplicate(true)
	missing.checkpoints = [Vector2(0, 6)]
	runner.configure(missing, "linear", SOLUTIONS[0].parameters)
	runner.start()
	runner.advance(5.0)
	check(runner.state == "failed" and "检查点" in runner.last_result.reason, "goal cannot bypass a mandatory checkpoint")
	var timed: Dictionary = levels[0].duplicate(true)
	timed.time_limit = 0.1
	runner.configure(timed, "linear", SOLUTIONS[0].parameters)
	runner.start()
	runner.advance(0.2)
	check(runner.state == "failed" and "时间" in runner.last_result.reason, "timeout reports a useful reason")
	var bounded: Dictionary = levels[0].duplicate(true)
	bounded.bounds = Rect2(-9, 3, 20, 5)
	runner.configure(bounded, "linear", SOLUTIONS[0].parameters)
	runner.start()
	runner.advance(3.0)
	check(runner.state == "failed" and "边界" in runner.last_result.reason, "world boundary failure independent of camera")
	runner.queue_free()
	await process_frame
	var main = load("res://scenes/main.tscn").instantiate()
	root.size = Vector2i(1440, 900)
	root.add_child(main)
	current_scene = main
	await process_frame
	main.adapter.set_physics_process(false)
	check(main.current_screen == "menu" and main.main_menu.visible and not main.get_node("%GamePage").visible, "application opens on main menu")
	main.open_help()
	check(main.get_node("%HelpModal").visible and main.current_screen == "menu", "help opens from main menu")
	main.close_help()
	main.open_levels()
	main.close_levels()
	check(main.current_screen == "menu" and main.main_menu.visible, "closing level selection returns to menu")
	main.main_menu.start_requested.emit()
	check(main.current_screen == "game" and not main.main_menu.visible, "start menu opens game")
	main._progress_path = "res://tests/.test_progress.cfg"
	main.completed = []
	main.unlocked_level = 0
	main.load_level(0)
	check(not main.formula_panel.get_node("DetailsMargin").visible, "formula details collapsed by default")
	main.formula_panel.get_node("%ExpandButton").button_pressed = true
	check(main.formula_panel.get_node("DetailsMargin").visible, "arrow expands template and parameters")
	main.formula_panel.get_node("%ExpandButton").button_pressed = false
	check(not main.formula_panel.get_node("DetailsMargin").visible, "arrow collapses details")
	for button_name in ["RunButton", "PauseButton", "RetryButton", "ResetButton"]:
		var button = main.get_node("%" + button_name)
		check(button.text.is_empty() and not button.tooltip_text.is_empty(), button_name + " is icon only with tooltip")
	check(not main.load_level(3), "locked level cannot be loaded")
	check(main.formula_panel.set_formula("linear", SOLUTIONS[0].parameters).is_empty(), "UI accepts reference coefficients")
	main.formula_panel._fields.a.spin.value = -0.5
	check(is_equal_approx(main.formula_panel._fields.a.slider.value, -0.5) and is_equal_approx(main.adapter.parameters.a, -0.5), "numeric input updates slider and adapter")
	main.formula_panel._fields.a.slider.value = -0.4
	check(is_equal_approx(main.formula_panel._fields.a.spin.value, -0.4), "slider updates numeric input")
	main.start_run()
	var run_parameters: Dictionary = main.formula_panel.parameters.duplicate()
	check(main.adapter.state == "running", "UI run starts simulation")
	var before_menu: Dictionary = main.formula_panel.parameters.duplicate()
	main.open_main_menu()
	check(main.current_screen == "menu" and main.adapter.state == "paused", "returning to menu pauses the ball")
	main.enter_game()
	check(main.adapter.state == "paused" and main.formula_panel.parameters == before_menu, "return from menu retains run and parameters")
	main.adapter.pause_or_resume()
	check(not main.formula_panel.set_formula("linear", {"a": 0, "b": 1}).is_empty(), "parameters cannot change during a run")
	main.open_help()
	check(main.adapter.state == "paused", "opening help pauses a running ball")
	main.close_help()
	main._toggle_hint()
	check(main.get_node("%HintModal").visible, "hint button opens hint dialog")
	main.close_hint()
	main.adapter.pause_or_resume()
	main.adapter.advance(5.0)
	await process_frame
	check(main.result_dialog.visible and main.adapter.state == "success", "UI displays successful result")
	check(main.unlocked_level == 1, "successful result unlocks next level")
	var key := InputEventKey.new()
	key.keycode = KEY_R
	key.pressed = true
	main._input(key)
	check(main.result_dialog.visible and main.adapter.state == "success", "modal blocks background shortcuts")
	main.retry_run()
	check(main.formula_panel.parameters == run_parameters and main.adapter.parameters == run_parameters and main.adapter.state == "editing", "UI retry preserves formula")
	main.reset_level()
	check(main.formula_panel.parameters == levels[0].initial_parameters.linear, "UI reset restores initial formula")
	main.load_level(1)
	check(main.current_level == 1 and main.formula_panel.template_id == "quadratic", "next level configures correct panel")
	main.graph.fit_view()
	var point := Vector2(-3.2, 1.75)
	check(main.graph.screen_to_world(main.graph.world_to_screen(point)).is_equal_approx(point), "graph coordinate conversion preserves world coordinates")
	main.graph.zoom_at(1000, main.graph.size * 0.5)
	check(main.graph.zoom_factor <= 3.0, "zoom upper bound")
	main.graph.zoom_at(0.0001, main.graph.size * 0.5)
	check(main.graph.zoom_factor >= 0.65, "zoom lower bound")
	var clipped: PackedVector2Array = main.graph.clip_segment_to_bounds(Vector2(-100, 0), Vector2(100, 0))
	check(clipped.size() == 2 and is_equal_approx(clipped[0].x, main.graph.bounds.position.x) and is_equal_approx(clipped[1].x, main.graph.bounds.end.x), "curve segment clips to drawing frame")
	check(main.graph.clip_segment_to_bounds(Vector2(-100, 100), Vector2(100, 100)).is_empty(), "curve outside drawing frame is hidden")
	main._load_progress()
	check(main.completed.has(levels[0].id), "demo progress survives reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://tests/.test_progress.cfg"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var report := FileAccess.open("res://artifacts/smoke_report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "mode": "constant-speed demo; not a physics validation"}, "  "))
	report.close()
	print("PROTOTYPE_SMOKE: %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
