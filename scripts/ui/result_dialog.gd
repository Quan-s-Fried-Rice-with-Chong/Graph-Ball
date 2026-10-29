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
	heading.add_theme_color_override("font_color", Color("6ee0c7") if result.success else Color("ff7863"))
	reason.visible = not result.success
	reason.text = result.reason
	reason.add_theme_color_override("font_color", Color("f2a095"))
	if result.success:
		var record: Dictionary = result.get("record", {})
		var best_time: float = float(record.get("best_time", result.elapsed))
		var stars := "★★★" if result.formula_count <= 1 else ("★★☆" if result.formula_count == 2 else "★☆☆")
		summary.text = "用时  %.2f s\n最佳  %.2f s\n公式数  %d\n简洁度  %s" % [result.elapsed, best_time, result.formula_count, stars]
	else:
		summary.text = "用时  %.2f s" % result.elapsed
	retry_button.text = "再玩一次" if result.success else "重试"
	next_button.visible = result.success
	next_button.text = "下一关  →" if has_next else "返回关卡选择"
	%ResultLevelsButton.visible = not result.success or has_next
	show()
	if result.success:
		next_button.grab_focus()
	else:
		retry_button.grab_focus()
