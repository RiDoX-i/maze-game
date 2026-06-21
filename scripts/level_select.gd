extends Control

## CLASSIC campaign hub: a scrollable list of chapters (10 levels each), built
## procedurally like [WorldRecords]. Each chapter card is tinted with its art
## theme so the player can see, at a glance, which look that block of 10 levels
## wears (the requested "theme-informing background"). Only the current level is
## playable — completed levels are locked (cannot be replayed) and future levels
## stay locked until reached.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const GAME_SCENE := "res://scenes/game.tscn"
const PL := preload("res://scripts/pixel_label.gd")

const GOLD := Color("#ffd23f")
const LILAC := Color("#9a93c8")
const DIM := Color("#6a6488")
const CLEARED_COL := Color("#57f3a0")
const LOCK_COL := Color("#3a3656")


func _ready() -> void:
	PixelUI.apply(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var total: int = CampaignProgress.TOTAL_LEVELS
	var per: int = GameState.CAMPAIGN_LEVELS_PER_CHAPTER
	var completed: int = CampaignProgress.levels_completed()
	var current: int = CampaignProgress.current_level()
	var done_all: bool = CampaignProgress.is_campaign_complete()
	var current_chapter: int = (current - 1) / per
	var theme := MazeTheme.for_campaign_level(current)

	# Backdrop tinted by the current chapter's theme.
	var bg := ColorRect.new()
	bg.color = Color(theme.get("tint", LILAC)).darkened(0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 20.0
	root.offset_right = -20.0
	root.offset_top = 24.0
	root.offset_bottom = -24.0
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	root.add_child(_label("CLASSIC", 7, GOLD, PixelLabel.Align.CENTER))
	var progress := "ALL %d LEVELS CLEARED" % total if done_all else "LEVEL %d / %d" % [current, total]
	root.add_child(_label(progress, 4, Color("#bfe3ff"), PixelLabel.Align.CENTER))
	root.add_child(_label("EACH CHAPTER IS 10 LEVELS - ONE THEME", 2, DIM, PixelLabel.Align.CENTER))
	root.add_child(_spacer(6))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)

	var chapters: int = total / per
	var current_card: Control = null
	for c in chapters:
		var card := _chapter_card(c, per, current, completed, done_all)
		list.add_child(card)
		if c == current_chapter:
			current_card = card

	root.add_child(_spacer(6))
	var back := _button("BACK", 4, Color.WHITE)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file(MENU_SCENE))
	root.add_child(back)

	# Jump straight to where the player is.
	if current_card != null:
		scroll.call_deferred("ensure_control_visible", current_card)


## One chapter card: themed panel + header + 10-level status strip, plus a PLAY
## button on the single unlocked (current) chapter.
func _chapter_card(chapter: int, per: int, current: int, completed: int, done_all: bool) -> Control:
	var first: int = chapter * per + 1
	var last: int = first + per - 1
	var theme := MazeTheme.for_campaign_level(first)
	var tint := Color(theme.get("tint", LILAC))

	var cleared: bool = done_all or completed >= last
	var unlocked: bool = (not done_all) and current >= first and current <= last

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _card_style(tint, unlocked))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_col: Color = tint.lightened(0.35) if not done_all and current < first else CLEARED_COL if cleared else tint.lightened(0.2)
	header.add_child(_label("CH %d  %s" % [chapter + 1, str(theme.get("name", "")).to_upper()],
		3, name_col, PixelLabel.Align.LEFT))
	header.add_child(_label("LV %03d-%03d" % [first, last], 2, DIM, PixelLabel.Align.RIGHT))
	box.add_child(header)

	var dots := HBoxContainer.new()
	dots.add_theme_constant_override("separation", 6)
	for i in per:
		dots.add_child(_dot(first + i, current, completed, done_all, tint))
	box.add_child(dots)

	if unlocked:
		var play := _button("PLAY LEVEL %d" % current, 4, GOLD)
		play.pressed.connect(_on_play.bind(current))
		box.add_child(play)
	else:
		var status: String = "CLEARED" if cleared else "LOCKED"
		var col: Color = CLEARED_COL if cleared else DIM
		box.add_child(_label(status, 2, col, PixelLabel.Align.LEFT))

	return panel


func _on_play(level: int) -> void:
	GameState.start_campaign(level)
	get_tree().change_scene_to_file(GAME_SCENE)


# --- Widgets ---------------------------------------------------------------

func _dot(level: int, current: int, completed: int, done_all: bool, tint: Color) -> ColorRect:
	var d := ColorRect.new()
	d.custom_minimum_size = Vector2(24, 14)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if done_all or level <= completed:
		d.color = tint                 # cleared
	elif level == current:
		d.color = GOLD                 # the one playable level
	else:
		d.color = LOCK_COL             # still locked
	return d


func _card_style(tint: Color, unlocked: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = tint.darkened(0.62) if unlocked else tint.darkened(0.78)
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(4 if unlocked else 2)
	sb.border_color = GOLD if unlocked else tint.darkened(0.25)
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
	b.custom_minimum_size = Vector2(280, 72)
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
