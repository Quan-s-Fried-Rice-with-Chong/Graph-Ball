class_name TutorialOverlay
extends Control

signal finished

const UITheme = preload("res://scripts/ui/ui_theme.gd")
const DIM_COLOR := Color(0.08, 0.12, 0.18, 0.62)
const ACCENT := Color("4968b5")

@onready var card: PanelContainer = %Card
@onready var step_label: Label = %StepLabel
@onready var title_label: Label = %Title
@onready var body_label: Label = %Body
@onready var next_button: Button = %NextTutorialButton
@onready var skip_button: Button = %SkipTutorialButton

var _steps: Array = []
var _target_resolver: Callable
var _state_provider: Callable
var _active := false
var _suspended := false
var _index := -1
var _baseline: Dictionary = {}
var _target_rect := Rect2()
var _target_valid := false
var _action_ready := false

func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UITheme.panel(Color("fbfcff"), 10, Color("b7c4dc"))
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	style.shadow_color = Color(0.08, 0.12, 0.18, 0.18)
	style.shadow_size = 14
	card.add_theme_stylebox_override("panel", style)
	next_button.pressed.connect(_advance)
	skip_button.pressed.connect(func(): stop())
	resized.connect(_refresh)

func start(steps: Array, target_resolver: Callable, state_provider: Callable = Callable()) -> void:
	_steps = steps.duplicate(true)
	_target_resolver = target_resolver
	_state_provider = state_provider
	_index = 0
	_active = true
	_suspended = false
	show()
	_apply_step()

func stop(emit_finished: bool = true) -> void:
	if not _active:
		return
	_active = false
	_suspended = false
	_steps = []
	hide()
	if emit_finished:
		finished.emit()

func suspend() -> void:
	if not _active:
		return
	_suspended = true
	hide()

func resume() -> void:
	if not _active or not _suspended:
		return
	_suspended = false
	show()
	_refresh()

func is_active() -> bool:
	return _active and not _suspended

func get_current_step() -> Dictionary:
	return {} if _index < 0 or _index >= _steps.size() else _steps[_index].duplicate(true)

func advance() -> void:
	_advance()

func _process(_delta: float) -> void:
	if not is_active():
		return
	_update_target()
	if not _action_ready and _should_advance():
		_action_ready = true
		next_button.disabled = false
		next_button.text = "继续"

func _apply_step() -> void:
	if _index < 0 or _index >= _steps.size():
		stop()
		return
	var step: Dictionary = _steps[_index]
	step_label.text = "教程  %d / %d" % [_index + 1, _steps.size()]
	title_label.text = String(step.get("title", "操作提示"))
	body_label.text = String(step.get("text", ""))
	var action := String(step.get("advance", "next"))
	_action_ready = action == "next"
	next_button.visible = true
	next_button.disabled = not _action_ready
	next_button.text = String(step.get("button", "下一步")) if _action_ready else "完成操作后继续"
	skip_button.text = "跳过教程" if _index < _steps.size() - 1 else "跳过"
	_baseline = _read_state()
	call_deferred("_refresh")

func _refresh() -> void:
	if not is_active():
		return
	_update_target()
	_position_card()
	queue_redraw()

func _read_state() -> Dictionary:
	if not _state_provider.is_valid():
		return {}
	var value = _state_provider.call()
	return value.duplicate(true) if value is Dictionary else {}

func _update_target() -> void:
	_target_rect = Rect2()
	_target_valid = false
	if not _target_resolver.is_valid() or _index < 0 or _index >= _steps.size():
		return
	var value = _target_resolver.call(String(_steps[_index].get("target", "")))
	if value is Rect2 and value.size.x > 0.0 and value.size.y > 0.0:
		_target_rect = Rect2(value.position - get_global_rect().position, value.size).abs()
		_target_valid = true
	queue_redraw()

func _position_card() -> void:
	if not is_instance_valid(card):
		return
	var margin := 18.0
	var width := minf(348.0, maxf(280.0, size.x - margin * 2.0))
	card.custom_minimum_size.x = width
	card.reset_size()
	var card_size := card.size
	var position := Vector2((size.x - card_size.x) * 0.5, (size.y - card_size.y) * 0.5)
	if _target_valid:
		var gap := 18.0
		if _target_rect.end.y + gap + card_size.y <= size.y - margin:
			position.y = _target_rect.end.y + gap
		elif _target_rect.position.y - gap - card_size.y >= margin:
			position.y = _target_rect.position.y - gap - card_size.y
		else:
			position.y = _target_rect.get_center().y - card_size.y * 0.5
		position.x = _target_rect.get_center().x - card_size.x * 0.5
	position.x = clampf(position.x, margin, maxf(margin, size.x - card_size.x - margin))
	position.y = clampf(position.y, margin, maxf(margin, size.y - card_size.y - margin))
	card.position = position

func _should_advance() -> bool:
	if _index < 0 or _index >= _steps.size():
		return false
	var action := String(_steps[_index].get("advance", "next"))
	if action == "next":
		return false
	var current := _read_state()
	var old_formulas: Array = _baseline.get("formulas", [])
	var new_formulas: Array = current.get("formulas", [])
	match action:
		"expand":
			return bool(current.get("expanded", false)) and not bool(_baseline.get("expanded", false))
		"parameter_change", "parameter_change_2":
			var parameter_index := 1 if action.ends_with("_2") else 0
			return _parameters_changed(old_formulas, new_formulas, parameter_index)
		"domain_change", "domain_change_2":
			var domain_index := 1 if action.ends_with("_2") else 0
			return _domain_changed(old_formulas, new_formulas, domain_index)
		"formula_added":
			return int(current.get("formula_count", 0)) > int(_baseline.get("formula_count", 0))
		"template_quadratic":
			return not new_formulas.is_empty() and String(new_formulas[0].get("template", "")) == "quadratic"
		"run":
			return String(current.get("state", "editing")) != "editing"
	return false

func _parameters_changed(old_formulas: Array, new_formulas: Array, index: int) -> bool:
	if index < 0 or index >= old_formulas.size() or index >= new_formulas.size():
		return false
	return old_formulas[index].get("parameters", {}) != new_formulas[index].get("parameters", {})

func _domain_changed(old_formulas: Array, new_formulas: Array, index: int) -> bool:
	if index < 0 or index >= old_formulas.size() or index >= new_formulas.size():
		return false
	return old_formulas[index].get("domain") != new_formulas[index].get("domain")

func _advance() -> void:
	if not _active:
		return
	_index += 1
	if _index >= _steps.size():
		stop()
	else:
		_apply_step()

func _draw() -> void:
	if not _target_valid:
		draw_rect(Rect2(Vector2.ZERO, size), DIM_COLOR)
		return
	var hole := _target_rect.grow(8.0).intersection(Rect2(Vector2.ZERO, size))
	draw_rect(Rect2(0, 0, size.x, hole.position.y), DIM_COLOR)
	draw_rect(Rect2(0, hole.end.y, size.x, size.y - hole.end.y), DIM_COLOR)
	draw_rect(Rect2(0, hole.position.y, hole.position.x, hole.size.y), DIM_COLOR)
	draw_rect(Rect2(hole.end.x, hole.position.y, size.x - hole.end.x, hole.size.y), DIM_COLOR)
	var halo := StyleBoxFlat.new()
	halo.bg_color = Color(1, 1, 1, 0.025)
	halo.border_color = Color(ACCENT, 0.22)
	halo.set_border_width_all(5)
	halo.set_corner_radius_all(13)
	draw_style_box(halo, hole)
	var ring := StyleBoxFlat.new()
	ring.bg_color = Color(0, 0, 0, 0)
	ring.border_color = Color("dfe8ff")
	ring.set_border_width_all(2)
	ring.set_corner_radius_all(10)
	draw_style_box(ring, hole)
