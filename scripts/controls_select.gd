extends Control

## Settings window: pick the control scheme (SWIPE or JOYSTICK) for each game
## mode. Built procedurally like the other menus; choosing reloads the screen so
## the highlighted scheme refreshes. Persists via [GameSettings].

const MENU_SCENE := "res://scenes/main_menu.tscn"
const PL := preload("res://scripts/pixel_label.gd")

const GOLD := Color("#ffd23f")
const DIM := Color("#6a6488")

## [label, settings key] per mode, in display order.
const MODES := [["CLASSIC", "classic"], ["ENDLESS", "endless"], ["TRAP", "trap"]]


func _ready() -> void:
	PixelUI.apply(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#141026")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24.0
	root.offset_right = -24.0
	root.offset_top = 40.0
	root.offset_bottom = -40.0
	root.add_theme_constant_override("separation", 14)
	add_child(root)

	root.add_child(_label("CONTROLS", 7, GOLD, PixelLabel.Align.CENTER))
	root.add_child(_label("PICK HOW TO MOVE IN EACH MODE", 2, DIM, PixelLabel.Align.CENTER))
	root.add_child(_spacer(10))

	var list := VBoxContainer.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 14)
	root.add_child(list)
	for entry in MODES:
		list.add_child(_mode_card(entry[0], entry[1]))

	root.add_child(_spacer(8))
	var back := _button("BACK", 4, Color.WHITE, Color("#241d44"))
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file(MENU_SCENE))
	root.add_child(back)


func _mode_card(label: String, key: String) -> Control:
	var current := GameSettings.control_for(key)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _card_style())

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(_label(label, 4, Color("#cfe3ff"), PixelLabel.Align.LEFT))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(_scheme_button("SWIPE", key, GameSettings.SWIPE, current))
	row.add_child(_scheme_button("JOYSTICK", key, GameSettings.JOYSTICK, current))
	box.add_child(row)
	return panel


func _scheme_button(text: String, key: String, scheme: String, current: String) -> Button:
	var selected := current == scheme
	var b := _button(text, 3, GOLD if selected else Color.WHITE, Color("#3a2c66") if selected else Color("#241d44"))
	b.custom_minimum_size = Vector2(220, 64)
	b.pressed.connect(_on_pick.bind(key, scheme))
	return b


func _on_pick(key: String, scheme: String) -> void:
	GameSettings.set_control(key, scheme)
	get_tree().reload_current_scene()


# --- Widgets ---------------------------------------------------------------

func _card_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#1d1838")
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(2)
	sb.border_color = Color("#3a3656")
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 14
	return sb


func _label(text: String, scale: int, color: Color, align: PixelLabel.Align) -> PixelLabel:
	var lab := PL.new()
	lab.text = text
	lab.pixel_scale = scale
	lab.color = color
	lab.align = align
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lab


func _spacer(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _button(text: String, scale: int, color: Color, _bg: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(240, 60)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lab := PL.new()
	lab.text = text
	lab.pixel_scale = scale
	lab.color = color
	lab.align = PixelLabel.Align.CENTER
	lab.set_anchors_preset(Control.PRESET_FULL_RECT)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lab)
	return b
