class_name IntegrationPanel
extends CanvasLayer

var controller: LevelController
var root_control: Control
var title_label: Label
var hint_label: Label
var status_label: Label
var formula_container: HBoxContainer
var run_button: Button
var pause_button: Button
var add_line_button: Button
var add_quadratic_button: Button
var _formula_signature := ""

func _ready() -> void:
	controller = get_parent() as LevelController
	_build_interface()
	controller.level_loaded.connect(_on_level_loaded)
	controller.formula_list_changed.connect(_on_formula_list_changed)
	controller.status_changed.connect(_on_status_changed)
	controller.run_finished.connect(_on_run_finished)
	controller.validation_failed.connect(_on_validation_failed)
	_on_level_loaded(controller.current_level)
	_on_formula_list_changed(controller.formulas)

func _process(_delta: float) -> void:
	if controller == null or controller.current_level.is_empty():
		return
	var snapshot := controller.snapshot()
	status_label.text = "状态 %s    时间 %.1f    检查点 %d/%d    球 (%.2f, %.2f)" % [
		snapshot["status"], snapshot["time_left"], snapshot["checkpoint_index"],
		controller.current_level.get("checkpoints", []).size(),
		snapshot["ball_position"].x, snapshot["ball_position"].y,
	]

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			controller.start_run()
		KEY_R:
			controller.reset_run()
		KEY_P:
			controller.toggle_pause()
		KEY_Q:
			controller.load_level(controller.current_level_index - 1)
		KEY_E:
			controller.load_level(controller.current_level_index + 1)

func _build_interface() -> void:
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root_control)

	var top_panel := PanelContainer.new()
	top_panel.position = Vector2(18, 16)
	top_panel.size = Vector2(520, 150)
	root_control.add_child(top_panel)
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.035, 0.045, 0.09, 0.92)
	top_style.border_color = Color(0.30, 0.34, 0.55, 0.72)
	top_style.set_border_width_all(1)
	top_style.set_corner_radius_all(12)
	top_panel.add_theme_stylebox_override("panel", top_style)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_left", 16)
	top_margin.add_theme_constant_override("margin_right", 16)
	top_margin.add_theme_constant_override("margin_top", 12)
	top_margin.add_theme_constant_override("margin_bottom", 12)
	top_panel.add_child(top_margin)
	var top_box := VBoxContainer.new()
	top_box.add_theme_constant_override("separation", 7)
	top_margin.add_child(top_box)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color("f6f2ff"))
	top_box.add_child(title_label)
	hint_label = Label.new()
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_color_override("font_color", Color("b9c2df"))
	top_box.add_child(hint_label)
	status_label = Label.new()
	status_label.add_theme_color_override("font_color", Color("82e6cb"))
	top_box.add_child(status_label)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 7)
	top_box.add_child(button_row)
	button_row.add_child(_make_button("上一关 Q", _previous_level))
	run_button = _make_button("运行 Space", controller.start_run)
	button_row.add_child(run_button)
	pause_button = _make_button("暂停 P", controller.toggle_pause)
	button_row.add_child(pause_button)
	button_row.add_child(_make_button("重试 R", controller.reset_run))
	button_row.add_child(_make_button("下一关 E", _next_level))

	var formula_panel := PanelContainer.new()
	formula_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	formula_panel.offset_left = 18
	formula_panel.offset_right = -18
	formula_panel.offset_top = -168
	formula_panel.offset_bottom = -16
	root_control.add_child(formula_panel)
	var formula_style := StyleBoxFlat.new()
	formula_style.bg_color = Color(0.035, 0.045, 0.09, 0.94)
	formula_style.border_color = Color(0.30, 0.34, 0.55, 0.72)
	formula_style.set_border_width_all(1)
	formula_style.set_corner_radius_all(12)
	formula_panel.add_theme_stylebox_override("panel", formula_style)

	var formula_margin := MarginContainer.new()
	formula_margin.add_theme_constant_override("margin_left", 12)
	formula_margin.add_theme_constant_override("margin_right", 12)
	formula_margin.add_theme_constant_override("margin_top", 10)
	formula_margin.add_theme_constant_override("margin_bottom", 10)
	formula_panel.add_child(formula_margin)
	var formula_root := VBoxContainer.new()
	formula_margin.add_child(formula_root)
	var formula_header := HBoxContainer.new()
	formula_root.add_child(formula_header)
	var formula_title := Label.new()
	formula_title.text = "A 核心集成测试面板（B 可直接替换）"
	formula_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	formula_header.add_child(formula_title)
	add_line_button = _make_button("+ 一次函数", func(): controller.add_formula(GameConstants.MODULE_LINE))
	add_quadratic_button = _make_button("+ 二次函数", func(): controller.add_formula(GameConstants.MODULE_QUADRATIC))
	formula_header.add_child(add_line_button)
	formula_header.add_child(add_quadratic_button)
	formula_container = HBoxContainer.new()
	formula_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	formula_container.add_theme_constant_override("separation", 16)
	formula_root.add_child(formula_container)

func _make_button(text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.pressed.connect(callback)
	return button

func _on_level_loaded(level: Dictionary) -> void:
	if level.is_empty():
		return
	title_label.text = "%s  %s · %s" % [level.get("number", ""), level.get("title", ""), level.get("subtitle", "")]
	hint_label.text = String(level.get("hint", ""))
	_formula_signature = ""
	_update_add_buttons()

func _on_formula_list_changed(next_formulas: Array) -> void:
	var signature_parts: Array[String] = []
	for formula in next_formulas:
		signature_parts.append(String(formula.get("id", "")))
	var signature := "|".join(signature_parts)
	if signature == _formula_signature:
		return
	_formula_signature = signature
	for child in formula_container.get_children():
		formula_container.remove_child(child)
		child.queue_free()
	for index in next_formulas.size():
		formula_container.add_child(_build_formula_editor(index, next_formulas[index]))
	_update_add_buttons()

func _build_formula_editor(index: int, formula: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(320, 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var header := HBoxContainer.new()
	box.add_child(header)
	var label := Label.new()
	label.text = "%s  %s" % ["一次函数" if formula["type"] == GameConstants.MODULE_LINE else "二次函数", FormulaModel.display_text(formula)]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	var remove_button := Button.new()
	remove_button.text = "×"
	remove_button.tooltip_text = "删除函数"
	remove_button.pressed.connect(func(): controller.remove_formula(index))
	header.add_child(remove_button)

	var parameters: Dictionary = formula["parameters"]
	var limits: Dictionary = controller.current_level.get("parameter_limits", {})
	for key in parameters:
		var limit: Vector2 = limits.get(key, Vector2(-10, 10))
		box.add_child(_build_slider(index, String(key), float(parameters[key]), limit.x, limit.y, label))
	var x_range: Vector2 = formula["x_range"]
	box.add_child(_build_range_controls(index, x_range))
	return box

func _build_slider(index: int, key: String, value: float, minimum: float, maximum: float, expression_label: Label) -> Control:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = key
	name_label.custom_minimum_size.x = 18
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.02 if key != "c" else 0.05
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value_label := Label.new()
	value_label.text = "%.2f" % value
	value_label.custom_minimum_size.x = 48
	row.add_child(value_label)
	slider.value_changed.connect(func(next_value: float):
		value_label.text = "%.2f" % next_value
		if controller.update_formula_parameter(index, key, next_value):
			expression_label.text = "%s  %s" % ["一次函数" if controller.formulas[index]["type"] == GameConstants.MODULE_LINE else "二次函数", FormulaModel.display_text(controller.formulas[index])]
	)
	return row

func _build_range_controls(index: int, x_range: Vector2) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "x"
	label.custom_minimum_size.x = 18
	row.add_child(label)
	var minimum_box := SpinBox.new()
	minimum_box.min_value = -10
	minimum_box.max_value = 10
	minimum_box.step = 0.1
	minimum_box.value = x_range.x
	minimum_box.custom_minimum_size.x = 92
	row.add_child(minimum_box)
	var separator := Label.new()
	separator.text = "→"
	row.add_child(separator)
	var maximum_box := SpinBox.new()
	maximum_box.min_value = -10
	maximum_box.max_value = 10
	maximum_box.step = 0.1
	maximum_box.value = x_range.y
	maximum_box.custom_minimum_size.x = 92
	row.add_child(maximum_box)
	minimum_box.value_changed.connect(func(value: float): controller.update_formula_x_range(index, value, maximum_box.value))
	maximum_box.value_changed.connect(func(value: float): controller.update_formula_x_range(index, minimum_box.value, value))
	return row

func _on_status_changed(status: String) -> void:
	var locked := status != "EDITING"
	run_button.disabled = status == "RUNNING" or status == "PAUSED"
	pause_button.disabled = status != "RUNNING" and status != "PAUSED"
	formula_container.mouse_filter = Control.MOUSE_FILTER_IGNORE if locked else Control.MOUSE_FILTER_PASS
	formula_container.modulate = Color(1, 1, 1, 0.55) if locked else Color.WHITE
	_update_add_buttons()

func _on_run_finished(success: bool, reason: String, elapsed: float) -> void:
	hint_label.text = ("通关！" if success else "失败：%s" % reason) + "  用时 %.2f 秒；按 R 保留公式重试。" % elapsed

func _on_validation_failed(errors: Array) -> void:
	hint_label.text = "参数校验失败：" + "；".join(errors)

func _update_add_buttons() -> void:
	if controller == null or controller.current_level.is_empty():
		return
	var allowed: Array = controller.current_level.get("allowed_types", [])
	var has_room := controller.formulas.size() < int(controller.current_level.get("max_functions", 3))
	var editing := controller.state == LevelController.RunState.EDITING
	add_line_button.disabled = not editing or not has_room or not allowed.has(GameConstants.MODULE_LINE)
	add_quadratic_button.disabled = not editing or not has_room or not allowed.has(GameConstants.MODULE_QUADRATIC)

func _previous_level() -> void:
	controller.load_level(controller.current_level_index - 1)

func _next_level() -> void:
	controller.load_level(controller.current_level_index + 1)
