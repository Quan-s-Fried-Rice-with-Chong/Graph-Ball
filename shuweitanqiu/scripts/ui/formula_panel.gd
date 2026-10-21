extends VBoxContainer

signal formula_changed(template_id: String, parameters: Dictionary)
signal formulas_changed(formulas: Array)

const Catalog = preload("res://scripts/core/formula_catalog.gd")
const UITheme = preload("res://scripts/ui/ui_theme.gd")
const DualRangeSlider = preload("res://scripts/ui/dual_range_slider.gd")
const IconButton = preload("res://scripts/ui/icon_button.gd")

const MAX_FORMULAS := 4
const DOMAIN_STEP := 0.01
const MIN_DOMAIN_WIDTH := 0.1

@onready var formula_list: VBoxContainer = %FormulaList
@onready var add_button: Button = %AddFormulaButton
@onready var lock_label: Label = %LockLabel

var template_id := "linear"
var parameters: Dictionary = {}
var formulas: Array = []

var _available: Array = []
var _initial_parameters: Dictionary = {}
var _domain_min := -9.0
var _domain_max := 11.0
var _entries: Array = []
var _fields: Dictionary = {}
var _locked := false
var _rebuilding := false

func _ready() -> void:
	add_button.pressed.connect(func(): add_formula())

func configure(level: Dictionary) -> void:
	_available = level.templates.duplicate()
	_initial_parameters = level.initial_parameters.duplicate(true)
	_domain_min = float(level.bounds.position.x)
	_domain_max = float(level.bounds.end.x)
	formulas = []
	if level.has("initial_formulas") and level.initial_formulas is Array and not level.initial_formulas.is_empty():
		for item in level.initial_formulas:
			formulas.append(_normalized_formula(item))
	else:
		var initial_template: String = level.initial_template
		var initial_values: Dictionary = level.initial_parameters.get(initial_template, {}).duplicate(true)
		formulas.append(_make_formula(initial_template, initial_values, Vector2(_domain_min, _domain_max)))
	_rebuild_all()
	_set_expanded(0, false)
	_update_lock_label()

func set_details_expanded(expanded: bool) -> void:
	if _entries.is_empty():
		return
	_set_expanded(0, expanded)

func is_details_expanded() -> bool:
	return not _entries.is_empty() and _entries[0].expanded

func add_formula(next_template: String = "", next_parameters: Dictionary = {}, domain: Variant = null) -> int:
	if _locked or formulas.size() >= MAX_FORMULAS:
		return -1
	var chosen := next_template
	if chosen.is_empty() or not chosen in _available:
		chosen = formulas[-1].template if not formulas.is_empty() and formulas[-1].template in _available else _available[0]
	var values := {}
	if not next_parameters.is_empty():
		values = next_parameters.duplicate(true)
	elif not formulas.is_empty() and formulas[-1].template == chosen:
		values = formulas[-1].parameters.duplicate(true)
	else:
		values = _default_parameters(chosen)
	var next_domain := Vector2(_domain_min, _domain_max) if domain == null else _as_domain(domain)
	formulas.append(_make_formula(chosen, values, next_domain))
	_rebuild_all(formulas.size() - 1)
	_emit_change()
	return formulas.size() - 1

func remove_formula(index: int) -> void:
	if _locked or formulas.size() <= 1 or index < 0 or index >= formulas.size():
		return
	formulas.remove_at(index)
	_rebuild_all()
	_emit_change()

func get_formulas() -> Array:
	return formulas.duplicate(true)

func get_formula_count() -> int:
	return formulas.size()

func get_max_formulas() -> int:
	return MAX_FORMULAS

func set_formulas(values: Array) -> String:
	if _locked:
		return "运行时不能修改公式，请先重试。"
	if values.is_empty():
		return "至少需要一条函数。"
	if values.size() > MAX_FORMULAS:
		return "最多可以添加 %d 条函数。" % MAX_FORMULAS
	var parsed: Array = []
	for item in values:
		var formula := _normalized_formula(item)
		var error := _validate_formula(formula)
		if not error.is_empty():
			return error
		parsed.append(formula)
	formulas = parsed
	_rebuild_all()
	_emit_change()
	return ""

func set_domain(index: int, low: float, high: float) -> void:
	if index < 0 or index >= formulas.size():
		return
	var domain := _clamp_domain(low, high)
	formulas[index].domain = domain
	if index < _entries.size():
		_sync_domain_controls(index)
		_update_expression(index)
	_emit_change()

func set_formula(next_template: String, values: Dictionary) -> String:
	if _locked:
		return "运行时不能修改公式，请先重试。"
	if not next_template in _available:
		return "本关没有提供这个模板。"
	var error := Catalog.validate(next_template, values)
	if not error.is_empty():
		return error
	formulas[0].template = next_template
	formulas[0].parameters = values.duplicate(true)
	_rebuild_all()
	_emit_change()
	return ""

func commit_input() -> void:
	for entry in _entries:
		for field in entry.fields.values():
			field.spin.apply()
		entry.min_spin.apply()
		entry.max_spin.apply()

func set_locked(value: bool) -> void:
	_locked = value
	add_button.disabled = value or formulas.size() >= MAX_FORMULAS
	for entry in _entries:
		entry.picker.disabled = value
		entry.expand_button.disabled = false
		entry.remove_button.disabled = value or formulas.size() <= 1
		entry.domain_slider.editable = not value
		entry.min_spin.editable = not value
		entry.max_spin.editable = not value
		for field in entry.fields.values():
			field.spin.editable = not value
			field.slider.editable = not value
	_update_lock_label()

func _rebuild_all(expand_index: int = -1) -> void:
	var was_expanded: Array = []
	for entry in _entries:
		was_expanded.append(entry.expanded)
	_rebuilding = true
	for child in formula_list.get_children():
		formula_list.remove_child(child)
		child.queue_free()
	_entries = []
	for i in range(formulas.size()):
		var entry := _build_entry(i)
		_entries.append(entry)
		if i < was_expanded.size():
			_set_expanded(i, was_expanded[i])
	_rebuilding = false
	if expand_index >= 0:
		_set_expanded(expand_index, true)
	_fields = _entries[0].fields if not _entries.is_empty() else {}
	_sync_compat()
	add_button.disabled = _locked or formulas.size() >= MAX_FORMULAS
	add_button.text = "＋  添加函数" if formulas.size() < MAX_FORMULAS else "已达函数数量上限"

func _build_entry(index: int) -> Dictionary:
	var formula: Dictionary = formulas[index]
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.panel(Color.WHITE, 5, Color("e1e4ea")))
	formula_list.add_child(card)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)
	var tag := Label.new()
	tag.text = "f%d" % (index + 1)
	tag.custom_minimum_size = Vector2(24, 0)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.add_theme_color_override("font_color", Color("4968b5"))
	tag.add_theme_font_size_override("font_size", 15)
	header.add_child(tag)
	var expression := Label.new()
	expression.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	expression.theme_type_variation = &"MathLabel"
	expression.text = Catalog.formatted(formula.template, formula.parameters)
	expression.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	expression.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(expression)
	var expand_button = IconButton.new()
	expand_button.custom_minimum_size = Vector2(34, 34)
	expand_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	expand_button.theme_type_variation = &"DisclosureButton"
	expand_button.toggle_mode = true
	expand_button.tooltip_text = "调整函数"
	expand_button.symbol = "chevron_right"
	header.add_child(expand_button)
	var remove_button := Button.new()
	remove_button.custom_minimum_size = Vector2(30, 34)
	remove_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	remove_button.theme_type_variation = &"ToolButton"
	remove_button.tooltip_text = "移除这条函数"
	remove_button.text = "×"
	remove_button.add_theme_font_size_override("font_size", 19)
	remove_button.add_theme_color_override("font_color", Color("7f838b"))
	header.add_child(remove_button)

	var details_margin := MarginContainer.new()
	details_margin.add_theme_constant_override("margin_left", 32)
	details_margin.add_theme_constant_override("margin_top", 2)
	box.add_child(details_margin)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 12)
	details_margin.add_child(details)

	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(0, 38)
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.add_theme_font_size_override("font_size", 15)
	picker.clip_text = true
	for id in _available:
		picker.add_item(Catalog.TEMPLATES[id].title)
		picker.set_item_metadata(picker.item_count - 1, id)
	picker.select(maxi(0, _available.find(formula.template)))
	details.add_child(picker)

	var description := Label.new()
	description.text = Catalog.TEMPLATES[formula.template].description
	description.add_theme_color_override("font_color", Color("81858c"))
	description.add_theme_font_size_override("font_size", 13)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(description)

	var parameter_list := VBoxContainer.new()
	parameter_list.add_theme_constant_override("separation", 13)
	details.add_child(parameter_list)
	var fields: Dictionary = {}
	for spec in Catalog.TEMPLATES[formula.template].parameters:
		var group := VBoxContainer.new()
		group.add_theme_constant_override("separation", 4)
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s   %s" % [spec.key, spec.title]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 15)
		row.add_child(label)
		var spin := SpinBox.new()
		spin.name = "Value_" + spec.key
		spin.custom_minimum_size = Vector2(94, 34)
		spin.min_value = spec.min
		spin.max_value = spec.max
		spin.step = spec.step
		spin.value = formula.parameters[spec.key]
		spin.update_on_text_changed = false
		spin.get_line_edit().alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(spin)
		group.add_child(row)
		var slider := HSlider.new()
		slider.name = "Slider_" + spec.key
		slider.custom_minimum_size = Vector2(0, 22)
		slider.min_value = spec.min
		slider.max_value = spec.max
		slider.step = spec.step
		slider.value = formula.parameters[spec.key]
		group.add_child(slider)
		parameter_list.add_child(group)
		fields[spec.key] = {"spin": spin, "slider": slider}

	var domain_header := Label.new()
	domain_header.name = "DomainLabel"
	domain_header.add_theme_font_size_override("font_size", 14)
	domain_header.add_theme_color_override("font_color", Color("4f5560"))
	details.add_child(domain_header)
	var domain_slider := DualRangeSlider.new()
	domain_slider.set_range_limits(_domain_min, _domain_max, DOMAIN_STEP)
	domain_slider.set_values(formula.domain.x, formula.domain.y)
	details.add_child(domain_slider)
	var domain_row := HBoxContainer.new()
	domain_row.add_theme_constant_override("separation", 8)
	details.add_child(domain_row)
	var from_label := Label.new()
	from_label.text = "x 从"
	from_label.add_theme_font_size_override("font_size", 13)
	from_label.add_theme_color_override("font_color", Color("81858c"))
	domain_row.add_child(from_label)
	var min_spin := SpinBox.new()
	min_spin.custom_minimum_size = Vector2(92, 32)
	min_spin.min_value = _domain_min
	min_spin.max_value = _domain_max
	min_spin.step = DOMAIN_STEP
	min_spin.value = formula.domain.x
	min_spin.update_on_text_changed = false
	min_spin.get_line_edit().alignment = HORIZONTAL_ALIGNMENT_CENTER
	domain_row.add_child(min_spin)
	var to_label := Label.new()
	to_label.text = "到"
	to_label.add_theme_font_size_override("font_size", 13)
	to_label.add_theme_color_override("font_color", Color("81858c"))
	domain_row.add_child(to_label)
	var max_spin := SpinBox.new()
	max_spin.custom_minimum_size = Vector2(92, 32)
	max_spin.min_value = _domain_min
	max_spin.max_value = _domain_max
	max_spin.step = DOMAIN_STEP
	max_spin.value = formula.domain.y
	max_spin.update_on_text_changed = false
	max_spin.get_line_edit().alignment = HORIZONTAL_ALIGNMENT_CENTER
	domain_row.add_child(max_spin)
	var domain_note := Label.new()
	domain_note.text = "定义域外的部分不参与轨道。"
	domain_note.add_theme_font_size_override("font_size", 11)
	domain_note.add_theme_color_override("font_color", Color("9a9da4"))
	details.add_child(domain_note)

	var entry := {
		"card": card,
		"details": details_margin,
		"picker": picker,
		"description": description,
		"parameter_list": parameter_list,
		"expression": expression,
		"expand_button": expand_button,
		"remove_button": remove_button,
		"fields": fields,
		"domain_slider": domain_slider,
		"domain_label": domain_header,
		"min_spin": min_spin,
		"max_spin": max_spin,
		"expanded": false
	}

	picker.item_selected.connect(_on_template_selected.bind(index))
	expand_button.toggled.connect(func(expanded: bool): _set_expanded(index, expanded))
	remove_button.pressed.connect(func(): remove_formula(index))
	domain_slider.range_changed.connect(_on_domain_slider_changed.bind(index))
	min_spin.value_changed.connect(_on_domain_spin_changed.bind(index, true))
	max_spin.value_changed.connect(_on_domain_spin_changed.bind(index, false))
	for key in fields:
		fields[key].spin.value_changed.connect(_on_parameter_changed.bind(index, key))
		fields[key].slider.value_changed.connect(_on_parameter_changed.bind(index, key))
	_update_domain_text(entry, formula)
	return entry

func _set_expanded(index: int, expanded: bool) -> void:
	if index < 0 or index >= _entries.size():
		return
	var entry: Dictionary = _entries[index]
	if not is_instance_valid(entry.details):
		return
	entry.expanded = expanded
	entry.details.visible = expanded
	entry.expand_button.set_pressed_no_signal(expanded)
	entry.expand_button.symbol = "chevron_down" if expanded else "chevron_right"
	entry.expand_button.tooltip_text = "收起调整" if expanded else "调整函数"

func _on_template_selected(picker_index: int, formula_index: int) -> void:
	if _locked or _rebuilding or formula_index < 0 or formula_index >= formulas.size():
		return
	var formula: Dictionary = formulas[formula_index]
	var next_template: String = _entries[formula_index].picker.get_item_metadata(picker_index)
	if next_template == formula.template:
		return
	formula.template = next_template
	formula.parameters = _default_parameters(next_template)
	_rebuild_all(formula_index)
	_emit_change()

func _on_parameter_changed(value: float, formula_index: int, key: String) -> void:
	if _locked or _rebuilding or formula_index >= formulas.size():
		return
	var formula: Dictionary = formulas[formula_index]
	formula.parameters[key] = value
	var field: Dictionary = _entries[formula_index].fields[key]
	field.spin.set_value_no_signal(value)
	field.slider.set_value_no_signal(value)
	_update_expression(formula_index)
	_emit_change()

func _on_domain_slider_changed(low: float, high: float, formula_index: int) -> void:
	if _locked or _rebuilding or formula_index >= formulas.size():
		return
	formulas[formula_index].domain = _clamp_domain(low, high)
	_sync_domain_controls(formula_index, true)
	_update_expression(formula_index)
	_emit_change()

func _on_domain_spin_changed(value: float, formula_index: int, is_low: bool) -> void:
	if _locked or _rebuilding or formula_index >= formulas.size():
		return
	var formula: Dictionary = formulas[formula_index]
	var domain: Vector2 = formula.domain
	if is_low:
		domain.x = minf(value, domain.y - MIN_DOMAIN_WIDTH)
	else:
		domain.y = maxf(value, domain.x + MIN_DOMAIN_WIDTH)
	formula.domain = _clamp_domain(domain.x, domain.y)
	_sync_domain_controls(formula_index, true)
	_update_expression(formula_index)
	_emit_change()

func _sync_domain_controls(formula_index: int, update_slider: bool = true) -> void:
	if formula_index < 0 or formula_index >= _entries.size():
		return
	var entry: Dictionary = _entries[formula_index]
	var domain: Vector2 = formulas[formula_index].domain
	entry.min_spin.set_value_no_signal(domain.x)
	entry.max_spin.set_value_no_signal(domain.y)
	if update_slider:
		entry.domain_slider.set_values(domain.x, domain.y)
	_update_domain_text(entry, formulas[formula_index])

func _update_domain_text(entry: Dictionary, formula: Dictionary) -> void:
	entry.domain_label.text = "定义域  x ∈ [%s, %s]" % [_number(formula.domain.x), _number(formula.domain.y)]

func _update_expression(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return
	_entries[index].expression.text = Catalog.formatted(formulas[index].template, formulas[index].parameters)

func _emit_change() -> void:
	_sync_compat()
	formulas_changed.emit(get_formulas())
	formula_changed.emit(template_id, parameters.duplicate())

func _sync_compat() -> void:
	if formulas.is_empty():
		return
	template_id = formulas[0].template
	parameters = formulas[0].parameters.duplicate(true)

func _normalized_formula(item: Dictionary) -> Dictionary:
	var next_template: String = item.get("template", _available[0] if not _available.is_empty() else "linear")
	var values: Dictionary = item.get("parameters", {}).duplicate(true)
	if not Catalog.TEMPLATES.has(next_template):
		next_template = _available[0] if not _available.is_empty() else "linear"
	for spec in Catalog.TEMPLATES[next_template].parameters:
		if not values.has(spec.key):
			values[spec.key] = float(spec.min)
	var domain: Vector2 = _as_domain(item.get("domain", [_domain_min, _domain_max]))
	return _make_formula(next_template, values, domain)

func _make_formula(next_template: String, values: Dictionary, domain: Vector2) -> Dictionary:
	return {"template": next_template, "parameters": values.duplicate(true), "domain": _clamp_domain(domain.x, domain.y)}

func _default_parameters(next_template: String) -> Dictionary:
	if _initial_parameters.has(next_template):
		return _initial_parameters[next_template].duplicate(true)
	var values: Dictionary = {}
	for spec in Catalog.TEMPLATES[next_template].parameters:
		values[spec.key] = float(spec.min)
	return values

func _as_domain(value: Variant) -> Vector2:
	if value is Vector2:
		return _clamp_domain(value.x, value.y)
	if value is Array and value.size() >= 2:
		return _clamp_domain(float(value[0]), float(value[1]))
	if value is Dictionary:
		return _clamp_domain(float(value.get("min", _domain_min)), float(value.get("max", _domain_max)))
	return Vector2(_domain_min, _domain_max)

func _clamp_domain(low: float, high: float) -> Vector2:
	var next_low := snappedf(clampf(low, _domain_min, _domain_max), DOMAIN_STEP)
	var next_high := snappedf(clampf(high, _domain_min, _domain_max), DOMAIN_STEP)
	if next_high - next_low < MIN_DOMAIN_WIDTH:
		next_high = minf(_domain_max, next_low + MIN_DOMAIN_WIDTH)
		next_low = maxf(_domain_min, next_high - MIN_DOMAIN_WIDTH)
	return Vector2(next_low, next_high)

func _validate_formula(formula: Dictionary) -> String:
	var error := Catalog.validate(formula.template, formula.parameters)
	if not error.is_empty():
		return error
	if formula.domain.y - formula.domain.x < MIN_DOMAIN_WIDTH:
		return "定义域的上下界至少相差 %.1f。" % MIN_DOMAIN_WIDTH
	return ""

func _update_lock_label() -> void:
	lock_label.text = "运行中，重试后可继续调整。" if _locked else "拖动滑条或输入数值；按 Enter 确认。"

func _number(value: float) -> String:
	var text := ("%.2f" % value).rstrip("0").rstrip(".")
	return "0" if text == "-0" else text.replace("-", "−")
