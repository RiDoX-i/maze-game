extends Control

## Shown when a Classic run ends with a record-worthy tier. The player types a
## name on an on-screen pixel keyboard (works identically on phone and desktop —
## no OS keyboard needed), then the World Records board is shown.

const RECORDS_SCENE := "res://scenes/world_records.tscn"
const MENU_BG := "res://assets/sprites/ui/menu_bg.png"
const PL := preload("res://scripts/pixel_label.gd")
const KEYS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

var _name := ""
var _tier := 1
var _blink := 0.0
var _name_label: PixelLabel


func _ready() -> void:
	PixelUI.apply(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_tier = GameState.last_tier_reached
	_build()


func _process(delta: float) -> void:
	_blink += delta
	var cursor := "_" if fmod(_blink, 1.0) < 0.5 else " "
	_name_label.text = _name + cursor


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
	vbox.offset_top = 70.0
	vbox.offset_bottom = -40.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 22)
	add_child(vbox)

	vbox.add_child(_label("NEW RECORD!", 9, Color("#ffd23f")))
	vbox.add_child(_label("YOU REACHED TIER %d" % _tier, 4, Color("#bfe3ff")))
	vbox.add_child(_label("ENTER YOUR NAME", 3, Color("#9a93c8")))

	var name_panel := Panel.new()
	name_panel.add_theme_stylebox_override("panel", PixelUI.panel_style())
	name_panel.custom_minimum_size = Vector2(440, 96)
	name_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_name_label = _label("", 7, Color.WHITE)
	_name_label.set_anchors_preset(Control.PRESET_CENTER)
	name_panel.add_child(_name_label)
	vbox.add_child(name_panel)

	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for i in KEYS.length():
		grid.add_child(_key_button(KEYS[i]))
	vbox.add_child(grid)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_child(_wide_button("SPACE", 200, _on_space))
	row.add_child(_wide_button("DEL", 150, _on_del))
	row.add_child(_wide_button("SAVE", 200, _on_save))
	vbox.add_child(row)


func _label(text: String, scale: int, color: Color) -> PixelLabel:
	var lab := PL.new()
	lab.text = text
	lab.pixel_scale = scale
	lab.align = PixelLabel.Align.CENTER
	lab.color = color
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lab


func _key_button(ch: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(86, 86)
	var lab := PL.new()
	lab.text = ch
	lab.pixel_scale = 5
	lab.align = PixelLabel.Align.CENTER
	lab.set_anchors_preset(Control.PRESET_CENTER)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lab)
	b.pressed.connect(_on_key.bind(ch))
	return b


func _wide_button(text: String, width: int, handler: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(width, 86)
	var lab := PL.new()
	lab.text = text
	lab.pixel_scale = 4
	lab.align = PixelLabel.Align.CENTER
	lab.set_anchors_preset(Control.PRESET_CENTER)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lab)
	b.pressed.connect(handler)
	return b


func _on_key(ch: String) -> void:
	if _name.length() < HighScores.NAME_MAX:
		_name += ch


func _on_space() -> void:
	if _name.length() > 0 and _name.length() < HighScores.NAME_MAX:
		_name += " "


func _on_del() -> void:
	if _name.length() > 0:
		_name = _name.substr(0, _name.length() - 1)


func _on_save() -> void:
	HighScores.submit(_name, _tier)
	get_tree().change_scene_to_file(RECORDS_SCENE)
