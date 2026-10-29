extends Control

signal start_requested
signal levels_requested
signal help_requested

func _ready() -> void:
	%StartMenuButton.pressed.connect(func(): start_requested.emit())
	%MenuLevelsButton.pressed.connect(func(): levels_requested.emit())
	%MenuHelpButton.pressed.connect(func(): help_requested.emit())
	visibility_changed.connect(_on_visibility_changed)

func set_started(started: bool) -> void:
	%StartMenuButton.title_text = "继续游戏" if started else "开始游戏"
	%StartMenuButton.caption_text = "CONTINUE" if started else "START"
	%StartMenuButton.queue_redraw()

func _on_visibility_changed() -> void:
	if visible and is_node_ready():
		%StartMenuButton.grab_focus.call_deferred()
