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
	check(is_equal_approx(float(GameConstants.MATERIALS.quadratic.restitution), 0.80), "Quadratic restitution")
	check(is_equal_approx(float(GameConstants.MATERIALS.quadratic.friction), 0.08), "Quadratic friction")
	check(is_zero_approx(float(GameConstants.MATERIALS.line.restitution)), "Line remains non-bouncy")
	check(is_zero_approx(float(GameConstants.MATERIALS.sine.restitution)), "Sine remains non-bouncy")

	SaveManager.save_path = "user://elasticity-performance-progress.json"
	if FileAccess.file_exists(SaveManager.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.save_path))
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	ui.unlocked_level = ui.levels.size() - 1
	var bounce_index := 0
	for index in ui.levels.size():
		if ui.levels[index].id == "quiet_valley":
			bounce_index = index
			break
	check(ui.load_level(bounce_index), "Load bounce level")
	await process_frame

	var adapter = ui.adapter
	var builder: TrackBuilder = adapter.core.game_world.track_builder
	check(builder.get_child_count() == 0, "Editing preview has no physics bodies")
	var initial_preview_count: int = builder.preview_rebuild_count
	var initial_flush_count: int = adapter.formula_flush_count
	var reference: Array = ui.levels[bounce_index].reference_formulas.duplicate(true)
	for index in 80:
		var candidate: Array = reference.duplicate(true)
		candidate[0].parameters.a = 0.04 if index % 2 == 0 else 0.05
		check(adapter.update_formulas(candidate), "Queue formula update")
	check(adapter.formula_flush_count == initial_flush_count, "Formula changes coalesce before render frame")
	await process_frame
	check(adapter.formula_flush_count == initial_flush_count + 1, "Formula changes flush once per render frame")
	check(builder.preview_rebuild_count == initial_preview_count + 1, "Preview rebuilds once")
	check(builder.get_child_count() == 0 and builder.collision_shape_count == 0, "Preview does not create colliders")

	check(adapter.update_formulas(reference), "Queue reference formula")
	await process_frame
	check(adapter.start(), "Start bounce reference")
	check(builder.get_child_count() == reference.size(), "Run builds one body per formula")
	check(builder.collision_shape_count > 0, "Run builds collision shapes")

	var physics_frames := 0
	var ui_updates_before: int = adapter.ui_update_count
	var previous_vertical_speed: float = adapter.core.game_world.ball.world_velocity().y
	var first_upward_speed := 0.0
	var maximum_height_after_bounce := -INF
	var bounce_detected := false
	for frame in 1200:
		await physics_frame
		physics_frames += 1
		var velocity: Vector2 = adapter.core.game_world.ball.world_velocity()
		var position: Vector2 = adapter.core.game_world.ball_world_position()
		if not bounce_detected and previous_vertical_speed < -0.2 and velocity.y > 0.2:
			bounce_detected = true
			first_upward_speed = velocity.y
		if bounce_detected:
			maximum_height_after_bounce = maxf(maximum_height_after_bounce, position.y)
		previous_vertical_speed = velocity.y
		if adapter.state != "running":
			break
	await process_frame
	var emitted_updates: int = adapter.ui_update_count - ui_updates_before
	check(bounce_detected and first_upward_speed > 0.2, "Quadratic track produces a visible upward bounce")
	check(adapter.state == "success", "Stronger bounce keeps reference solution valid")
	check(emitted_updates <= ceili(physics_frames * 0.65) + 4, "UI updates stay near 60 Hz")
	print("ELASTICITY_METRICS physics_frames=%d ui_updates=%d shapes=%d first_upward=%.4f apex=%.4f" % [
		physics_frames, emitted_updates, builder.collision_shape_count, first_upward_speed, maximum_height_after_bounce
	])

	ui.queue_free()
	await process_frame
	if FileAccess.file_exists(SaveManager.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.save_path))
	for failure in failures:
		push_error(failure)
	print("ELASTICITY_PERFORMANCE_TEST: %s (%d assertions)" % ["PASS" if failures.is_empty() else "FAIL", assertions])
	quit(0 if failures.is_empty() else 1)
