extends SceneTree

## Generates a pixel-art main-menu background: gradient sky, scattered stars,
## glowing horizon, and a maze-wall skyline along the bottom.
## Run: godot --headless --path . --script res://tools/render_menu_bg.gd

const W := 360
const H := 640


func _initialize() -> void:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240620

	var top := Color("#0b1024")
	var mid := Color("#1a1240")
	var bot := Color("#2a1b4a")
	for y in H:
		var t := float(y) / float(H)
		var col := top.lerp(mid, minf(t * 1.6, 1.0)) if t < 0.6 else mid.lerp(bot, (t - 0.6) / 0.4)
		for x in W:
			img.set_pixel(x, y, col)

	# Stars (upper area), 2x2 fat pixels.
	for _i in 90:
		var sx := rng.randi_range(0, W - 2)
		var sy := rng.randi_range(0, int(H * 0.55))
		var b := rng.randf_range(0.4, 1.0)
		img.fill_rect(Rect2i(sx, sy, 2, 2), Color(0.8, 0.85, 1.0, b))

	# Glowing horizon band.
	var horizon := int(H * 0.62)
	for x in W:
		img.set_pixel(x, horizon, Color("#6c5ce7"))
		img.set_pixel(x, horizon + 1, Color("#5a4fcf"))

	# Maze-wall skyline along the bottom (blocky, fading up).
	var cell := 16
	for gy in range(horizon + 4, H, cell):
		for gx in range(0, W, cell):
			# carve a pseudo-maze: keep ~55% as wall blocks
			if ((gx / cell) * 7 + (gy / cell) * 13 + ((gx / cell) % 3)) % 5 < 3:
				var shade := Color("#241a3e").lerp(Color("#3b2c63"), rng.randf())
				img.fill_rect(Rect2i(gx, gy, cell - 2, cell - 2), shade)
				img.fill_rect(Rect2i(gx, gy, cell - 2, 2), Color("#4a3a78"))  # lit top

	var path := "res://assets/sprites/ui/menu_bg.png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/sprites/ui"))
	img.save_png(path)
	print("menu bg saved: ", path, " (", W, "x", H, ")")
	quit(0)
