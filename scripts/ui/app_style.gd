class_name AppStyle
extends RefCounted

const BG := Color("090d17")
const PANEL := Color("101928")
const LINE := Color("233248")
const TEXT := Color("ecf3fb")
const MUTED := Color("8b9bb2")
const MINT := Color("6de3d0")
const VIOLET := Color("b4a6ff")
const RED := Color("ff8194")
const CELLS := [Color("6de3d0"), Color("8dbbff"), Color("b4a6ff"), Color("f5c288")]
const KEYS := ["U", "I", "J", "K"]


static func box(color: Color, radius: int = 12, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_border_width_all(1)
	style.border_color = border
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


static func make_theme() -> Theme:
	var result := Theme.new()
	var font := FontVariation.new()
	font.base_font = load("res://assets/fonts/NotoSansKR.ttf")
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 450.0}
	result.default_font = font
	result.default_font_size = 14
	result.set_color("font_color", "Label", TEXT)
	result.set_color("font_color", "Button", TEXT)
	result.set_color("font_hover_color", "Button", MINT)
	result.set_color("font_disabled_color", "Button", MUTED.darkened(0.3))
	result.set_stylebox("normal", "Button", box(Color("192638"), 9, LINE))
	result.set_stylebox("hover", "Button", box(Color("24344b"), 9, MINT.darkened(0.4)))
	result.set_stylebox("pressed", "Button", box(Color("304457"), 9, MINT))
	result.set_stylebox("disabled", "Button", box(Color("111a27"), 9, LINE))
	result.set_stylebox("focus", "Button", box(Color.TRANSPARENT, 9, MINT))
	for type in ["LineEdit", "SpinBox"]:
		result.set_color("font_color", type, TEXT)
	result.set_stylebox("normal", "LineEdit", box(Color("0b1320"), 7, LINE))
	result.set_stylebox("focus", "LineEdit", box(Color("101e2d"), 7, MINT.darkened(0.4)))
	result.set_stylebox("panel", "ItemList", box(Color("0b1320"), 9, LINE))
	result.set_color("font_color", "ItemList", TEXT)
	result.set_color("font_selected_color", "ItemList", MINT)
	result.set_stylebox("selected", "ItemList", box(Color("203a46"), 6))
	result.set_constant("separation", "VBoxContainer", 12)
	result.set_constant("separation", "HBoxContainer", 12)
	return result


static func label(text: String, font_size: int = 14, color: Color = TEXT) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	return node


static func button(text: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.pressed.connect(action)
	return node


static func card() -> PanelContainer:
	var node := PanelContainer.new()
	node.add_theme_stylebox_override("panel", box(PANEL, 16, LINE))
	return node


static func launch(chart_path: String, maker: bool = false, autoplay: bool = false, start_phrase: int = -1, auto_mode: bool = false) -> int:
	var arguments := PackedStringArray()
	if OS.has_feature("editor"):
		arguments.append_array(["--path", ProjectSettings.globalize_path("res://")])
	arguments.append("--")
	if maker:
		arguments.append("--chart-maker")
	if autoplay:
		arguments.append("--autoplay")
	if not maker and start_phrase >= 0:
		arguments.append_array(["--start-phrase", str(start_phrase)])
	if not maker and auto_mode:
		arguments.append("--auto-mode")
	arguments.append_array(["--chart", chart_path])
	return OS.create_instance(arguments)


static func launch_gui_editor() -> int:
	var arguments := PackedStringArray()
	if OS.has_feature("editor"):
		arguments.append_array(["--path", ProjectSettings.globalize_path("res://")])
	arguments.append_array(["--", "--gui-editor"])
	return OS.create_instance(arguments)

