extends Control
## The menu: opened with the menu button at the top. It pauses the game and has big
## buttons to go back to playing, to read about the game, and to close the app.

const BG := Color(0.1, 0.15, 0.3, 0.6)
const CARD := Color(1, 1, 1, 0.95)
const TEXT := Color(0.2, 0.2, 0.3)

var _main_box: VBoxContainer
var _about_box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = BG
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = CARD
	style.set_corner_radius_all(28)
	style.set_content_margin_all(36)
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)
	var pages := VBoxContainer.new()
	card.add_child(pages)

	_main_box = _page(pages)
	_label(_main_box, "Menu", 48)
	_button(_main_box, "Main lagi", Color(0.35, 0.75, 0.3), close)
	_button(_main_box, "Tentang", Color(0.3, 0.65, 0.95), _show_about)
	_button(_main_box, "Keluar", Color(0.9, 0.35, 0.3), func(): get_tree().quit())

	_about_box = _page(pages)
	_label(_about_box, "JumpBox", 48)
	_label(_about_box, "Versi " + str(ProjectSettings.get_setting("application/config/version", "?")), 26)
	_label(_about_box, "Main tanpa internet, gratis", 26)
	_label(_about_box, "Dibuat oleh Yusuf\nThreads: @yusufmalikul", 30)
	_label(_about_box, "Dibuat dengan Godot Engine (lisensi MIT).", 20)
	_button(_about_box, "Kembali", Color(0.3, 0.65, 0.95), _show_main)


func open() -> void:
	_show_main()
	visible = true
	get_tree().paused = true


func close() -> void:
	visible = false
	get_tree().paused = false


func _show_about() -> void:
	_main_box.visible = false
	_about_box.visible = true


func _show_main() -> void:
	_main_box.visible = true
	_about_box.visible = false


func _page(parent: Node) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	parent.add_child(box)
	return box


func _label(parent: Node, text: String, font_size: int) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", TEXT)
	parent.add_child(l)


func _button(parent: Node, text: String, color: Color, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(420, 96)
	b.add_theme_font_size_override("font_size", 36)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	for state in ["normal", "hover", "pressed", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color = color.darkened(0.15) if state == "pressed" else color
		s.set_corner_radius_all(48)
		b.add_theme_stylebox_override(state, s)
	b.pressed.connect(action)
	parent.add_child(b)
