class_name SlideMotion
extends RefCounted

## Pure, engine-decoupled corridor-follow movement for swipe controls.
##
## Given the maze graph, a starting cell and a cardinal direction, returns the
## ordered list of cells the character runs through: it steps in [param dir] and
## then AUTO-FOLLOWS the corridor (turning at bends) until it reaches a real
## decision point — a junction (2+ onward exits), a dead-end, or the exit. So a
## single swipe flows the runner all the way down a winding corridor and only
## stops where a choice actually exists. Has no scene deps -> unit testable.

const _DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


## The run path (excluding [param from]); empty if the first step is walled.
static func compute(maze, from: Vector2i, dir: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if maze == null or _bit(dir) == 0:
		return path
	var cur := from
	var d := dir
	var guard := 0
	var cap: int = maze.width * maze.height + 4
	while guard < cap:
		guard += 1
		if (int(maze.cells[cur.x][cur.y]) & _bit(d)) != 0:
			break                              # wall ahead -> stop here
		cur += d
		path.append(cur)
		if cur == maze.exit:
			break                              # always stop on the exit
		var exits := _open_dirs(maze, cur)
		exits.erase(-d)                        # never reverse back the way we came
		if exits.size() == 1:
			d = exits[0]                       # plain corridor / bend -> keep flowing
		else:
			break                              # junction (>=2) or dead-end (0) -> stop
	return path


## Cardinal directions with no wall out of [param cell].
static func open_dirs(maze, cell: Vector2i) -> Array[Vector2i]:
	return _open_dirs(maze, cell)


# --- Internals -------------------------------------------------------------

static func _open_dirs(maze, cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var mask := int(maze.cells[cell.x][cell.y])
	if (mask & MazeGenerator.WALL_N) == 0: out.append(Vector2i(0, -1))
	if (mask & MazeGenerator.WALL_E) == 0: out.append(Vector2i(1, 0))
	if (mask & MazeGenerator.WALL_S) == 0: out.append(Vector2i(0, 1))
	if (mask & MazeGenerator.WALL_W) == 0: out.append(Vector2i(-1, 0))
	return out


static func _bit(dir: Vector2i) -> int:
	if dir == Vector2i(0, -1): return MazeGenerator.WALL_N
	if dir == Vector2i(1, 0): return MazeGenerator.WALL_E
	if dir == Vector2i(0, 1): return MazeGenerator.WALL_S
	if dir == Vector2i(-1, 0): return MazeGenerator.WALL_W
	return 0
