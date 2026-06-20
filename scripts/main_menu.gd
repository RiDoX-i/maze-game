extends Control

## Title screen. Starts a fresh run and loads the game scene.

const GAME_SCENE := "res://scenes/game.tscn"


func _on_play_pressed() -> void:
	GameState.reset_run()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()
