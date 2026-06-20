extends SceneTree

## Generates the procedural theme tiles and writes them to disk:
##   - assets/sprites/tiles/<theme>/floor.png + wall_0.png .. wall_N.png
##   - assets/sprites/tiles/_preview.png  (floor + scattered walls per theme)
##
## Run: godot --headless --path . --script res://tools/export_tiles.gd

const TF := preload("res://scripts/tile_forge.gd")
const MT := preload("res://scripts/maze_theme.gd")

const COLS := 6
const ROWS := 4
const GAP := 8


func _initialize() -> void:
	var ids: Array = MT.ids()
	var tile := TF.SIZE
	var block_w := COLS * tile
	var block_h := ROWS * tile

	var sheet_w := GAP + block_w + GAP + block_w + GAP
	var sheet_h := GAP + ids.size() * (block_h + GAP)
	var sheet := Image.create(sheet_w, sheet_h, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#0a0b12"))

	var y := GAP
	for id in ids:
		var imgs: Dictionary = TF.images(id)
		_save(id, imgs)
		_block(sheet, [imgs.floor], GAP, y)                 # floor (single tile)
		_block(sheet, imgs.walls, GAP + block_w + GAP, y)   # walls (scattered variants)
		print("exported theme: ", id, "  (", imgs.walls.size(), " wall variants)")
		y += block_h + GAP

	var preview := "res://assets/sprites/tiles/_preview.png"
	sheet.save_png(preview)
	print("preview saved: ", preview, " (", sheet_w, "x", sheet_h, ")")
	quit(0)


func _save(id: String, imgs: Dictionary) -> void:
	var dir := "res://assets/sprites/tiles/" + id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	imgs.floor.save_png(dir + "/floor.png")
	for v in imgs.walls.size():
		imgs.walls[v].save_png(dir + "/wall_%d.png" % v)
	# Remove the legacy single wall.png so the loader uses wall_*.png.
	var legacy := ProjectSettings.globalize_path(dir + "/wall.png")
	if FileAccess.file_exists(legacy):
		DirAccess.remove_absolute(legacy)


func _block(sheet: Image, tiles: Array, ox: int, oy: int) -> void:
	var ts := Vector2i(TF.SIZE, TF.SIZE)
	var count := tiles.size()
	for cx in COLS:
		for cy in ROWS:
			var idx: int = abs(cx * 31 + cy * 17) % count
			sheet.blit_rect(tiles[idx], Rect2i(Vector2i.ZERO, ts), Vector2i(ox + cx * ts.x, oy + cy * ts.y))
