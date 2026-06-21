extends Control

## Title screen. Opens the Classic campaign's level-select, or starts a fresh
## Endless / Trap run.

const GAME_SCENE := "res://scenes/game.tscn"
const RECORDS_SCENE := "res://scenes/world_records.tscn"
const LEVEL_SELECT_SCENE := "res://scenes/level_select.tscn"
const SPEED_SELECT_SCENE := "res://scenes/speed_select.tscn"
const CONTROLS_SCENE := "res://scenes/controls_select.tscn"


func _ready() -> void:
	PixelUI.apply(self)


func _on_records_pressed() -> void:
	get_tree().change_scene_to_file(RECORDS_SCENE)


func _on_speeds_pressed() -> void:
	get_tree().change_scene_to_file(SPEED_SELECT_SCENE)


func _on_controls_pressed() -> void:
	get_tree().change_scene_to_file(CONTROLS_SCENE)


## CLASSIC is the 1000-level campaign: pick up where you left off in level-select.
func _on_classic_pressed() -> void:
	get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)


## ENDLESS is the original tier-based, score-chasing mode.
func _on_endless_pressed() -> void:
	GameState.start_run(GameState.GameMode.ENDLESS)
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_trap_pressed() -> void:
	GameState.start_run(GameState.GameMode.TRAP)
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()
