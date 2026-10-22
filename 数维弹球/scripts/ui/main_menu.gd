extends Control

signal start_requested
signal levels_requested
signal help_requested

func _ready() -> void:
	%StartMenuButton.pressed.connect(func(): start_requested.emit())
	%MenuLevelsButton.pressed.connect(func(): levels_requested.emit())
	%MenuHelpButton.pressed.connect(func(): help_requested.emit())

func set_started(started: bool) -> void:
	%StartMenuButton.text = "继续游戏" if started else "开始游戏"
