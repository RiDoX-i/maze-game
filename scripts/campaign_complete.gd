extends Control

## Victory screen. Shown when the TRAP campaign (20 levels) or the CLASSIC
## campaign (1000 levels) is fully cleared; the copy and the primary button adapt
## to whichever mode just finished.

const GAME_SCENE := "res://scenes/game.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const LEVEL_SELECT_SCENE := "res://scenes/level_select.tscn"

@onready var _title: PixelLabel = $Title
@onready var _message: PixelLabel = $Message
@onready var _replay_label: PixelLabel = $Buttons/ReplayButton/Label


func _ready() -> void:
	PixelUI.apply(self)
	if GameState.is_classic_mode():
		_title.text = "MAZE MASTER"
		_message.text = "ALL %d LEVELS CLEARED" % GameState.CAMPAIGN_TOTAL_LEVELS
		_replay_label.text = "LEVELS"   # nothing left to replay; back to the map


func _on_replay_pressed() -> void:
	if GameState.is_classic_mode():
		get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)
		return
	GameState.start_run(GameState.GameMode.TRAP)
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
