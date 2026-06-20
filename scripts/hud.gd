extends Control

## In-game heads-up display: pixel-art hearts, tier / maze progress, countdown
## timer, and the celebratory bonus-heart popup. Reads from GameState signals
## plus per-frame [method set_time] calls from the game scene. All text uses the
## built-in pixel font via PixelLabel.

@onready var _progress: PixelLabel = $TopBar/Progress
@onready var _timer: PixelLabel = $TimerLabel
@onready var _bonus: PixelLabel = $BonusPopup
@onready var _hearts: Array = [
	$TopBar/Hearts/Heart0, $TopBar/Hearts/Heart1, $TopBar/Hearts/Heart2,
]

var _heart_full: Texture2D
var _heart_empty: Texture2D


func _ready() -> void:
	_heart_full = PixelIcons.heart(true)
	_heart_empty = PixelIcons.heart(false)
	_bonus.pivot_offset = _bonus.size * 0.5

	GameState.hearts_changed.connect(_on_hearts_changed)
	GameState.progress_changed.connect(_on_progress_changed)
	GameState.bonus_heart_won.connect(_on_bonus_heart_won)

	_on_hearts_changed(GameState.hearts)
	_on_progress_changed(GameState.current_tier, GameState.maze_in_tier)


## Update the countdown display (seconds remaining).
func set_time(seconds: float) -> void:
	seconds = maxf(seconds, 0.0)
	_timer.text = "%0.1f" % seconds
	_timer.color = Color("#ef476f") if seconds <= 5.0 else Color.WHITE


func _on_hearts_changed(hearts: int) -> void:
	for i in _hearts.size():
		_hearts[i].texture = _heart_full if i < hearts else _heart_empty


func _on_progress_changed(tier: int, maze_in_tier: int) -> void:
	_progress.text = "TIER %d  MAZE %d/%d" % [tier, maze_in_tier, GameState.MAZES_PER_TIER]


func _on_bonus_heart_won() -> void:
	_bonus.text = "+1 HEART!"
	_bonus.pivot_offset = _bonus.size * 0.5
	_bonus.modulate.a = 1.0
	_bonus.scale = Vector2.ONE
	var tween := create_tween()
	tween.tween_property(_bonus, "scale", Vector2(1.3, 1.3), 0.3)
	tween.tween_property(_bonus, "scale", Vector2.ONE, 0.2)
	tween.tween_property(_bonus, "modulate:a", 0.0, 1.4).set_delay(0.3)
