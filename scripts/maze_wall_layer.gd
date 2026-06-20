extends Node2D

## Draws only the wall tiles of a maze, as its own CanvasItem so an (optional)
## animated ShaderMaterial can be applied to the walls without affecting the
## floor. Several wall variants are scattered per-cell (deterministically) so
## the maze doesn't look like one tile stamped everywhere. Owned by MazeRenderer.

var _maze: MazeGenerator.MazeData
var _texs: Array = []   ## Array[Texture2D] wall variants.
var _tile: int = 32


func setup(maze: MazeGenerator.MazeData, texs: Array, tile: int) -> void:
	_maze = maze
	_texs = texs
	_tile = tile
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func _draw() -> void:
	if _maze == null or _texs.is_empty():
		return
	var count := _texs.size()
	for gx in _maze.grid_width:
		for gy in _maze.grid_height:
			if _maze.grid[gx][gy] == 1:
				var v: int = abs(gx * 31 + gy * 17) % count
				draw_texture_rect(_texs[v], Rect2(gx * _tile, gy * _tile, _tile, _tile), false)
