extends Control

const Catalog = preload("res://scripts/core/formula_catalog.gd")
const Levels = preload("res://scripts/core/level_repository.gd")
const UITheme = preload("res://scripts/ui/ui_theme.gd")

@onready var formula_panel = %FormulaPanel
@onready var graph = %GraphCanvas
@onready var adapter = $RunAdapter
@onready var result_dialog = %ResultDialog
@onready var main_menu = %MainMenu

var levels: Array = []
var current_level := 0
var unlocked_level := 0
var completed: Array = []
var _loading := false
var _progress_path := "user://b_prototype_progress.cfg"
var current_screen := "menu"
var _has_entered_game := false
var _booting := true

func _ready() -> void:
	theme = UITheme.create()
	levels = Levels.load_levels()
	if levels.is_empty():
		%StatusMessage.text = "关卡数据无法读取，请检查 data/levels.json。"
		%RunButton.disabled = true
		return
	if OS.get_cmdline_user_args().has("--prototype-test"):
		_progress_path = "res://tests/.test_progress.cfg"
	_load_progress()
	_connect_controls()
	load_level(0)
	open_main_menu()
	_booting = false

func _connect_controls() -> void:
	formula_panel.formula_changed.connect(_on_formula_changed)
	adapter.curve_changed.connect(graph.set_curve)
	adapter.ball_moved.connect(_on_ball_moved)
	adapter.checkpoints_changed.connect(_on_checkpoints_changed)
	adapter.state_changed.connect(_on_state_changed)
	adapter.run_finished.connect(_on_run_finished)
	%RunButton.pressed.connect(start_run)
	%PauseButton.pressed.connect(adapter.pause_or_resume)
	%RetryButton.pressed.connect(retry_run)
	%ResetButton.pressed.connect(reset_level)
	%FitButton.pressed.connect(graph.fit_view)
	%ZoomInButton.pressed.connect(func(): graph.zoom_at(1.2, graph.size * 0.5))
	%ZoomOutButton.pressed.connect(func(): graph.zoom_at(1.0 / 1.2, graph.size * 0.5))
	graph.view_changed.connect(func(value: float): %ZoomValue.text = "%d%%" % roundi(value * 100.0))
	graph.cursor_moved.connect(func(point: Vector2): %CursorValue.text = "x  %.2f    y  %.2f" % [point.x, point.y])
	%HintButton.pressed.connect(_toggle_hint)
	%LevelsButton.pressed.connect(open_levels)
	%HelpButton.pressed.connect(open_help)
	%MainMenuButton.pressed.connect(open_main_menu)
	main_menu.start_requested.connect(enter_game)
	main_menu.levels_requested.connect(open_levels)
	main_menu.help_requested.connect(open_help)
	%CloseLevelsButton.pressed.connect(close_levels)
	%CloseHelpButton.pressed.connect(close_help)
	%CloseHintButton.pressed.connect(close_hint)
	result_dialog.retry_requested.connect(retry_run)
	result_dialog.next_requested.connect(_next_level)
	result_dialog.levels_requested.connect(open_levels)

func load_level(index: int) -> bool:
	if index < 0 or index >= levels.size() or index > unlocked_level:
		return false
	_loading = true
	current_level = index
	var data: Dictionary = levels[index]
	result_dialog.hide()
	%LevelModal.hide()
	%HelpModal.hide()
	%HintModal.hide()
	%LevelNumber.text = "%02d" % (index + 1)
	%LevelTitle.text = data.title
	%LevelTitle.tooltip_text = data.objective
	%HintText.text = data.objective + "\n\n" + data.hint
	formula_panel.set_locked(false)
	formula_panel.configure(data)
	graph.set_level(data)
	adapter.configure(data, formula_panel.template_id, formula_panel.parameters)
	%StatusMessage.text = "演示运动 · 匀速沿轨道"
	current_screen = "game"
	%GamePage.show()
	main_menu.hide()
	if not _booting:
		_has_entered_game = true
	_loading = false
	return true

func enter_game() -> void:
	current_screen = "game"
	_has_entered_game = true
	main_menu.hide()
	%GamePage.show()
	_restore_result_if_needed()

func open_main_menu() -> void:
	if adapter.state == "running":
		adapter.pause_or_resume()
	for modal in [result_dialog, %HelpModal, %LevelModal, %HintModal]:
		modal.hide()
	current_screen = "menu"
	%GamePage.hide()
	main_menu.set_started(_has_entered_game)
	main_menu.show()

func _restore_result_if_needed() -> void:
	if current_screen == "game" and adapter.state in ["success", "failed"]:
		result_dialog.present(adapter.last_result, current_level < levels.size() - 1)

func _on_formula_changed(template_id: String, parameters: Dictionary) -> void:
	if _loading:
		return
	adapter.update_formula(template_id, parameters)
	graph.reset_trail()
	%StatusMessage.text = "参数已更新"

func start_run() -> void:
	if _modal_open() or adapter.state != "editing":
		return
	formula_panel.commit_input()
	graph.remember_curve()
	graph.fit_view()
	adapter.start()

func retry_run() -> void:
	result_dialog.hide()
	adapter.retry()
	graph.reset_trail()
	%StatusMessage.text = "重试：已保留参数"

func reset_level() -> void:
	load_level(current_level)
	%StatusMessage.text = "重置：已恢复初始参数"

func _on_ball_moved(point: Vector2, elapsed: float) -> void:
	graph.set_ball(point, elapsed)
	%TimeValue.text = "%.2f s" % elapsed

func _on_checkpoints_changed(reached: Array) -> void:
	graph.set_checkpoints(reached)
	%CheckpointValue.text = "%d / %d" % [reached.count(true), reached.size()]

func _on_state_changed(state: String) -> void:
	var locked: bool = state in ["running", "paused"]
	formula_panel.set_locked(locked)
	%RunButton.disabled = state != "editing"
	%PauseButton.disabled = not locked
	%PauseButton.symbol = "play" if state == "paused" else "pause"
	%PauseButton.tooltip_text = "继续（空格）" if state == "paused" else "暂停（空格）"
	%RunButton.queue_redraw()
	%PauseButton.queue_redraw()
	var names := {"editing": "编辑中", "running": "运行中", "paused": "已暂停", "success": "已通关", "failed": "待调整"}
	%StateLabel.text = names.get(state, state)
	if state == "running":
		%StatusMessage.text = "演示运动 · 匀速沿轨道"
	elif state == "paused":
		%StatusMessage.text = "已暂停"

func _on_run_finished(result: Dictionary) -> void:
	var saved := true
	if result.success:
		var id: String = levels[current_level].id
		if not completed.has(id):
			completed.append(id)
		unlocked_level = mini(levels.size() - 1, maxi(unlocked_level, current_level + 1))
		saved = _save_progress()
	%StatusMessage.text = "本次演示成功。" if result.success else "重试会保留当前参数。"
	if not saved:
		%StatusMessage.text = "已通关；进度暂存于本次会话，无法写入存档文件。"
	if current_screen == "game":
		result_dialog.present(result, current_level < levels.size() - 1)

func _next_level() -> void:
	if current_level < levels.size() - 1:
		load_level(current_level + 1)
	else:
		open_levels()

func _toggle_hint() -> void:
	if adapter.state == "running":
		adapter.pause_or_resume()
	%HintModal.show()
	%CloseHintButton.grab_focus()

func close_hint() -> void:
	%HintModal.hide()

func open_levels() -> void:
	if adapter.state == "running":
		adapter.pause_or_resume()
	result_dialog.hide()
	%HelpModal.hide()
	for child in %LevelGrid.get_children():
		%LevelGrid.remove_child(child)
		child.queue_free()
	for i in range(levels.size()):
		var data: Dictionary = levels[i]
		var button := Button.new()
		button.name = "Level_%02d" % (i + 1)
		button.custom_minimum_size = Vector2(320, 128)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var status := "已完成" if completed.has(data.id) else ("可以挑战" if i <= unlocked_level else "完成前一关后解锁")
		button.text = "%02d   %s\n%s\n%s" % [i + 1, data.title, data.concept, status]
		button.disabled = i > unlocked_level
		button.pressed.connect(func(): load_level(i))
		%LevelGrid.add_child(button)
	%LevelModal.show()
	%CloseLevelsButton.grab_focus()

func close_levels() -> void:
	%LevelModal.hide()
	_restore_result_if_needed()

func open_help() -> void:
	if adapter.state == "running":
		adapter.pause_or_resume()
	%HelpModal.show()
	%CloseHelpButton.grab_focus()

func close_help() -> void:
	%HelpModal.hide()

func _modal_open() -> bool:
	return current_screen != "game" or result_dialog.visible or %LevelModal.visible or %HelpModal.visible or %HintModal.visible

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		if %HelpModal.visible:
			close_help()
		elif %HintModal.visible:
			close_hint()
		elif %LevelModal.visible:
			close_levels()
		elif current_screen == "game" and not result_dialog.visible:
			adapter.pause_or_resume()
		get_viewport().set_input_as_handled()
		return
	if _modal_open() or get_viewport().gui_get_focus_owner() is LineEdit:
		return
	if event.keycode == KEY_SPACE:
		if adapter.state == "editing":
			start_run()
		else:
			adapter.pause_or_resume()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_R:
		retry_run()
		get_viewport().set_input_as_handled()

func _load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(_progress_path) != OK:
		return
	var value = config.get_value("demo", "completed", [])
	if value is Array:
		for id in value:
			for data in levels:
				if id == data.id and not completed.has(id):
					completed.append(id)
	# Only a consecutive run of completed levels unlocks the next one.
	for i in range(levels.size()):
		if completed.has(levels[i].id):
			unlocked_level = mini(i + 1, levels.size() - 1)
		else:
			break

func _save_progress() -> bool:
	var config := ConfigFile.new()
	config.set_value("demo", "completed", completed)
	return config.save(_progress_path) == OK

func get_debug_snapshot() -> Dictionary:
	return {"screen": current_screen, "details_expanded": formula_panel.get_node("DetailsMargin").visible, "level": current_level, "unlocked_level": unlocked_level, "state": adapter.state, "template": formula_panel.template_id, "parameters": formula_panel.parameters.duplicate(), "elapsed": adapter.elapsed, "checkpoints": adapter.reached.duplicate(), "result_visible": result_dialog.visible, "help_visible": %HelpModal.visible, "hint_visible": %HintModal.visible, "levels_visible": %LevelModal.visible, "zoom": graph.zoom_factor}
