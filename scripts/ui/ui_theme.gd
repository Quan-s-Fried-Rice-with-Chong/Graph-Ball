extends RefCounted

const BG := Color("07101a")
const BG_DEEP := Color("050b12")
const PANEL := Color("0f1a28")
const PANEL_RAISED := Color("142131")
const PANEL_HOVER := Color("1a2a3b")
const INK := Color("f2eee4")
const MUTED := Color("8b99ab")
const ACCENT := Color("6ee0c7")
const ACCENT_DARK := Color("3fae99")
const CORAL := Color("ff7863")
const LINE := Color("26384a")
const LINE_SOFT := Color("192938")

static func panel(color: Color = PANEL, radius: int = 4, border: Color = LINE) -> StyleBoxFlat:
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

static func flat(color: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
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
	var toolbar := flat(BG)
	toolbar.border_width_bottom = 1
	toolbar.border_color = LINE
	theme.set_stylebox("panel", "ToolbarPanel", toolbar)
	theme.set_type_variation("SidebarPanel", "PanelContainer")
	var sidebar := flat(PANEL)
	sidebar.border_width_right = 1
	sidebar.border_color = LINE
	theme.set_stylebox("panel", "SidebarPanel", sidebar)
	theme.set_type_variation("FooterPanel", "PanelContainer")
	var footer := flat(BG)
	footer.border_width_top = 1
	footer.border_color = LINE
	theme.set_stylebox("panel", "FooterPanel", footer)
	for type in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type, panel(PANEL_RAISED, 3))
		theme.set_stylebox("hover", type, panel(PANEL_HOVER, 3, Color("3f586d")))
		theme.set_stylebox("pressed", type, panel(Color("24394b"), 3, ACCENT_DARK))
		theme.set_stylebox("disabled", type, panel(Color("0b1521"), 3, LINE_SOFT))
		theme.set_stylebox("focus", type, panel(Color(0, 0, 0, 0), 3, ACCENT))
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			theme.set_color(state, type, INK)
		theme.set_color("font_disabled_color", type, Color("526173"))
	theme.set_type_variation("PrimaryButton", "Button")
	for state in ["normal", "hover", "pressed"]:
		var color := ACCENT if state == "normal" else (Color("8bead6") if state == "hover" else ACCENT_DARK)
		theme.set_stylebox(state, "PrimaryButton", panel(color, 3, color))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(state, "PrimaryButton", BG_DEEP)
	for variation in ["NavButton", "ToolButton"]:
		theme.set_type_variation(variation, "Button")
		for state in ["normal", "disabled"]:
			theme.set_stylebox(state, variation, flat(Color(1, 1, 1, 0)))
		for state in ["hover", "pressed"]:
			theme.set_stylebox(state, variation, flat(Color(1, 1, 1, 0.045) if state == "hover" else Color(ACCENT, 0.10)))
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			theme.set_color(state, variation, INK)
		theme.set_color("font_disabled_color", variation, Color("526173"))
	theme.set_type_variation("DisclosureButton", "ToolButton")
	theme.set_stylebox("pressed", "DisclosureButton", flat(Color(1, 1, 1, 0)))
	var separator := StyleBoxLine.new()
	separator.color = LINE
	separator.thickness = 1
	theme.set_stylebox("separator", "HSeparator", separator)
	theme.set_stylebox("normal", "LineEdit", panel(BG_DEEP, 2, LINE))
	theme.set_stylebox("focus", "LineEdit", panel(BG_DEEP, 2, ACCENT))
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("caret_color", "LineEdit", ACCENT)
	theme.set_color("selection_color", "LineEdit", Color(ACCENT, 0.24))
	for state in ["slider", "grabber_area", "grabber_area_highlight"]:
		var color := Color("182838") if state == "slider" else Color("4eb9a5")
		var track := flat(color)
		track.set_corner_radius_all(2)
		track.content_margin_top = 1.5
		track.content_margin_bottom = 1.5
		theme.set_stylebox(state, "HSlider", track)
	for type in ["VScrollBar", "HScrollBar"]:
		for state in ["scroll", "grabber", "grabber_highlight", "grabber_pressed"]:
			var color := Color(0, 0, 0, 0)
			if state == "grabber":
				color = Color("2a4054")
			elif state == "grabber_highlight":
				color = Color("3a566d")
			elif state == "grabber_pressed":
				color = Color("4b6d84")
			var bar := flat(color)
			bar.content_margin_left = 3
			bar.content_margin_right = 3
			bar.content_margin_top = 3
			bar.content_margin_bottom = 3
			if state != "scroll":
				bar.set_corner_radius_all(3)
			theme.set_stylebox(state, type, bar)
	theme.set_stylebox("panel", "PopupMenu", panel(PANEL_RAISED))
	var popup_hover := flat(Color(ACCENT, 0.14))
	popup_hover.set_corner_radius_all(3)
	theme.set_stylebox("hover", "PopupMenu", popup_hover)
	theme.set_color("font_color", "PopupMenu", INK)
	theme.set_color("font_hover_color", "PopupMenu", ACCENT)
	theme.set_color("font_disabled_color", "PopupMenu", Color("526173"))
	theme.set_color("font_color", "TooltipLabel", INK)
	theme.set_font_size("font_size", "TooltipLabel", 13)
	theme.set_stylebox("panel", "TooltipPanel", panel(Color("1b2a39"), 3, Color("385067")))
	var math_font := SystemFont.new()
	math_font.font_names = PackedStringArray(["Cambria Math", "STIX Two Math", "Times New Roman"])
	theme.set_type_variation("MathLabel", "Label")
	theme.set_font("font", "MathLabel", math_font)
	theme.set_font_size("font_size", "MathLabel", 23)
	return theme

