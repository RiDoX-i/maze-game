extends SceneTree

## Standalone, editor-independent unit tests for the pure-logic scripts.
##
## Run headless:
##   godot --headless --path <project> --script res://tests/test_runner.gd
##
## Scripts are loaded with load() (not their class_name globals) and GameState is
## instantiated directly, so the suite does not depend on the autoload or scene
## tree being set up.

var _passed := 0
var _failed := 0

const MazeGen := preload("res://scripts/maze_generator.gd")
const TimerMgr := preload("res://scripts/timer_manager.gd")
const GameStateScript := preload("res://scripts/game_state.gd")


func _initialize() -> void:
	print("== Maze Runner test suite ==")
	_test_maze_generator()
	_test_timer_manager()
	_test_game_state()
	print("\n== Results: %d passed, %d failed ==" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# --- Assertions ------------------------------------------------------------

func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		print("  FAIL  ", label)


func _eq(a, b, label: String) -> void:
	_check(a == b, "%s (got %s, expected %s)" % [label, str(a), str(b)])


# --- Maze generator --------------------------------------------------------

func _test_maze_generator() -> void:
	print("\n[maze_generator]")
	var maze = MazeGen.generate(8, 8, 42)

	_eq(maze.width, 8, "width")
	_eq(maze.height, 8, "height")
	_eq(maze.grid_width, 17, "grid_width == 2w+1")
	_eq(maze.grid_height, 17, "grid_height == 2h+1")
	_eq(maze.cell_count, 64, "cell_count")
	_eq(maze.start, Vector2i(0, 0), "start cell")
	_check(maze.dead_end_count > 0 and maze.dead_end_count < maze.cell_count, "dead_end_count in sane range")
	_check(maze.junction_count >= 0, "junction_count present")
	_check(maze.explore_length >= maze.solution_length, "blind solve >= shortest path")
	_check(maze.explore_length > 0, "explore_length computed")

	# Determinism: same seed -> identical grid.
	var maze_b = MazeGen.generate(8, 8, 42)
	_eq(str(maze.grid), str(maze_b.grid), "deterministic for fixed seed")

	# Different seeds usually differ.
	var maze_c = MazeGen.generate(8, 8, 99)
	_check(str(maze.grid) != str(maze_c.grid), "different seed -> different grid")

	# Perfect maze: every floor tile reachable from the start, exit included.
	_check(_fully_connected(maze), "perfect maze is fully connected")

	# Exit must be the cell FARTHEST from the start (longest path in the maze).
	var farthest := _max_path(maze)
	_check(maze.exit != maze.start, "exit is not the start")
	_eq(maze.solution_length, farthest.max_dist, "solution_length == longest path length")
	_eq(farthest.exit_dist, farthest.max_dist, "exit is the farthest reachable cell")

	# Difficulty lever: more branchiness => more misleading routes (junctions +
	# dead-end branches) for the same map size.
	var seeds := range(0, 20)
	var low := _avg_complexity(11, 0.05, seeds)
	var high := _avg_complexity(11, 0.75, seeds)
	print("  info  avg (junctions+dead_ends)  branch=0.05: %.1f  branch=0.75: %.1f" % [low, high])
	_check(high > low, "higher branchiness yields more misleading routes")

	# A heavily-branched maze must still be solvable (it stays a perfect maze).
	var branched = MazeGen.generate(12, 12, 7, 0.9)
	_check(_fully_connected(branched), "branched maze still fully connected")


func _fully_connected(maze) -> bool:
	# BFS over floor tiles in the expanded grid; compare reached vs total floors.
	var total_floor := 0
	for x in maze.grid_width:
		for y in maze.grid_height:
			if maze.grid[x][y] == 0:
				total_floor += 1

	var start_g: Vector2i = maze.cell_to_grid(maze.start)
	var visited := {}
	var queue: Array[Vector2i] = [start_g]
	visited[start_g] = true
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d in dirs:
			var n: Vector2i = cur + d
			if maze.is_wall(n.x, n.y):
				continue
			if visited.has(n):
				continue
			visited[n] = true
			queue.append(n)

	var exit_g: Vector2i = maze.cell_to_grid(maze.exit)
	return visited.size() == total_floor and visited.has(exit_g)


## BFS over the cell graph from start; returns the longest distance and the
## distance to the maze's chosen exit.
func _max_path(maze) -> Dictionary:
	var dirs := {1: Vector2i(0, -1), 2: Vector2i(1, 0), 4: Vector2i(0, 1), 8: Vector2i(-1, 0)}
	var dist := {}
	var queue: Array[Vector2i] = [maze.start]
	dist[maze.start] = 0
	var max_dist := 0
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for bit in dirs:
			if (maze.cells[cur.x][cur.y] & bit) != 0:
				continue
			var n: Vector2i = cur + dirs[bit]
			if n.x < 0 or n.y < 0 or n.x >= maze.width or n.y >= maze.height:
				continue
			if dist.has(n):
				continue
			dist[n] = dist[cur] + 1
			max_dist = maxi(max_dist, dist[n])
			queue.append(n)
	return {"max_dist": max_dist, "exit_dist": int(dist.get(maze.exit, -1))}


## Average number of misleading decision points (junctions + dead ends) over
## several seeds at a given branchiness.
func _avg_complexity(size: int, branch: float, seeds: Array) -> float:
	var total := 0
	for s in seeds:
		var m = MazeGen.generate(size, size, s, branch)
		total += m.junction_count + m.dead_end_count
	return float(total) / float(seeds.size())


# --- Timer manager ---------------------------------------------------------

func _test_timer_manager() -> void:
	print("\n[timer_manager]")
	# optimal=2750/275=10s, blind=8250/275=30s.
	# tier 1: g=0.55 -> 10 + 0.55*20 = 21
	_check(is_equal_approx(TimerMgr.compute_time_limit(2750.0, 8250.0, 1, 275.0), 21.0), "tier 1 budget")
	# high tier: g floored at 0.35 -> 10 + 0.35*20 = 17
	_check(is_equal_approx(TimerMgr.compute_time_limit(2750.0, 8250.0, 100, 275.0), 17.0), "g floored at high tier")
	_check(is_equal_approx(TimerMgr.generosity(1), 0.55), "generosity starts at 0.55")
	_check(is_equal_approx(TimerMgr.generosity(100), 0.35), "generosity floors at 0.35")
	_check(TimerMgr.generosity(1) > TimerMgr.generosity(20), "generosity eases down with tier")

	# THE FIX: a harder maze (longer blind solve, same shortest path) must get
	# MORE time, not less.
	var easy := TimerMgr.compute_time_limit(2750.0, 6000.0, 5, 275.0)
	var hard := TimerMgr.compute_time_limit(2750.0, 18000.0, 5, 275.0)
	_check(hard > easy, "harder maze (more exploration) gets more time")

	var maze = MazeGen.generate(6, 6, 3)
	var via_maze: float = TimerMgr.compute_for_maze(maze, 2, 64.0, 275.0)
	var via_stats: float = TimerMgr.compute_time_limit(
		float(maze.solution_length) * 64.0, float(maze.explore_length) * 64.0, 2, 275.0)
	_check(is_equal_approx(via_maze, via_stats), "compute_for_maze matches compute_time_limit")


# --- Game state ------------------------------------------------------------

func _test_game_state() -> void:
	print("\n[game_state]")
	var gs = GameStateScript.new()
	gs.reset_run(false)
	_eq(gs.hearts, 3, "fresh run hearts")
	_eq(gs.current_tier, 1, "fresh run tier")
	_eq(gs.maze_in_tier, 1, "fresh run maze")

	# Win two mazes -> still tier 1, maze 3.
	gs.on_maze_won()
	gs.on_maze_won()
	_eq(gs.maze_in_tier, 3, "maze advances within tier")
	_eq(gs.current_tier, 1, "tier unchanged mid-tier")

	# Win the third -> tier 2, maze 1.
	gs.on_maze_won()
	_eq(gs.current_tier, 2, "tier advances after maze 3")
	_eq(gs.maze_in_tier, 1, "maze resets on new tier")

	# Losing a heart resets the in-tier streak but keeps the tier.
	var run_over: bool = gs.on_maze_lost()
	_eq(run_over, false, "single loss does not end run")
	_eq(gs.hearts, 2, "loss costs a heart")
	_eq(gs.maze_in_tier, 1, "loss retries tier from maze 1")
	_eq(gs.current_tier, 2, "loss keeps tier progress")
	_eq(gs.tier_clean_run, false, "loss marks tier as not clean")

	# A non-clean tier clear must NOT roll the bonus heart.
	gs.on_maze_won()
	gs.on_maze_won()
	gs.on_maze_won()
	_eq(gs.hearts, 2, "no bonus heart after a non-clean tier")

	# Drain hearts to zero -> full reset, run over, last tier recorded.
	gs.hearts = 1
	gs.current_tier = 5
	var over: bool = gs.on_maze_lost()
	_eq(over, true, "losing last heart ends the run")
	_eq(gs.hearts, 3, "full reset restores hearts")
	_eq(gs.current_tier, 1, "full reset returns to tier 1")
	_eq(gs.last_tier_reached, 5, "records tier reached before reset")

	# Difficulty scaling: small size growth, twistiness as the main lever.
	gs.reset_run(false)
	var d1: Vector2i = gs.get_maze_dimensions()
	_eq(d1, Vector2i(gs.BASE_SIZE, gs.BASE_SIZE), "tier 1 dimensions == base")
	_check(is_equal_approx(gs.get_branchiness(), gs.BASE_BRANCH), "tier 1 branchiness == base")
	gs.current_tier = 50
	var d_cap: Vector2i = gs.get_maze_dimensions()
	_check(d_cap.x <= gs.MAX_SIZE and d_cap.y <= gs.MAX_SIZE, "dimensions capped at high tier")
	_check(is_equal_approx(gs.get_branchiness(), gs.MAX_BRANCH), "branchiness caps at MAX_BRANCH")
	gs.current_tier = 3
	_check(gs.get_branchiness() > gs.BASE_BRANCH, "branchiness rises with tier")

	# The bonus-heart path is reachable: with a clean tier clear and hearts < max,
	# at least one seed produces a successful 20% roll (proves the +1 logic works).
	var bonus_seen := false
	for s in range(0, 300):
		var g2 = GameStateScript.new()
		g2.reset_run(false)
		g2.set_seed(s)
		g2.hearts = 2
		g2.current_tier = 1
		g2.maze_in_tier = 3
		g2.tier_clean_run = true
		g2.on_maze_won()
		var won_bonus: bool = g2.hearts == 3
		g2.free()
		if won_bonus:
			bonus_seen = true
			break
	_check(bonus_seen, "bonus heart roll can succeed on a clean tier clear")

	gs.free()
