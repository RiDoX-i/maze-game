extends SceneTree

## Renders sample strings with PixelFont to a PNG to check legibility.
## Run: godot --headless --path . --script res://tools/render_font_preview.gd

const PF := preload("res://scripts/pixel_font.gd")

const S := 6
const PAD := 12
const LINE_GAP := 10


func _initialize() -> void:
	var lines := ["MAZE RUNNER", "TIER 12  MAZE 3/3", "0123456789  +-:/!", "GAME OVER  +1 HEART"]
	var max_chars := 0
	for l in lines:
		max_chars = maxi(max_chars, l.length())
	var line_w := max_chars * PF.advance() * S
	var line_h := PF.GH * S
	var img := Image.create(PAD * 2 + line_w, PAD * 2 + lines.size() * (line_h + LINE_GAP), false, Image.FORMAT_RGBA8)
	img.fill(Color("#12141f"))

	var y := PAD
	for l in lines:
		_draw_text(img, l, PAD, y)
		y += line_h + LINE_GAP

	var path := "res://assets/sprites/ui/_font_preview.png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/sprites/ui"))
	img.save_png(path)
	print("font preview saved: ", path, " (", img.get_width(), "x", img.get_height(), ")")
	quit(0)


func _draw_text(img: Image, text: String, ox: int, oy: int) -> void:
	var x := ox
	for i in text.length():
		var ch := text[i].to_upper()
		if not PF.GLYPHS.has(ch):
			ch = " "
		var rows: Array = PF.GLYPHS[ch]
		for ry in PF.GH:
			for rx in PF.GW:
				if rows[ry][rx] == "1":
					img.fill_rect(Rect2i(x + rx * S, oy + ry * S, S, S), Color("#ffe9a8"))
		x += PF.advance() * S
