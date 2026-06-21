extends Control

## In-game heads-up display: pixel-art hearts, tier / maze progress, countdown
## timer, and the celebratory bonus-heart popup. Reads from GameState signals
## plus per-frame [method set_time] calls from the game scene. All text uses the
## built-in pixel font via PixelLabel.

signal pause_pressed()

@onready var _progress: PixelLabel = $TopBar/Progress
@onready var _timer: PixelLabel = $TimerLabel
@onready var _bonus: PixelLabel = $BonusPopup
@onready var _pause_button: Button = $PauseButton
@onready var _hearts: Array = [
	$TopBar/Hearts/Heart0, $TopBar/Hearts/Heart1, $TopBar/Hearts/Heart2,
]

var _heart_full: Texture2D
var _heart_empty: Texture2D


func _ready() -> void:
	PixelUI.apply(self)
	_heart_full = PixelIcons.heart(true)
	_heart_empty = PixelIcons.heart(false)
	_bonus.pivot_offset = _bonus.size * 0.5
	_pause_button.icon = PixelIcons.pause(6)
	_pause_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())

	GameState.hearts_changed.connect(_on_hearts_changed)
	GameState.progress_changed.connect(_on_progress_changed)
	GameState.bonus_heart_won.connect(_on_bonus_heart_won)
	GameState.campaign_level_changed.connect(_on_campaign_level_changed)

	if GameState.is_classic_mode():
		# Campaign has no hearts; the top bar shows LEVEL N / 1000 instead.
		for heart in _hearts:
			heart.visible = false
		_on_campaign_level_changed(GameState.campaign_level)
	else:
		_on_hearts_changed(GameState.hearts)
		_on_progress_changed(GameState.current_tier, GameState.maze_in_tier)
	if GameState.is_trap_mode():
		_timer.text = "TRAP MODE"
		_timer.color = Color("#ff675b")
		_timer.pixel_scale = 5


## Update the countdown display (seconds remaining).
func set_time(seconds: float) -> void:
	if GameState.is_trap_mode():
		return
	seconds = maxf(seconds, 0.0)
	_timer.text = "%0.1f" % seconds
	_timer.color = Color("#ef476f") if seconds <= 5.0 else Color.WHITE


func _on_hearts_changed(hearts: int) -> void:
	for i in _hearts.size():
		_hearts[i].texture = _heart_full if i < hearts else _heart_empty


func _on_progress_changed(tier: int, maze_in_tier: int) -> void:
	if GameState.is_classic_mode():
		return   # CLASSIC drives the label via campaign_level_changed instead.
	if GameState.is_trap_mode():
		var map_number := PreparedTrapMaps.index_for_progress(tier, maze_in_tier) + 1
		_progress.text = "LEVEL %d/%d" % [map_number, PreparedTrapMaps.count()]
	else:
		_progress.text = "TIER %d  MAZE %d/%d" % [tier, maze_in_tier, GameState.MAZES_PER_TIER]


## CLASSIC campaign: top bar shows the current level out of the total.
func _on_campaign_level_changed(level: int) -> void:
	_progress.text = "LEVEL %d/%d" % [level, GameState.CAMPAIGN_TOTAL_LEVELS]


func _on_bonus_heart_won() -> void:
	_bonus.text = "+1 HEART!"
	_bonus.pivot_offset = _bonus.size * 0.5
	_bonus.modulate.a = 1.0
	_bonus.scale = Vector2.ONE
	var tween := create_tween()
	tween.tween_property(_bonus, "scale", Vector2(1.3, 1.3), 0.3)
	tween.tween_property(_bonus, "scale", Vector2.ONE, 0.2)
	tween.tween_property(_bonus, "modulate:a", 0.0, 1.4).set_delay(0.3)


## Tint the pause button while a pause is queued (it fires after the map ends).
func set_pause_queued(on: bool) -> void:
	if _pause_button != null:
		_pause_button.modulate = Color("#ffd23f") if on else Color.WHITE


## Flash a big centred pixel banner (tier clear, queued-pause notice, etc.).
func announce(text: String, color: Color = Color.WHITE) -> void:
	var lab := PixelLabel.new()
	lab.text = text
	lab.pixel_scale = 6
	lab.align = PixelLabel.Align.CENTER
	lab.color = color
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.anchor_left = 0.0
	lab.anchor_right = 1.0
	lab.anchor_top = 0.4
	lab.anchor_bottom = 0.4
	lab.offset_bottom = 60.0
	add_child(lab)
	lab.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(lab, "modulate:a", 1.0, 0.15)
	tween.tween_interval(0.7)
	tween.tween_property(lab, "modulate:a", 0.0, 0.5)
	tween.tween_callback(lab.queue_free)
