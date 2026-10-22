extends SceneTree
const Repository = preload("res://scripts/core/level_repository.gd")
const Catalog = preload("res://scripts/core/formula_catalog.gd")
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	for data in Repository.load_levels():
		var core = load("res://scenes/core_world.tscn").instantiate()
		root.add_child(core)
		core.save_enabled = false
		var level := LevelData.from_ui(data)
		level.formulas = Catalog.to_core_list(data.reference_formulas)
		core.configure_level(level)
		await physics_frame
		core.start_run()
		print("PROBE ", data.id)
		for i in 2400:
			await physics_frame
			if i % 60 == 0:
				print("t=", snappedf(core.elapsed_time,0.01), " p=",core.game_world.ball_world_position()," v=",core.game_world.ball.world_velocity())
			if core.state != LevelController.RunState.RUNNING:
				print(core.snapshot())
				break
		core.queue_free()
		await process_frame
	quit()
