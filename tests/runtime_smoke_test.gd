extends SceneTree
var failures: Array[String] = []
var assertions := 0
func _init() -> void:
	_run.call_deferred()
func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
func _run() -> void:
	SaveManager.save_path = "user://runtime-test-progress.json"
	if FileAccess.file_exists(SaveManager.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.save_path))
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	await physics_frame
	check(ui.current_screen == "menu" and ui.unlocked_level == 0, "Clean progression")
	check(not ui.load_level(1), "Locked level rejected")
	ui.enter_game()
	ui.formula_panel.add_formula()
	ui.formula_panel.add_formula()
	check(ui.formula_panel.add_formula() == -1 and ui.formula_panel.get_formula_count() == 3, "UI max three")
	ui.reset_level()
	for i in ui.levels.size():
		check(ui.load_level(i), "Load sequential level")
		check(ui.formula_panel.set_formulas(ui.levels[i].reference_formulas).is_empty(), "Apply reference")
		await physics_frame
		ui.start_run()
		check(ui.adapter.state == "running" and ui.graph.view_locked, "Run locks UI")
		if i == 0:
			for frame in 120:
				await physics_frame
			ui.adapter.pause_or_resume()
			await physics_frame
			var position: Vector2 = ui.adapter.core.game_world.ball_world_position()
			var time: float = ui.adapter.core.elapsed_time
			var spin: float = ui.adapter.core.game_world.ball._paused_angular_velocity
			for frame in 30:
				await physics_frame
			check(ui.adapter.core.game_world.ball_world_position().is_equal_approx(position) and ui.adapter.core.elapsed_time == time, "Pause freezes position and time")
			check(not ui.adapter.update_formulas(ui.levels[i].initial_formulas), "Pause prevents editing")
			ui.adapter.pause_or_resume()
			check(is_equal_approx(ui.adapter.core.game_world.ball.angular_velocity, spin), "Resume restores spin")
		for frame in 4200:
			await physics_frame
			if ui.adapter.state != "running":
				break
		await process_frame
		await process_frame
		check(ui.adapter.state == "success", "Reference wins: " + ui.levels[i].id)
		check(ui.adapter.reached.count(true) == ui.adapter.reached.size(), "All checkpoints")
		check(ui.result_dialog.visible, "Result visible")
		check(ui.adapter.last_result.saved, "Saved progress")
		check(ui.unlocked_level == mini(i+1,3), "Next unlock")
		print("REFERENCE_PASS %s time=%.4f formulas=%d" % [ui.levels[i].id, ui.adapter.elapsed, ui.adapter.formulas.size()])
		var retained: Array = ui.formula_panel.get_formulas()
		ui.retry_run()
		check(ui.adapter.state == "editing" and ui.adapter.elapsed == 0 and ui.adapter.reached.count(true) == 0, "Retry resets run")
		check(ui.formula_panel.get_formulas() == retained, "Retry retains configuration")
		await process_frame
		check(ui.adapter.core.game_world.track_builder.get_child_count() == retained.size(), "No duplicate colliders")
	check(SaveManager.load_progress().completed_levels.size() == 4, "Four records stored")
	ui.open_levels()
	check(ui.level_page.get_node("%LevelRoute").cards.size() == ui.levels.size(), "All level cards constructed")
	check(ui.level_page.get_lock_states().count(true) == 0, "All levels replayable")
	ui.queue_free()
	await process_frame
	var reopened = load("res://scenes/main.tscn").instantiate()
	root.add_child(reopened)
	await process_frame
	check(reopened.unlocked_level == 3 and reopened.completed.size() == 4, "Reopen restores progress")
	reopened.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.save_path))
	for failure in failures:
		push_error(failure)
	print("RUNTIME_SMOKE_TEST: %s (%d assertions)" % ["PASS" if failures.is_empty() else "FAIL", assertions])
	quit(0 if failures.is_empty() else 1)
