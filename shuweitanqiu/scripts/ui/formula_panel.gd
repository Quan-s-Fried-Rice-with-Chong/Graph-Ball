extends VBoxContainer

signal formula_changed(template_id: String, parameters: Dictionary)

const Catalog = preload("res://scripts/core/formula_catalog.gd")
const UITheme = preload("res://scripts/ui/ui_theme.gd")

@onready var picker: OptionButton = %TemplatePicker
@onready var expression_label: Label = %ExpressionLabel
@onready var description_label: Label = %TemplateDescription
@onready var parameter_list: VBoxContainer = %ParameterList
@onready var lock_label: Label = %LockLabel

var template_id := "linear"
var parameters: Dictionary = {}
var _available: Array = []
var _saved: Dictionary = {}
var _fields: Dictionary = {}
var _locked := false

func _ready() -> void:
	picker.item_selected.connect(_on_template_selected)
	%ExpandButton.toggled.connect(set_details_expanded)

func set_details_expanded(expanded: bool) -> void:
	%DetailsMargin.visible = expanded
	%ExpandButton.set_pressed_no_signal(expanded)
	%ExpandButton.symbol = "chevron_down" if expanded else "chevron_right"
	%ExpandButton.tooltip_text = "收起调整" if expanded else "调整公式"

func configure(level: Dictionary) -> void:
	_available = level.templates.duplicate()
	_saved = level.initial_parameters.duplicate(true)
	picker.clear()
	for id in _available:
		picker.add_item(Catalog.TEMPLATES[id].title)
		picker.set_item_metadata(picker.item_count - 1, id)
	template_id = level.initial_template
	parameters = _saved[template_id].duplicate()
	picker.select(_available.find(template_id))
	_rebuild_parameters()
	set_details_expanded(false)

func _on_template_selected(index: int) -> void:
	if _locked:
		return
	_saved[template_id] = parameters.duplicate()
	template_id = picker.get_item_metadata(index)
	parameters = _saved[template_id].duplicate()
	_rebuild_parameters()
	formula_changed.emit(template_id, parameters.duplicate())

func _rebuild_parameters() -> void:
	for child in parameter_list.get_children():
		parameter_list.remove_child(child)
		child.queue_free()
	_fields = {}
	description_label.text = Catalog.TEMPLATES[template_id].description
	for spec in Catalog.TEMPLATES[template_id].parameters:
		var group := VBoxContainer.new()
		group.add_theme_constant_override("separation", 5)
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s   %s" % [spec.key, spec.title]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 15)
		row.add_child(label)
		var spin := SpinBox.new()
		spin.name = "Value_" + spec.key
		spin.custom_minimum_size = Vector2(94, 36)
		spin.min_value = spec.min
		spin.max_value = spec.max
		spin.step = spec.step
		spin.value = parameters[spec.key]
		spin.update_on_text_changed = false
		spin.get_line_edit().alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(spin)
		group.add_child(row)
		var slider := HSlider.new()
		slider.name = "Slider_" + spec.key
		slider.custom_minimum_size = Vector2(0, 24)
		slider.min_value = spec.min
		slider.max_value = spec.max
		slider.step = spec.step
		slider.value = parameters[spec.key]
		slider.value_changed.connect(_on_parameter_changed.bind(spec.key))
		spin.value_changed.connect(_on_parameter_changed.bind(spec.key))
		group.add_child(slider)
		parameter_list.add_child(group)
		_fields[spec.key] = {"spin": spin, "slider": slider}
	_update_expression()
	set_locked(_locked)

func _on_parameter_changed(value: float, key: String) -> void:
	if _locked:
		return
	parameters[key] = value
	_fields[key].spin.set_value_no_signal(value)
	_fields[key].slider.set_value_no_signal(value)
	_update_expression()
	formula_changed.emit(template_id, parameters.duplicate())

func set_formula(next_template: String, values: Dictionary) -> String:
	if _locked:
		return "运行时不能修改公式，请先重试。"
	if not next_template in _available:
		return "本关没有提供这个模板。"
	var error := Catalog.validate(next_template, values)
	if not error.is_empty():
		return error
	_saved[template_id] = parameters.duplicate()
	template_id = next_template
	parameters = values.duplicate()
	_saved[template_id] = parameters.duplicate()
	picker.select(_available.find(template_id))
	_rebuild_parameters()
	formula_changed.emit(template_id, parameters.duplicate())
	return ""

func commit_input() -> void:
	for field in _fields.values():
		field.spin.apply()

func set_locked(value: bool) -> void:
	_locked = value
	picker.disabled = value
	for field in _fields.values():
		field.spin.editable = not value
		field.slider.editable = not value
	lock_label.text = "运行中，重试后可继续调整。" if value else "数值输入后按 Enter 确认。"

func _update_expression() -> void:
	expression_label.text = Catalog.formatted(template_id, parameters)
