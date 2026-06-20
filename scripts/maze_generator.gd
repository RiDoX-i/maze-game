class_name MazeGenerator
extends RefCounted

## Pure, engine-decoupled maze generation (recursive backtracker / DFS).
##
## This script has NO dependency on scene nodes so it can be unit tested
## independently of the Godot editor / running scene tree.
##
## Difficulty comes from COMPLEXITY, not size. We use the Growing-Tree
## algorithm with a "branchiness" knob (0..1):
##   * branchiness 0  -> always extend the newest frontier cell == recursive
##     backtracker: few, long, winding corridors (gentle).
##   * branchiness high -> often extend a RANDOM frontier cell == Prim's-like:
##     many junctions and dead ends, i.e. lots of misleading routes that fork
##     off and lead nowhere (hard).
## The exit is then placed at the cell FARTHEST from the start (longest path),
## so the correct route is long and surrounded by tempting wrong turns.
## The maze stays "perfect" (exactly one path between any two cells) — no loops,
## because loops would add shortcuts and make it easier.

# Wall bit flags stored per cell. A set bit means that wall is still present.
const WALL_N := 1
const WALL_E := 2
const WALL_S := 4
const WALL_W := 8
const ALL_WALLS := WALL_N | WALL_E | WALL_S | WALL_W

const _DIRS := {
	WALL_N: Vector2i(0, -1),
	WALL_E: Vector2i(1, 0),
	WALL_S: Vector2i(0, 1),
	WALL_W: Vector2i(-1, 0),
}
const _OPPOSITE := {
	WALL_N: WALL_S,
	WALL_E: WALL_W,
	WALL_S: WALL_N,
	WALL_W: WALL_E,
}


## Plain data container for a generated maze. RefCounted -> no scene deps.
class MazeData:
	extends RefCounted

	var width: int                ## Maze width in cells.
	var height: int               ## Maze height in cells.
	var cells: Array              ## [width][height] of wall bitmasks.
	var grid: Array               ## [2w+1][2h+1] of ints: 1 = wall, 0 = floor.
	var grid_width: int           ## == 2 * width + 1
	var grid_height: int          ## == 2 * height + 1
	var start: Vector2i           ## Start cell (cell coords).
	var exit: Vector2i            ## Exit cell — farthest reachable cell from start.
	var cell_count: int           ## width * height.
	var dead_end_count: int       ## Cells with exactly one open side (degree 1).
	var junction_count: int       ## Cells with three or more open sides (forks).
	var solution_length: int      ## Steps along the (unique) start -> exit path.
	var explore_length: int       ## Steps a blind wall-follower takes start -> exit
	                              ## (a realistic "time to solve" measure: grows
	                              ## with misleading branches).
	var seed_used: int            ## Seed actually used (for reproducibility).

	## Cell coords -> the floor tile index in the expanded grid.
	func cell_to_grid(cell: Vector2i) -> Vector2i:
		return Vector2i(cell.x * 2 + 1, cell.y * 2 + 1)

	## Is the given expanded-grid tile a wall? Out-of-bounds counts as wall.
	func is_wall(gx: int, gy: int) -> bool:
		if gx < 0 or gy < 0 or gx >= grid_width or gy >= grid_height:
			return true
		return grid[gx][gy] == 1


## Generate a maze. [param seed_value] < 0 means a random seed. [param branchiness]
## (0..1) is the Growing-Tree mix: 0 = recursive backtracker (few long corridors),
## higher = more random frontier picks (more junctions and misleading dead ends).
static func generate(width: int, height: int, seed_value: int = -1, branchiness: float = 0.0) -> MazeData:
	width = maxi(width, 2)
	height = maxi(height, 2)
	branchiness = clampf(branchiness, 0.0, 1.0)

	var rng := RandomNumberGenerator.new()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
		seed_value = int(rng.seed)

	# Every cell starts fully walled.
	var cells: Array = []
	var visited: Array = []
	for x in width:
		var wall_col: Array = []
		var vis_col: Array = []
		for y in height:
			wall_col.append(ALL_WALLS)
			vis_col.append(false)
		cells.append(wall_col)
		visited.append(vis_col)

	# Growing-Tree carving. `active` holds frontier cells; which one we extend
	# each step decides the maze's character (see header).
	var active: Array[Vector2i] = []
	var start := Vector2i.ZERO
	visited[0][0] = true
	active.append(start)

	while not active.is_empty():
		# Mostly extend the newest cell (backtracker behaviour); with probability
		# `branchiness` extend a random frontier cell instead, which forks the
		# maze and multiplies dead ends / junctions.
		var idx := active.size() - 1
		if branchiness > 0.0 and rng.randf() < branchiness:
			idx = rng.randi() % active.size()
		var current: Vector2i = active[idx]

		var options := _unvisited_neighbours(current, width, height, visited)
		if options.is_empty():
			active.remove_at(idx)
			continue
		var pick: Dictionary = options[rng.randi() % options.size()]
		var dir: int = pick.dir
		var nxt: Vector2i = pick.cell
		cells[current.x][current.y] &= ~dir
		cells[nxt.x][nxt.y] &= ~int(_OPPOSITE[dir])
		visited[nxt.x][nxt.y] = true
		active.append(nxt)

	var data := MazeData.new()
	data.width = width
	data.height = height
	data.cells = cells
	data.start = Vector2i.ZERO
	data.cell_count = width * height
	data.seed_used = seed_value
	_compute_metrics(data)   # sets exit, solution_length, dead_end_count, junction_count
	_build_expanded_grid(data)
	return data


# --- Internals -------------------------------------------------------------

static func _unvisited_neighbours(cell: Vector2i, width: int, height: int, visited: Array) -> Array:
	var result: Array = []
	for dir in _DIRS:
		var n: Vector2i = cell + _DIRS[dir]
		if n.x < 0 or n.y < 0 or n.x >= width or n.y >= height:
			continue
		if visited[n.x][n.y]:
			continue
		result.append({"dir": dir, "cell": n})
	return result


static func _compute_metrics(data: MazeData) -> void:
	var width := data.width
	var height := data.height
	var cells := data.cells

	# Degree (open sides) per cell -> dead ends and junctions.
	var dead_ends := 0
	var junctions := 0
	for x in width:
		for y in height:
			var open := 0
			for bit in [WALL_N, WALL_E, WALL_S, WALL_W]:
				if (cells[x][y] & bit) == 0:
					open += 1
			if open == 1:
				dead_ends += 1
			elif open >= 3:
				junctions += 1
	data.dead_end_count = dead_ends
	data.junction_count = junctions

	# BFS from start over passages -> farthest cell becomes the exit.
	var dist: Array = []
	for x in width:
		var col: Array = []
		col.resize(height)
		col.fill(-1)
		dist.append(col)

	var queue: Array[Vector2i] = [data.start]
	dist[data.start.x][data.start.y] = 0
	var farthest := data.start
	var max_dist := 0
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for dir in _DIRS:
			if (cells[cur.x][cur.y] & dir) != 0:
				continue  # wall -> no passage this way
			var n: Vector2i = cur + _DIRS[dir]
			if n.x < 0 or n.y < 0 or n.x >= width or n.y >= height:
				continue
			if dist[n.x][n.y] != -1:
				continue
			dist[n.x][n.y] = dist[cur.x][cur.y] + 1
			if dist[n.x][n.y] > max_dist:
				max_dist = dist[n.x][n.y]
				farthest = n
			queue.append(n)

	data.exit = farthest
	data.solution_length = max_dist
	data.explore_length = _wall_follow_steps(data)


## Right-hand wall-follower step count from start to exit. Always solves a
## perfect maze, and wanders more when there are more misleading branches, so it
## is a good realistic "effort to solve" measure.
static func _wall_follow_steps(data: MazeData) -> int:
	var order := [WALL_N, WALL_E, WALL_S, WALL_W]  # clockwise
	var pos: Vector2i = data.start
	var facing := 1  # index into `order` (E)
	var steps := 0
	var cap: int = data.cell_count * 8
	while pos != data.exit and steps < cap:
		for off in [1, 0, 3, 2]:  # right, straight, left, back (relative)
			var idx: int = (facing + int(off)) % 4
			var bit: int = order[idx]
			if (data.cells[pos.x][pos.y] & bit) == 0:
				facing = idx
				pos += _DIRS[bit]
				steps += 1
				break
	return steps


static func _build_expanded_grid(data: MazeData) -> void:
	# Expanded grid: each cell becomes a floor tile surrounded by wall tiles.
	# Index (2x+1, 2y+1) is a cell centre; even rows/cols are wall lanes.
	var gw := data.width * 2 + 1
	var gh := data.height * 2 + 1
	var grid: Array = []
	for gx in gw:
		var col: Array = []
		col.resize(gh)
		col.fill(1)  # start solid, carve floors below
		grid.append(col)

	for x in data.width:
		for y in data.height:
			var cx := x * 2 + 1
			var cy := y * 2 + 1
			grid[cx][cy] = 0  # cell floor
			var mask: int = data.cells[x][y]
			if (mask & WALL_N) == 0:
				grid[cx][cy - 1] = 0
			if (mask & WALL_S) == 0:
				grid[cx][cy + 1] = 0
			if (mask & WALL_E) == 0:
				grid[cx + 1][cy] = 0
			if (mask & WALL_W) == 0:
				grid[cx - 1][cy] = 0

	data.grid = grid
	data.grid_width = gw
	data.grid_height = gh
