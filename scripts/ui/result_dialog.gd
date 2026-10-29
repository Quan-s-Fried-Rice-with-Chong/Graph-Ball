extends Control

signal retry_requested
signal next_requested
signal levels_requested

@onready var heading: Label = %ResultHeading
@onready var reason: Label = %ResultReason
@onready var summary: Label = %ResultSummary
@onready var retry_button: Button = %RetryResultButton
@onready var next_button: Button = %NextButton

func _ready() -> void:
	hide()
	retry_button.pressed.connect(func(): retry_requested.emit())
	next_button.pressed.connect(func(): next_requested.emit())
	%ResultLevelsButton.pressed.connect(func(): levels_requested.emit())

func present(result: Dictionary, has_next: bool) -> void:
	heading.text = "通关" if result.success else "未通过"
	heading.add_theme_color_override("font_color", Color("187a6b") if result.success else Color("20334b"))
	reason.visible = not result.success
	reason.text = result.reason
	summary.text = "用时  %.2f s     ·     检查点  %d / %d\n使用公式  %d 条" % [result.elapsed, result.reached, result.total, result.formula_count]
	var record: Dictionary = result.get("record", {})
	if result.success and not record.is_empty():
		summary.text += "\n最佳  %.2f s     ·     最少公式  %d 条" % [record.best_time, record.best_formula_count]
	if result.success:
		var stars := "★★★" if result.formula_count <= 1 else ("★★☆" if result.formula_count == 2 else "★☆☆")
		summary.text += "\n简洁度  %s     ·     公式越少，评价越高" % stars
	retry_button.text = "再玩一次" if result.success else "重试"
	next_button.visible = result.success
	next_button.text = "下一关  →" if has_next else "返回关卡选择"
	show()
	if result.success:
		next_button.grab_focus()
	else:
		retry_button.grab_focus()
