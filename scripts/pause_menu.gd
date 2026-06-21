extends Control

## In-game pause overlay. Built entirely in code so it needs no scene wiring.
##
## By design the game can only actually pause BETWEEN maps (see game.gd): pausing
## mid-map is deferred until the current map is won or lost, so a player can't
## freeze a map to study it. The overlay shows the run's general score and a
## Resume button (plus a Main Menu exit).

signal resume_requested()
signal menu_requested()

const PL := preload("res://scripts/pixel_label.gd")

var _score_label: PixelLabel


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	PixelUI.apply(self)
	_build()


## Show the overlay with the given score text (newlines allowed).
func open(score_text: String) -> void:
	_score_label.text = score_text
	visible = true


func close() -> void:
	visible = false


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", PixelUI.panel_style())
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -260.0
	panel.offset_right = 260.0
	panel.offset_top = -280.0
	panel.offset_bottom = 280.0
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 30.0
	vbox.offset_top = 40.0
	vbox.offset_right = -30.0
	vbox.offset_bottom = -40.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 26)
	panel.add_child(vbox)

	vbox.add_child(_label("PAUSED", 8, Color("#ffd23f")))
	_score_label = _label("", 3, Color("#dfe2ff"))
	vbox.add_child(_score_label)

	var resume_btn := _button("RESUME")
	resume_btn.pressed.connect(_on_resume)
	vbox.add_child(resume_btn)

	var menu_btn := _button("MAIN MENU")
	menu_btn.pressed.connect(_on_menu)
	vbox.add_child(menu_btn)


func _label(text: String, scale: int, color: Color) -> PixelLabel:
	var lab := PL.new()
	lab.text = text
	lab.pixel_scale = scale
	lab.align = PixelLabel.Align.CENTER
	lab.color = color
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lab


func _button(text: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(360, 84)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var lab := PL.new()
	lab.text = text
	lab.pixel_scale = 5
	lab.align = PixelLabel.Align.CENTER
	lab.set_anchors_preset(Control.PRESET_CENTER)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lab)
	return b


func _on_resume() -> void:
	visible = false
	resume_requested.emit()


func _on_menu() -> void:
	menu_requested.emit()
