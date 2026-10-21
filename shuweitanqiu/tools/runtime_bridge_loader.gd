extends Node
## Keep local QA independent of the currently running editor preview.

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--prototype-test"):
		return
	var bridge_script = load("res://addons/godot-mcp/runtime_bridge.gd")
	add_child(bridge_script.new())
