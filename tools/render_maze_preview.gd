extends SceneTree

## Composes full themed mazes to a PNG so the look + difficulty can be eyeballed
## without launching the GPU (headless can't capture the live viewport).
## Note: the animated glow (circuit/ember) only shows at runtime; here you see
## the static base texture.
##
## Run: godot --headless --path . --script res://tools/render_maze_preview.gd

const TF := preload("res://scripts/tile_forge.gd")
const MT := preload("res://scripts/maze_theme.gd")
const MG := preload("res://scripts/maze_generator.gd")
const GS := preload("res://scripts/game_state.gd")

const PREVIEW_CELLS := 12   ## Fixed maze size for all panels (equal-size grid).
const PAD := 14


func _initialize() -> void:
	# tier -> shows a distinct theme; the last one is a high tier to show dense
	# branching at the branchiness cap.
	var tiers := [1, 3, 4, 12]
	var gs = GS.new()

	var tile := TF.SIZE
	var grid := PREVIEW_CELLS * 2 + 1
	var panel := grid * tile
	var sheet_w := PAD + panel + PAD + panel + PAD
	var sheet_h := PAD + panel + PAD + panel + PAD
	var sheet := Image.create(sheet_w, sheet_h, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#05060a"))

	for i in tiers.size():
		var tier: int = tiers[i]
		gs.current_tier = tier
		var theme: Dictionary = MT.for_tier(tier)
		var maze = MG.generate(PREVIEW_CELLS, PREVIEW_CELLS, 1234 + tier, gs.get_branchiness())
		var panel_img := _render_maze(maze, theme.id)
		var ox := PAD + (i % 2) * (panel + PAD)
		var oy := PAD + (i / 2) * (panel + PAD)
		sheet.blit_rect(panel_img, Rect2i(Vector2i.ZERO, panel_img.get_size()), Vector2i(ox, oy))
		print("tier %d  theme=%-9s branch=%.2f junctions=%d dead_ends=%d solution=%d"
			% [tier, theme.id, gs.get_branchiness(), maze.junction_count, maze.dead_end_count, maze.solution_length])

	var path := "res://assets/sprites/tiles/_maze_preview.png"
	sheet.save_png(path)
	print("maze preview saved: ", path, " (", sheet_w, "x", sheet_h, ")")
	quit(0)


func _render_maze(maze, theme_id: String) -> Image:
	var imgs: Dictionary = TF.images(theme_id)
	var floor_tex: Image = imgs.floor
	var walls: Array = imgs.walls
	var tile := TF.SIZE
	var out := Image.create(maze.grid_width * tile, maze.grid_height * tile, false, Image.FORMAT_RGBA8)
	var ts := Vector2i(tile, tile)
	for gx in maze.grid_width:
		for gy in maze.grid_height:
			var src: Image = floor_tex
			if maze.grid[gx][gy] == 1:
				src = walls[abs(gx * 31 + gy * 17) % walls.size()]
			out.blit_rect(src, Rect2i(Vector2i.ZERO, ts), Vector2i(gx * tile, gy * tile))
	_mark(out, maze.cell_to_grid(maze.start), tile, Color("#57f3a0"))
	_mark(out, maze.cell_to_grid(maze.exit), tile, Color("#ffd166"))
	return out


func _mark(img: Image, g: Vector2i, tile: int, col: Color) -> void:
	# Solid dot in the centre of the cell tile.
	var cx := g.x * tile + tile / 2
	var cy := g.y * tile + tile / 2
	for dx in range(-6, 7):
		for dy in range(-6, 7):
			if dx * dx + dy * dy <= 36:
				img.set_pixel(cx + dx, cy + dy, col)
