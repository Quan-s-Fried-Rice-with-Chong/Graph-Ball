extends SceneTree
## Launch with a visible renderer. Captures real engine output, not mockups.

var main

func _initialize() -> void:
	_run.call_deferred()

func _capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "res://artifacts/" + name + ".png"
	var error := image.save_png(path)
	if error != OK:
		printerr("VISUAL_CAPTURE_FAILED: " + path)
	else:
		print("VISUAL_CAPTURE: " + path)

func _run() -> void:
	root.size = Vector2i(1440, 900)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _capture("redesign_menu")
	main.enter_game()
	await _capture("redesign_game_collapsed")
	main.formula_panel.set_details_expanded(true)
	await _capture("redesign_game_expanded")
	var hover := InputEventMouseMotion.new()
	hover.position = main.get_node("%RunButton").get_global_rect().get_center()
	hover.global_position = hover.position
	root.push_input(hover, true)
	await create_timer(0.9).timeout
	await _capture("redesign_tooltip")
	main.open_help()
	await _capture("redesign_help")
	main.close_help()
	main._toggle_hint()
	await _capture("redesign_hint")
	main.close_hint()
	main.open_levels()
	await _capture("redesign_levels")
	main.close_levels()
	main.unlocked_level = 3
	main.load_level(3)
	main.formula_panel.set_formula("sine", {"a": 2.0, "b": 0.5, "h": 1.0, "k": 1.0})
	main.formula_panel.set_details_expanded(true)
	await _capture("redesign_sine_expanded")
	main.load_level(1)
	main.formula_panel.set_formula("quadratic", {"a": 0.2, "h": -4.0, "k": 5.0})
	await _capture("redesign_clipping")
	main.load_level(0)
	main.formula_panel.set_details_expanded(true)
	root.size = Vector2i(1100, 720)
	await _capture("redesign_small_window")
	print("VISUAL_REVIEW_COMPLETE")
	quit()
