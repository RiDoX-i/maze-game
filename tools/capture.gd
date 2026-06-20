extends Node

## Captures real rendered screenshots of scenes to PNGs (run NON-headless).
## godot --path . res://tools/capture.tscn
## Used only for visual verification; safe to delete.

var _shots := [
	{"scene": "res://scenes/main_menu.tscn", "out": "res://assets/sprites/ui/_shot_menu.png"},
	{"scene": "res://scenes/game.tscn", "out": "res://assets/sprites/ui/_shot_game.png"},
]


func _ready() -> void:
	await _run()
	get_tree().quit(0)


func _run() -> void:
	for s in _shots:
		var inst: Node = load(s.scene).instantiate()
		add_child(inst)
		# Let scripts run and a few frames render.
		for i in 12:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(s.out)
		print("captured: ", s.out)
		inst.queue_free()
		await get_tree().process_frame
