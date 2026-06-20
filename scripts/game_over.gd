extends Control

## Shown after a full run reset (hearts hit 0). Reports how far the run got and
## offers a retry (a fresh run) or a trip back to the main menu.

const GAME_SCENE := "res://scenes/game.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"

@onready var _result_label: PixelLabel = $Reached


func _ready() -> void:
	_result_label.text = "YOU REACHED TIER %d" % GameState.last_tier_reached


func _on_retry_pressed() -> void:
	GameState.reset_run()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
