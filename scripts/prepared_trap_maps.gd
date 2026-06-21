class_name PreparedTrapMaps
extends RefCounted

## Fixed Trap Mode campaign. Each level is generated DETERMINISTICALLY from its
## index (a fixed seed), so every level looks and plays identically every time —
## a "prepared" map in practice — while letting the maps be far larger than the
## hand-baked originals. Trap Mode maps are ~3x the size of a normal Classic maze
## and use ten trap mechanics (including the pressure-plate arrow volley and the
## rolling boulder). Trap positions are deterministic too, and TrapLayer keeps
## them invisible until they spring, so the surprise survives any restart.

const MAPS_PER_TIER := 3
const LEVEL_COUNT := 20

# Big maps: ~3x a normal Classic maze (Classic base is 9 cells/side).
const BASE_SIZE := 25
const SIZE_STEP := 1
const MAX_SIZE := 33

const BASE_BRANCH := 0.45
const BRANCH_STEP := 0.018
const MAX_BRANCH := 0.85

# Every trap mechanic TrapLayer can run, cycled so each level mixes many and the
# campaign as a whole uses all of them.
const ALL_TYPES := [
	"spike", "mine", "dart", "laser", "crusher",
	"saw", "teleport", "fire", "arrow", "boulder",
]

## Trap density: the maze is split into TRAP_BLOCK x TRAP_BLOCK tile blocks and
## every block that has a usable floor cell gets exactly one trap, with the type
## rotating so each successive trap is a different mechanic.
const TRAP_BLOCK := 5

const NAMES := [
	"First Steps", "Hidden Teeth", "Arrow Alley", "Rolling Thunder", "Crossfire",
	"The Long Hall", "Saw Mill", "Phantom Floor", "Ember Maze", "Pitfall Run",
	"Dart Gauntlet", "Boulder Canyon", "Laser Grid", "No Safe Step", "Trapsmith",
	"Iron Labyrinth", "The Crush", "Inferno Path", "Zero Mercy", "Trap Master",
]


static func count() -> int:
	return LEVEL_COUNT


static func index_for_progress(tier: int, maze_in_tier: int) -> int:
	return _campaign_step(tier, maze_in_tier) % LEVEL_COUNT


static func is_final_progress(tier: int, maze_in_tier: int) -> bool:
	return _campaign_step(tier, maze_in_tier) == LEVEL_COUNT - 1


static func _campaign_step(tier: int, maze_in_tier: int) -> int:
	return (maxi(tier, 1) - 1) * MAPS_PER_TIER + maxi(maze_in_tier, 1) - 1


static func for_progress(tier: int, maze_in_tier: int) -> Dictionary:
	return build(index_for_progress(tier, maze_in_tier))


## Build a fixed level by index. Deterministic: same index -> identical maze and
## trap roster every call.
static func build(index: int) -> Dictionary:
	var i := posmod(index, LEVEL_COUNT)
	var seed_value := absi(hash("maze_trap_level_%d" % i)) % 2147483647
	var size := mini(BASE_SIZE + i * SIZE_STEP, MAX_SIZE)
	var branch := minf(BASE_BRANCH + i * BRANCH_STEP, MAX_BRANCH)
	var maze := MazeGenerator.generate(size, size, seed_value, branch)
	var traps := _place_traps(maze, i)
	return {
		"id": "level_%02d" % (i + 1),
		"name": NAMES[i % NAMES.size()],
		"maze": maze,
		"traps": traps,
		"index": i,
	}


# --- Internals -------------------------------------------------------------

## Place one trap in every 5x5 tile block that has a safe floor cell, rotating the
## trap type so each successive trap is a new mechanic. Deterministic: same level
## index -> identical roster.
static func _place_traps(maze: MazeGenerator.MazeData, level_index: int) -> Array[Dictionary]:
	var start_g := maze.cell_to_grid(maze.start)
	var exit_g := maze.cell_to_grid(maze.exit)
	var traps: Array[Dictionary] = []
	var type_counter := level_index   # phase per level so levels differ
	var by := 0
	while by < maze.grid_height:
		var bx := 0
		while bx < maze.grid_width:
			var cell := _pick_block_cell(maze, bx, by, start_g, exit_g)
			if cell.x >= 0:
				traps.append({
					"type": ALL_TYPES[type_counter % ALL_TYPES.size()],
					"cell": cell,
					"variant": (cell.x * 3 + cell.y + level_index) % 4,
					"level": level_index + 1,
				})
				type_counter += 1
			bx += TRAP_BLOCK
		by += TRAP_BLOCK
	return traps


## The safest, most deterministic floor cell inside one block, or (-1,-1) if the
## block has no floor cell clear of the spawn and exit.
static func _pick_block_cell(maze: MazeGenerator.MazeData, bx: int, by: int,
		start_g: Vector2i, exit_g: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_key := -1
	for gx in range(bx, mini(bx + TRAP_BLOCK, maze.grid_width)):
		for gy in range(by, mini(by + TRAP_BLOCK, maze.grid_height)):
			if maze.grid[gx][gy] != 0:
				continue
			if absi(gx - start_g.x) + absi(gy - start_g.y) < 4:
				continue
			if absi(gx - exit_g.x) + absi(gy - exit_g.y) < 3:
				continue
			var key := absi((gx * 73856093) ^ (gy * 19349663))
			if best_key < 0 or key < best_key:
				best_key = key
				best = Vector2i(gx, gy)
	return best
