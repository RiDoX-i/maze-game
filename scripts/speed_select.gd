extends Control

## The Speeds window: shows the five speed tiers, their unlock XP, and lets the
## player select any they've unlocked. Built procedurally like [WorldRecords] /
## level-select. Selecting reloads the screen so every card's state refreshes.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const PL := preload("res://scripts/pixel_label.gd")

const GOLD := Color("#ffd23f")
const DIM := Color("#6a6488")
const LOCK_COL := Color("#3a3656")

## Trail swatch colour per VFX style.
const VFX_COLOR := {
	"dust": Color("#9a948a"), "wind": Color("#cfe0ff"), "fire": Color("#ff8a2c"),
	"electric": Color("#9becff"), "cosmic": Color("#c77bff"),
}


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
	root.offset_top = 28.0
	root.offset_bottom = -28.0
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	root.add_child(_label("SPEEDS", 7, GOLD, PixelLabel.Align.CENTER))
	root.add_child(_label("TOTAL XP: %d" % PlayerProgress.total_xp(), 4, Color("#9be7ff"), PixelLabel.Align.CENTER))
	root.add_child(_label("WIN MAPS TO EARN XP AND UNLOCK FASTER RUNS", 2, DIM, PixelLabel.Align.CENTER))
	root.add_child(_spacer(8))

	var list := VBoxContainer.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	root.add_child(list)
	for i in PlayerProgress.SPEEDS.size():
		list.add_child(_card(i))

	root.add_child(_spacer(6))
	var back := _button("BACK", 4, Color.WHITE)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file(MENU_SCENE))
	root.add_child(back)


func _card(index: int) -> Control:
	var sp: Dictionary = PlayerProgress.SPEEDS[index]
	var vfx := str(sp["vfx"])
	var tint: Color = VFX_COLOR.get(vfx, DIM)
	var unlocked := PlayerProgress.is_unlocked(index)
	var selected := index == PlayerProgress.selected_index()

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _card_style(tint, selected, unlocked))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_col: Color = tint.lightened(0.3) if unlocked else DIM
	header.add_child(_label(str(sp["name"]), 4, name_col, PixelLabel.Align.LEFT))
	header.add_child(_label("SPD %d" % int(sp["speed"]), 2, DIM, PixelLabel.Align.RIGHT))
	box.add_child(header)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var swatch := ColorRect.new()
	swatch.color = tint if unlocked else LOCK_COL
	swatch.custom_minimum_size = Vector2(28, 18)
	row.add_child(swatch)
	row.add_child(_label("TRAIL: %s" % vfx.to_upper(), 2, Color("#bfb9e0") if unlocked else DIM, PixelLabel.Align.LEFT))
	box.add_child(row)

	if selected:
		box.add_child(_label("SELECTED", 3, GOLD, PixelLabel.Align.LEFT))
	elif unlocked:
		var pick := _button("SELECT", 3, Color.WHITE)
		pick.pressed.connect(_on_select.bind(index))
		box.add_child(pick)
	else:
		box.add_child(_label("LOCKED - NEED %d XP" % PlayerProgress.xp_to_unlock(index), 2, Color("#ff9b8a"), PixelLabel.Align.LEFT))

	return panel


func _on_select(index: int) -> void:
	if PlayerProgress.select_speed(index):
		get_tree().reload_current_scene()   # refresh all card states


# --- Widgets ---------------------------------------------------------------

func _card_style(tint: Color, selected: bool, unlocked: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = tint.darkened(0.6) if unlocked else Color("#1d1838")
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(4 if selected else 2)
	sb.border_color = GOLD if selected else (tint.darkened(0.2) if unlocked else LOCK_COL)
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


func _button(text: String, scale: int, color: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(240, 60)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var lab := PL.new()
	lab.text = text
	lab.pixel_scale = scale
	lab.color = color
	lab.align = PixelLabel.Align.CENTER
	lab.set_anchors_preset(Control.PRESET_CENTER)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lab)
	return b
