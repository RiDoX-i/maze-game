extends Control

## The World Records board (Classic mode — highest tier reached). Opened from the
## main-menu corner button, and shown right after a record name is entered, with
## the player's fresh entry highlighted.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const MENU_BG := "res://assets/sprites/ui/menu_bg.png"
const PL := preload("res://scripts/pixel_label.gd")


func _ready() -> void:
	PixelUI.apply(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	HighScores.last_submitted_rank = 0   # one-shot highlight only


func _build() -> void:
	if ResourceLoader.exists(MENU_BG):
		var bg := TextureRect.new()
		bg.texture = load(MENU_BG)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 24.0
	vbox.offset_right = -24.0
	vbox.offset_top = 90.0
	vbox.offset_bottom = -50.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	add_child(vbox)

	vbox.add_child(_label("WORLD RECORDS", 7, Color("#ffd23f"), 1))
	vbox.add_child(_label("ENDLESS MODE", 3, Color("#9a93c8"), 1))

	var entries := HighScores.entries()
	if entries.is_empty():
		vbox.add_child(_spacer(30))
		vbox.add_child(_label("NO RECORDS YET", 5, Color("#bfe3ff"), 1))
		vbox.add_child(_label("BE THE FIRST", 3, Color("#9a93c8"), 1))
	else:
		vbox.add_child(_spacer(10))
		var highlight := HighScores.last_submitted_rank
		for i in entries.size():
			var entry: Dictionary = entries[i]
			var rank := i + 1
			var line := "%2d  %-8s  TIER %d" % [rank, str(entry["name"]), int(entry["tier"])]
			var color := Color("#ffd23f") if rank == highlight else Color("#e8e8ff")
			vbox.add_child(_label(line, 3, color, 0))

	vbox.add_child(_spacer(20))
	var back := _button("BACK")
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file(MENU_SCENE))
	vbox.add_child(back)


func _label(text: String, scale: int, color: Color, align: int) -> PixelLabel:
	var lab := PL.new()
	lab.text = text
	lab.pixel_scale = scale
	lab.align = align
	lab.color = color
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if align != 1 else Control.SIZE_EXPAND_FILL
	return lab


func _spacer(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _button(text: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(300, 80)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var lab := PL.new()
	lab.text = text
	lab.pixel_scale = 5
	lab.align = PixelLabel.Align.CENTER
	lab.set_anchors_preset(Control.PRESET_CENTER)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lab)
	return b
