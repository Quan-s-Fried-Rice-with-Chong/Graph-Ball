extends RefCounted

const INK := Color("30343b")
const MUTED := Color("81858c")
const ACCENT := Color("4968b5")
const LINE := Color("e4e5e8")

static func panel(color: Color = Color.WHITE, radius: int = 3, border: Color = LINE) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

static func flat(color: Color = Color.WHITE) -> StyleBoxFlat:
	var style := panel(color, 0, color)
	style.set_border_width_all(0)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

static func create() -> Theme:
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "Noto Sans", "sans-serif"])
	theme.default_font = font
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", INK)
	theme.set_color("default_color", "RichTextLabel", INK)
	theme.set_constant("separation", "VBoxContainer", 12)
	theme.set_constant("separation", "HBoxContainer", 12)
	theme.set_stylebox("panel", "PanelContainer", panel())
	theme.set_type_variation("FlatPanel", "PanelContainer")
	theme.set_stylebox("panel", "FlatPanel", flat())
	theme.set_type_variation("ToolbarPanel", "PanelContainer")
	var toolbar := flat(Color("fafafa"))
	toolbar.border_width_bottom = 1
	toolbar.border_color = LINE
	theme.set_stylebox("panel", "ToolbarPanel", toolbar)
	theme.set_type_variation("SidebarPanel", "PanelContainer")
	var sidebar := flat()
	sidebar.border_width_right = 1
	sidebar.border_color = Color("d7d9df")
	theme.set_stylebox("panel", "SidebarPanel", sidebar)
	theme.set_type_variation("FooterPanel", "PanelContainer")
	var footer := flat()
	footer.border_width_top = 1
	footer.border_color = LINE
	theme.set_stylebox("panel", "FooterPanel", footer)
	for type in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type, panel(Color.WHITE, 3))
		theme.set_stylebox("hover", type, panel(Color("f2f4fa"), 3, Color("c8cede")))
		theme.set_stylebox("pressed", type, panel(Color("e8edf8"), 3, Color("aab9dc")))
		theme.set_stylebox("disabled", type, panel(Color("fafafa"), 3, LINE))
		theme.set_stylebox("focus", type, panel(Color(0, 0, 0, 0), 3, ACCENT))
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			theme.set_color(state, type, INK)
		theme.set_color("font_disabled_color", type, Color("b3b6bc"))
	theme.set_type_variation("PrimaryButton", "Button")
	for state in ["normal", "hover", "pressed"]:
		var color := ACCENT if state == "normal" else Color("3d5ca7")
		theme.set_stylebox(state, "PrimaryButton", panel(color, 3, color))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, "PrimaryButton", Color.WHITE)
	for variation in ["NavButton", "ToolButton"]:
		theme.set_type_variation(variation, "Button")
		for state in ["normal", "disabled"]:
			theme.set_stylebox(state, variation, flat(Color(1, 1, 1, 0)))
		for state in ["hover", "pressed"]:
			theme.set_stylebox(state, variation, flat(Color("eef0f5") if state == "hover" else Color("e3e8f3")))
	theme.set_type_variation("DisclosureButton", "ToolButton")
	theme.set_stylebox("pressed", "DisclosureButton", flat(Color(1, 1, 1, 0)))
	var separator := StyleBoxLine.new()
	separator.color = LINE
	separator.thickness = 1
	theme.set_stylebox("separator", "HSeparator", separator)
	theme.set_stylebox("normal", "LineEdit", panel(Color.WHITE, 2, Color("dadde3")))
	theme.set_stylebox("focus", "LineEdit", panel(Color.WHITE, 2, ACCENT))
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("caret_color", "LineEdit", ACCENT)
	for state in ["slider", "grabber_area", "grabber_area_highlight"]:
		var color := Color("e3e5e9") if state == "slider" else Color("8e9fc9")
		var track := flat(color)
		track.set_corner_radius_all(2)
		track.content_margin_top = 1.5
		track.content_margin_bottom = 1.5
		theme.set_stylebox(state, "HSlider", track)
	theme.set_stylebox("panel", "PopupMenu", panel())
	theme.set_stylebox("hover", "PopupMenu", flat(Color("eef1f8")))
	theme.set_color("font_color", "PopupMenu", INK)
	theme.set_color("font_hover_color", "PopupMenu", ACCENT)
	theme.set_color("font_color", "TooltipLabel", Color.WHITE)
	theme.set_font_size("font_size", "TooltipLabel", 13)
	theme.set_stylebox("panel", "TooltipPanel", panel(Color("42464e"), 3, Color("42464e")))
	var math_font := SystemFont.new()
	math_font.font_names = PackedStringArray(["Cambria Math", "STIX Two Math", "Times New Roman"])
	theme.set_type_variation("MathLabel", "Label")
	theme.set_font("font", "MathLabel", math_font)
	theme.set_font_size("font_size", "MathLabel", 23)
	return theme

