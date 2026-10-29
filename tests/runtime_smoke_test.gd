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
	await process_frame
	check(ui.tutorial_overlay.is_active() and ui.tutorial_overlay.get_current_step().target == "formula_expand", "Tutorial starts on expand")
	check(not ui.formula_panel.add_section.visible and not ui.formula_panel.get_tutorial_target("formula_picker").visible, "Tutorial one hides advanced features")
	ui.formula_panel.set_details_expanded(true)
	await process_frame
	await process_frame
	check(not ui.tutorial_overlay.next_button.disabled, "Tutorial waits for player after expand")
	ui.tutorial_overlay.advance()
	await process_frame
	check(ui.tutorial_overlay.get_current_step().target == "formula_parameters", "Tutorial advances after expand")
	ui.formula_panel.set_formula("linear", {"a": -0.6, "b": 2.3})
	await process_frame
	await process_frame
	check(ui.tutorial_overlay.get_current_step().target == "formula_parameters", "Tutorial stays on parameter step")
	check(not ui.tutorial_overlay.next_button.disabled, "Tutorial enables continue after parameter change")
	ui.tutorial_overlay.advance()
	await process_frame
	check(ui.tutorial_overlay.get_current_step().target == "formula_domain", "Tutorial advances after parameter change")
	ui.formula_panel.set_domain(0, -8.0, 9.0)
	await process_frame
	await process_frame
	check(ui.tutorial_overlay.get_current_step().target == "formula_domain", "Tutorial stays on domain step")
	ui.tutorial_overlay.advance()
	await process_frame
	check(ui.tutorial_overlay.get_current_step().target == "run_button", "Tutorial advances after domain change")
	check(ui.formula_panel.add_formula() == -1 and ui.formula_panel.get_formula_count() == 1, "Tutorial starts with one formula")
	ui.reset_level()
	for i in ui.levels.size():
		check(ui.load_level(i), "Load sequential level")
		if i == 1:
			check(ui.formula_panel.add_section.visible and not ui.formula_panel.get_tutorial_target("formula_picker").visible, "Tutorial two unlocks add only")
			var first_params: Dictionary = ui.formula_panel.get_formulas()[0].parameters.duplicate()
			ui.formula_panel.add_formula()
			var second_params: Dictionary = ui.formula_panel.get_formulas()[1].parameters
			check(not is_equal_approx(float(first_params.b), float(second_params.b)), "New formula is vertically offset")
			ui.formula_panel.add_formula()
			var third_params: Dictionary = ui.formula_panel.get_formulas()[2].parameters
			check(not is_equal_approx(float(second_params.b), float(third_params.b)), "Third formula is vertically offset")
			check(ui.formula_panel.add_formula() == -1 and ui.formula_panel.get_formula_count() == 3, "UI max three")
		if i == 2:
			check(ui.formula_panel.get_tutorial_target("formula_picker").visible, "Tutorial three unlocks template picker")
			await process_frame
			check(ui.tutorial_overlay.get_current_step().target == "obstacle", "Tutorial three starts with obstacle")
			ui.tutorial_overlay.advance()
			await process_frame
			ui.formula_panel.set_details_expanded(true)
			await process_frame
			await process_frame
			check(ui.tutorial_overlay.get_current_step().target == "formula_expand", "Tutorial waits after expand in lesson three")
			ui.tutorial_overlay.advance()
			await process_frame
			check(ui.tutorial_overlay.get_current_step().target == "formula_picker", "Tutorial three reveals picker")
			ui.formula_panel.set_formula("quadratic", {"a": 0.05, "h": 3, "k": -2})
			await process_frame
			await process_frame
			check(ui.tutorial_overlay.get_current_step().target == "formula_picker", "Tutorial stays on template step")
			ui.tutorial_overlay.advance()
			await process_frame
			check(ui.tutorial_overlay.get_current_step().target == "formula_parameters", "Tutorial advances after template switch")
		check(ui.formula_panel.set_formulas(ui.levels[i].reference_formulas).is_empty(), "Apply reference")
		await physics_frame
		var speed_button: Button = ui.get_node("%SpeedButton")
		check(speed_button.disabled and Engine.time_scale == 1.0, "Speed disabled while editing")
		ui.start_run()
		check(ui.adapter.state == "running" and ui.graph.view_locked, "Run locks UI")
		if i == 0:
			speed_button.button_pressed = true
			await physics_frame
			check(not speed_button.disabled and Engine.time_scale == 2.0, "Double speed applies while running")
			var fast_time: float = ui.adapter.core.elapsed_time
			await physics_frame
			check(ui.adapter.core.elapsed_time > fast_time, "Double speed advances simulation")
			ui.adapter.pause_or_resume()
			await physics_frame
			check(ui.adapter.state == "paused" and Engine.time_scale == 1.0, "Pause restores UI time scale")
			ui.adapter.pause_or_resume()
			await physics_frame
			check(ui.adapter.state == "running" and Engine.time_scale == 2.0, "Resume keeps selected speed")
			speed_button.button_pressed = false
			check(Engine.time_scale == 1.0, "Disabling double speed restores normal rate")
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
		check(not ui.adapter.core.game_world.running and ui.adapter.core.game_world.ball.freeze, "Success freezes ball immediately")
		check(ui.result_dialog.visible, "Result visible")
		check(speed_button.disabled and Engine.time_scale == 1.0, "Speed resets after run ends")
		check(ui.result_dialog.summary.text.split("\n").size() == 4, "Result summary has four rows")
		check(not ui.result_dialog.summary.text.contains("检查点") and not ui.result_dialog.summary.text.contains("公式越少"), "Result summary is concise")
		check(ui.adapter.last_result.saved, "Saved progress")
		check(ui.unlocked_level == mini(i+1, ui.levels.size()-1), "Next unlock")
		print("REFERENCE_PASS %s time=%.4f formulas=%d" % [ui.levels[i].id, ui.adapter.elapsed, ui.adapter.formulas.size()])
		var retained: Array = ui.formula_panel.get_formulas()
		ui.retry_run()
		check(ui.adapter.state == "editing" and ui.adapter.elapsed == 0 and ui.adapter.reached.count(true) == 0, "Retry resets run")
		check(ui.formula_panel.get_formulas() == retained, "Retry retains configuration")
		await process_frame
		check(ui.adapter.core.game_world.track_builder.get_child_count() == retained.size(), "No duplicate colliders")
	check(SaveManager.load_progress().completed_levels.size() == ui.levels.size(), "All records stored")
	ui.open_levels()
	check(ui.level_page.get_node("%LevelRoute").cards.size() == ui.levels.size(), "All level cards constructed")
	check(ui.level_page.get_lock_states().count(true) == 0, "All levels replayable")
	ui.queue_free()
	await process_frame
	var reopened = load("res://scenes/main.tscn").instantiate()
	root.add_child(reopened)
	await process_frame
	check(reopened.unlocked_level == reopened.levels.size()-1 and reopened.completed.size() == reopened.levels.size(), "Reopen restores progress")
	reopened.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.save_path))
	for failure in failures:
		push_error(failure)
	print("RUNTIME_SMOKE_TEST: %s (%d assertions)" % ["PASS" if failures.is_empty() else "FAIL", assertions])
	quit(0 if failures.is_empty() else 1)
