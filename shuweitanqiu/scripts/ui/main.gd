extends Control

const Catalog = preload("res://scripts/core/formula_catalog.gd")
const Levels = preload("res://scripts/core/level_repository.gd")
const UITheme = preload("res://scripts/ui/ui_theme.gd")

const SIDEBAR_WIDTH := 400.0
const SIDEBAR_COLLAPSED_WIDTH := 26.0
const SIDEBAR_ANIMATION_TIME := 0.24

@onready var formula_panel = %FormulaPanel
@onready var sidebar: PanelContainer = %Sidebar
@onready var sidebar_body: Control = %SidebarBody
@onready var graph = %GraphCanvas
@onready var adapter = $RunAdapter
@onready var result_dialog = %ResultDialog
@onready var main_menu = %MainMenu
@onready var level_page = %LevelSelectPage

var levels: Array = []
var current_level := 0
var unlocked_level := 0
var completed: Array = []
var _loading := false
var _progress_path := "user://b_prototype_progress.cfg"
var current_screen := "menu"
var _has_entered_game := false
var _booting := true
var _levels_origin := "menu"
var _sidebar_collapsed := false
var _sidebar_tween: Tween

func _ready() -> void:
	get_window().title = "数维弹球"
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
	formula_panel.formulas_changed.connect(_on_formulas_changed)
	adapter.curve_changed.connect(graph.set_curve)
	adapter.ball_moved.connect(_on_ball_moved)
	adapter.checkpoints_changed.connect(_on_checkpoints_changed)
	adapter.state_changed.connect(_on_state_changed)
	adapter.run_finished.connect(_on_run_finished)
	%RunButton.pressed.connect(start_run)
	%PauseButton.pressed.connect(adapter.pause_or_resume)
	%RetryButton.pressed.connect(retry_run)
	%ResetButton.pressed.connect(reset_level)
	%ToggleSidebarButton.pressed.connect(toggle_sidebar)
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
	level_page.back_requested.connect(close_levels)
	level_page.level_requested.connect(load_level)
	%CloseHelpButton.pressed.connect(close_help)
	%CloseHintButton.pressed.connect(close_hint)
	result_dialog.retry_requested.connect(retry_run)
	result_dialog.next_requested.connect(_next_level)
	result_dialog.levels_requested.connect(open_levels)

func toggle_sidebar() -> void:
	set_sidebar_collapsed(not _sidebar_collapsed)

func set_sidebar_collapsed(collapsed: bool) -> void:
	if collapsed == _sidebar_collapsed:
		return
	_sidebar_collapsed = collapsed
	if _sidebar_tween and _sidebar_tween.is_valid():
		_sidebar_tween.kill()
	sidebar_body.show()
	sidebar_body.mouse_filter = Control.MOUSE_FILTER_IGNORE if collapsed else Control.MOUSE_FILTER_STOP
	if collapsed:
		get_viewport().gui_release_focus()
	var target_width := SIDEBAR_COLLAPSED_WIDTH if collapsed else SIDEBAR_WIDTH
	_sidebar_tween = create_tween()
	_sidebar_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_sidebar_tween.tween_property(sidebar, "custom_minimum_size:x", target_width, SIDEBAR_ANIMATION_TIME)
	_sidebar_tween.parallel().tween_property(sidebar_body, "modulate:a", 0.0 if collapsed else 1.0, SIDEBAR_ANIMATION_TIME * 0.7)
	if collapsed:
		_sidebar_tween.chain().tween_callback(sidebar_body.hide)
	%ToggleSidebarButton.symbol = "chevron_right" if collapsed else "chevron_left"
	%ToggleSidebarButton.tooltip_text = "展开函数栏" if collapsed else "收起函数栏"

func is_sidebar_collapsed() -> bool:
	return _sidebar_collapsed

func load_level(index: int) -> bool:
	if index < 0 or index >= levels.size() or index > unlocked_level:
		return false
	_loading = true
	current_level = index
	var data: Dictionary = levels[index]
	result_dialog.hide()
	level_page.hide()
	%HelpModal.hide()
	%HintModal.hide()
	%LevelNumber.text = "%02d" % (index + 1)
	%LevelTitle.text = data.title
	%LevelTitle.tooltip_text = data.objective
	%HintText.text = data.objective + "\n\n" + data.hint
	formula_panel.set_locked(false)
	formula_panel.configure(data)
	%FormulaValue.text = "%d / %d" % [formula_panel.get_formula_count(), formula_panel.get_max_formulas()]
	graph.set_level(data)
	adapter.configure_formulas(data, formula_panel.get_formulas())
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
	level_page.hide()
	%GamePage.show()
	_restore_result_if_needed()

func open_main_menu() -> void:
	if adapter.state == "running":
		adapter.pause_or_resume()
	for modal in [result_dialog, %HelpModal, level_page, %HintModal]:
		modal.hide()
	current_screen = "menu"
	%GamePage.hide()
	main_menu.set_started(_has_entered_game)
	main_menu.show()

func _restore_result_if_needed() -> void:
	if current_screen == "game" and adapter.state in ["success", "failed"]:
		result_dialog.present(adapter.last_result, current_level < levels.size() - 1)

func _on_formulas_changed(formula_list: Array) -> void:
	if _loading:
		return
	adapter.update_formulas(formula_list)
	%FormulaValue.text = "%d / %d" % [formula_panel.get_formula_count(), formula_panel.get_max_formulas()]
	graph.reset_trail()

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

func reset_level() -> void:
	load_level(current_level)

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

func _on_run_finished(result: Dictionary) -> void:
	var saved := true
	if result.success:
		var id: String = levels[current_level].id
		if not completed.has(id):
			completed.append(id)
		unlocked_level = mini(levels.size() - 1, maxi(unlocked_level, current_level + 1))
		saved = _save_progress()
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
	if current_screen != "levels":
		_levels_origin = current_screen
	result_dialog.hide()
	%HelpModal.hide()
	%HintModal.hide()
	main_menu.hide()
	%GamePage.hide()
	current_screen = "levels"
	level_page.configure(levels, unlocked_level, completed)
	level_page.show()

func close_levels() -> void:
	level_page.hide()
	if _levels_origin == "game":
		enter_game()
	else:
		open_main_menu()

func open_help() -> void:
	if adapter.state == "running":
		adapter.pause_or_resume()
	%HelpModal.show()
	%CloseHelpButton.grab_focus()

func close_help() -> void:
	%HelpModal.hide()

func _modal_open() -> bool:
	return current_screen != "game" or result_dialog.visible or %HelpModal.visible or %HintModal.visible

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		if %HelpModal.visible:
			close_help()
		elif %HintModal.visible:
			close_hint()
		elif current_screen == "levels":
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
	return {"screen": current_screen, "details_expanded": formula_panel.is_details_expanded(), "sidebar_collapsed": _sidebar_collapsed, "level": current_level, "unlocked_level": unlocked_level, "state": adapter.state, "template": formula_panel.template_id, "parameters": formula_panel.parameters.duplicate(), "formulas": formula_panel.get_formulas(), "formula_count": formula_panel.get_formula_count(), "elapsed": adapter.elapsed, "checkpoints": adapter.reached.duplicate(), "result_visible": result_dialog.visible, "help_visible": %HelpModal.visible, "hint_visible": %HintModal.visible, "levels_visible": level_page.visible, "level_locks": level_page.get_lock_states(), "zoom": graph.zoom_factor}
