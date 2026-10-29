extends SceneTree
## Capture actual rendered pages without touching the player's save.
var ui: Control

func _init() -> void:
	_run.call_deferred()

func _capture(label: String) -> void:
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://artifacts/" + label + ".png")
	if error != OK:
		push_error("Screenshot failed: " + label)
	print("CAPTURE " + label)

func _run() -> void:
	SaveManager.save_path = "user://visual-review-unused.json"
	root.size = Vector2i(1440, 900)
	ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	await _capture("menu-1440")
	ui.open_levels()
	await _capture("levels-1440")
	ui.unlocked_level = ui.levels.size() - 1
	ui.load_level(4)
	ui.formula_panel.set_formulas(ui.levels[4].reference_formulas)
	await _capture("game-1440")
	ui.open_help()
	await _capture("help-1440")
	ui.close_help()
	ui.result_dialog.present({"success": true, "reason": "通关", "elapsed": 12.9, "reached": 3, "total": 3, "formula_count": 2,
		"record": {"best_time": 12.9, "best_formula_count": 2}}, false)
	await _capture("result-1440")
	ui.result_dialog.hide()
	ui.load_level(3)
	root.size = Vector2i(1100, 720)
	await _capture("game-1100")
	ui.queue_free()
	await process_frame
	quit()
