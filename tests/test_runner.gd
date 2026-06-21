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
const Footsteps := preload("res://scripts/footstep_forge.gd")
const Themes := preload("res://scripts/maze_theme.gd")
const PreparedMaps := preload("res://scripts/prepared_trap_maps.gd")
const Traps := preload("res://scripts/trap_layer.gd")
const Campaign := preload("res://scripts/campaign_progress.gd")
const Props := preload("res://scripts/prop_forge.gd")
const Lights := preload("res://scripts/light_forge.gd")
const Slide := preload("res://scripts/slide_motion.gd")
const Progress := preload("res://scripts/player_progress.gd")
const Settings := preload("res://scripts/game_settings.gd")


func _initialize() -> void:
	print("== Maze Runner test suite ==")
	_test_maze_generator()
	_test_timer_manager()
	_test_game_state()
	_test_campaign()
	_test_traps()
	_test_footsteps()
	_test_art()
	_test_movement()
	_test_player_progress()
	_test_settings()
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
	# base = shortest_path / speed = 2750/275 = 10s. A flat +5s is added everywhere.
	# tier 1: X=3 -> 10 * (1 + 3/3) + 5 = 25.
	_check(is_equal_approx(TimerMgr.compute_time_limit(2750.0, 1, 275.0), 25.0), "tier 1 budget = 2x optimal + 5s")
	# very high tier: X -> 1 -> 10 * (1 + 1/3) + 5 = 18.333.
	_check(is_equal_approx(TimerMgr.compute_time_limit(2750.0, 100, 275.0), 40.0 / 3.0 + 5.0), "high tier -> ~1.33x optimal + 5s")
	# never below the optimal walk itself.
	_check(TimerMgr.compute_time_limit(2750.0, 100, 275.0) > 10.0, "limit always exceeds optimal walk")
	# the flat bonus is applied on top of the formula.
	_check(is_equal_approx(TimerMgr.compute_time_limit(2750.0, 1, 275.0)
		- TimerMgr.EXTRA_SECONDS, 20.0), "flat +5s bonus is included")

	# Buffer X: starts at 3, eases asymptotically toward 1 (never below).
	_check(is_equal_approx(TimerMgr.buffer_factor(1), 3.0), "X starts at 3")
	_check(TimerMgr.buffer_factor(1) > TimerMgr.buffer_factor(8), "X eases down with tier")
	_check(TimerMgr.buffer_factor(8) > TimerMgr.buffer_factor(20), "X keeps easing down")
	_check(TimerMgr.buffer_factor(50) > 1.0, "X approaches but never reaches its floor")
	_check(TimerMgr.buffer_factor(50) < 1.01, "X is essentially at its floor on deep tiers")

	# Same shortest path -> less time on a harder (higher) tier.
	_check(TimerMgr.compute_time_limit(2750.0, 1, 275.0) > TimerMgr.compute_time_limit(2750.0, 12, 275.0),
		"higher tier grants less time for the same path")

	var maze = MazeGen.generate(6, 6, 3)
	var via_maze: float = TimerMgr.compute_for_maze(maze, 2, 64.0, 275.0)
	var via_stats: float = TimerMgr.compute_time_limit(float(maze.solution_length) * 64.0, 2, 275.0)
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
	_eq(gs.difficulty_tier(), 1 + gs.DIFFICULTY_OFFSET, "difficulty tier = tier + offset")
	var d1: Vector2i = gs.get_maze_dimensions()
	var eff: int = mini(gs.difficulty_tier(), gs.MAX_SIZE_TIER)
	var expected_w: int = mini(gs.BASE_SIZE + (eff - 1) * gs.SIZE_INCREMENT, gs.MAX_SIZE)
	_eq(d1.x, expected_w, "tier 1 width reflects +2 difficulty")
	_eq(d1.y, int(round(expected_w * gs.PORTRAIT_RATIO)), "maze is a portrait rectangle")
	_check(d1.y > d1.x, "maze is taller than wide (fills the screen)")
	_check(is_equal_approx(gs.get_branchiness(),
		minf(gs.BASE_BRANCH + (gs.difficulty_tier() - 1) * gs.BRANCH_PER_TIER, gs.MAX_BRANCH)),
		"tier 1 branchiness reflects +2 difficulty")
	gs.current_tier = 50
	var d_cap: Vector2i = gs.get_maze_dimensions()
	_check(d_cap.x <= gs.MAX_SIZE, "width capped at high tier")
	_eq(d_cap.y, int(round(d_cap.x * gs.PORTRAIT_RATIO)), "height follows the portrait ratio")
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


# --- Classic campaign ------------------------------------------------------

func _test_campaign() -> void:
	print("\n[campaign]")

	# Progression: one playable level at a time; winning unlocks the next and
	# locks the one just cleared (it can never be replayed).
	Campaign.reset()
	_eq(Campaign.levels_completed(), 0, "fresh campaign has no completed levels")
	_eq(Campaign.current_level(), 1, "first playable level is 1")
	_check(Campaign.is_unlocked(1), "level 1 is unlocked")
	_check(not Campaign.is_unlocked(2), "level 2 is locked until reached")
	_check(not Campaign.is_completed(1), "level 1 not yet completed")

	var done: bool = Campaign.complete_level(1)
	_check(not done, "completing level 1 does not finish the campaign")
	_eq(Campaign.levels_completed(), 1, "win advances completion count")
	_eq(Campaign.current_level(), 2, "next playable level is 2")
	_check(Campaign.is_completed(1), "level 1 now counts as completed")
	_check(not Campaign.is_unlocked(1), "a completed level cannot be replayed")
	_check(Campaign.is_unlocked(2), "the next level is now unlocked")

	# Re-completing an old level or skipping ahead must not change progress.
	Campaign.complete_level(1)
	Campaign.complete_level(5)
	_eq(Campaign.levels_completed(), 1, "cannot replay or skip levels")

	# Finishing the final level completes the whole campaign.
	Campaign._completed = Campaign.TOTAL_LEVELS - 1
	var finished: bool = Campaign.complete_level(Campaign.TOTAL_LEVELS)
	_check(finished, "clearing the last level completes the campaign")
	_check(Campaign.is_campaign_complete(), "campaign reports complete")
	_eq(Campaign.current_level(), Campaign.TOTAL_LEVELS, "current level caps at the last")
	Campaign.reset()

	# Difficulty is a deterministic, monotonic function of the level number.
	var gs = GameStateScript.new()
	_eq(gs.campaign_dimensions(1).x, gs.BASE_SIZE, "level 1 width is the base size")
	_eq(gs.campaign_dimensions(gs.CAMPAIGN_TOTAL_LEVELS).x, gs.CAMPAIGN_MAX_WIDTH, "width reaches its cap")
	var d := gs.campaign_dimensions(500)
	_eq(d.y, int(round(d.x * gs.PORTRAIT_RATIO)), "campaign maze is a portrait rectangle")
	_check(d.y > d.x, "campaign maze is taller than wide")
	_check(is_equal_approx(gs.campaign_branchiness(1), gs.CAMPAIGN_MIN_BRANCH), "level 1 branchiness is the floor")
	_check(is_equal_approx(gs.campaign_branchiness(gs.CAMPAIGN_TOTAL_LEVELS), gs.CAMPAIGN_MAX_BRANCH), "branchiness reaches its cap")
	_eq(gs.campaign_timer_tier(1), 1, "level 1 timer tier is gentle")
	_eq(gs.campaign_timer_tier(gs.CAMPAIGN_TOTAL_LEVELS), gs.CAMPAIGN_MAX_TIMER_TIER, "timer tier tightens to its cap")

	var monotonic := true
	var prev_w := 0
	var prev_b := -1.0
	var prev_t := 0
	for lvl in range(1, gs.CAMPAIGN_TOTAL_LEVELS + 1, 7):
		if gs.campaign_dimensions(lvl).x < prev_w or gs.campaign_branchiness(lvl) < prev_b - 0.0001 \
				or gs.campaign_timer_tier(lvl) < prev_t:
			monotonic = false
			break
		prev_w = gs.campaign_dimensions(lvl).x
		prev_b = gs.campaign_branchiness(lvl)
		prev_t = gs.campaign_timer_tier(lvl)
	_check(monotonic, "difficulty never decreases as levels climb")

	# Chapters: 10 levels each, one art theme per chapter.
	_eq(gs.campaign_chapter(1), 0, "levels 1-10 are chapter 0")
	_eq(gs.campaign_chapter(10), 0, "level 10 is still chapter 0")
	_eq(gs.campaign_chapter(11), 1, "level 11 starts chapter 1")
	_eq(str(Themes.for_campaign_level(1)), str(Themes.for_campaign_level(10)), "a chapter's 10 levels share one theme")
	_check(str(Themes.for_campaign_level(10)) != str(Themes.for_campaign_level(11)), "the theme changes between chapters")

	# Mode selection + advance.
	gs.start_campaign(5)
	_check(gs.is_classic_mode() and not gs.is_endless_mode() and not gs.is_trap_mode(), "classic campaign mode selected")
	_eq(gs.campaign_level, 5, "start_campaign sets the level")
	_check(gs.campaign_advance(), "advance moves to the next level")
	_eq(gs.campaign_level, 6, "campaign_level incremented")
	gs.campaign_level = gs.CAMPAIGN_TOTAL_LEVELS
	_check(not gs.campaign_advance(), "cannot advance past the final level")
	_check(gs.is_final_campaign_level(), "final level is recognised")
	gs.free()


# --- Trap mode -------------------------------------------------------------

func _test_traps() -> void:
	print("\n[trap_mode]")
	var gs = GameStateScript.new()
	gs.start_run(GameStateScript.GameMode.TRAP, false)
	_check(gs.is_trap_mode(), "trap mode can be selected")
	_eq(gs.hearts, 3, "trap mode starts with three hearts")
	gs.current_tier = 2
	gs.maze_in_tier = 3
	gs.on_maze_lost(true)
	_eq(gs.maze_in_tier, 3, "trap hit retries the current maze progress")
	_eq(gs.hearts, 2, "trap hit removes one heart")
	gs.start_run(GameStateScript.GameMode.ENDLESS, false)
	_check(gs.is_endless_mode() and not gs.is_trap_mode(), "endless mode can be restored")
	gs.free()

	_eq(PreparedMaps.count(), 20, "campaign contains twenty levels")
	var expected_types := {
		"spike": true, "mine": true, "dart": true, "laser": true, "crusher": true,
		"saw": true, "teleport": true, "fire": true, "arrow": true, "boulder": true,
	}
	var seen_types := {}
	var seen_layouts := {}
	for map_index in PreparedMaps.count():
		var prepared := PreparedMaps.build(map_index)
		var rebuilt := PreparedMaps.build(map_index)
		var maze = prepared["maze"]
		var trap_definitions: Array[Dictionary] = prepared["traps"]
		_eq(prepared["id"], rebuilt["id"], "level %d identity is fixed" % map_index)
		_eq(str(maze.cells), str(rebuilt["maze"].cells), "level %d layout is deterministic" % map_index)
		_eq(trap_definitions, rebuilt["traps"], "level %d trap roster is deterministic" % map_index)
		_check(not seen_layouts.has(str(maze.cells)), "level %d has a unique layout" % map_index)
		seen_layouts[str(maze.cells)] = true
		_check(maze.width >= 24, "level %d is ~3x normal size" % map_index)
		_check(_fully_connected(maze), "level %d is fully connected" % map_index)
		_check(maze.solution_length > 0, "level %d has a reachable exit" % map_index)
		_check(trap_definitions.size() >= 20, "level %d is densely trapped" % map_index)
		# One trap per 5x5 block, and the mechanic changes every trap.
		var blocks := {}
		var rotates := true
		for ti in trap_definitions.size():
			var tcell: Vector2i = trap_definitions[ti]["cell"]
			var block := Vector2i(tcell.x / PreparedMaps.TRAP_BLOCK, tcell.y / PreparedMaps.TRAP_BLOCK)
			blocks[block] = true
			if ti > 0 and trap_definitions[ti]["type"] == trap_definitions[ti - 1]["type"]:
				rotates = false
		_eq(blocks.size(), trap_definitions.size(), "level %d places one trap per 5x5 block" % map_index)
		_check(rotates, "level %d uses a new trap type each trap" % map_index)
		var start_grid: Vector2i = maze.cell_to_grid(maze.start)
		var exit_grid: Vector2i = maze.cell_to_grid(maze.exit)
		for definition in trap_definitions:
			var cell: Vector2i = definition["cell"]
			seen_types[definition["type"]] = true
			_check(expected_types.has(definition["type"]), "level %d trap type is supported" % map_index)
			_check(maze.grid[cell.x][cell.y] == 0, "level %d trap is on floor" % map_index)
			_check(absi(cell.x - start_grid.x) + absi(cell.y - start_grid.y) >= 4,
				"level %d trap respects spawn safety" % map_index)
			_check(absi(cell.x - exit_grid.x) + absi(cell.y - exit_grid.y) >= 3,
				"level %d trap respects exit safety" % map_index)
			_eq(definition["level"], map_index + 1, "trap carries its level difficulty")
	_eq(seen_layouts.size(), PreparedMaps.count(), "all twenty layouts are unique")
	_eq(seen_types.size(), expected_types.size(), "campaign uses all ten trap mechanics")
	_check(not PreparedMaps.is_final_progress(7, 1), "level 19 is not campaign completion")
	_check(PreparedMaps.is_final_progress(7, 2), "level 20 completes the campaign")
	_eq(PreparedMaps.index_for_progress(7, 2), 19, "final progress selects level 20")

	var final_level := PreparedMaps.build(PreparedMaps.count() - 1)
	var layer = Traps.new()
	var dummy_player := Node2D.new()
	var final_maze = final_level["maze"]
	var final_traps: Array[Dictionary] = final_level["traps"]
	layer.setup(final_traps, 32, dummy_player, Vector2(48, 48), final_maze.grid)
	_check(layer.trap_type_count() >= 8, "final level combines many trap types")
	layer.free()
	dummy_player.free()


# --- Procedural footsteps --------------------------------------------------

func _test_footsteps() -> void:
	print("\n[footsteps]")
	var assigned := {}
	for theme in Themes.THEMES:
		var surface: String = theme.step
		_check(Footsteps.supports(surface), "%s uses a supported surface" % theme.id)
		assigned[surface] = true
	_eq(assigned.size(), Themes.THEMES.size(), "every visual theme has a distinct floor sound")

	for surface in Footsteps.surface_names():
		var bank := Footsteps.get_steps(surface)
		_eq(bank.size(), Footsteps.VARIANT_COUNT, "%s has a complete variation bank" % surface)
		_check(bank[0].data.size() > 0, "%s produces audible sample data" % surface)
		_check(bank[0].data != bank[1].data, "%s variants are not identical" % surface)
		_eq(bank[0].mix_rate, Footsteps.RATE, "%s uses the expected sample rate" % surface)


# --- Art: biomes, decorations, lighting ------------------------------------

func _test_art() -> void:
	print("\n[art]")

	# Twelve biomes; campaign chapters cycle through them.
	_eq(Themes.THEMES.size(), 12, "twelve art biomes")
	_eq(str(Themes.for_campaign_level(1)), str(Themes.THEMES[0]), "chapter 0 uses biome 0")
	_eq(str(Themes.for_campaign_level(61)), str(Themes.THEMES[6]), "chapter 6 uses biome 6")
	_eq(str(Themes.for_campaign_level(121)), str(Themes.THEMES[0]), "biomes cycle every 12 chapters")

	# Per-chapter accent: deterministic and varies between chapters.
	_eq(str(Themes.chapter_accent(3)), str(Themes.chapter_accent(3)), "accent is deterministic")
	_check(str(Themes.chapter_accent(0)) != str(Themes.chapter_accent(1)), "accent varies per chapter")

	# Ambient stays bright enough to keep the maze readable (never near-black).
	for theme in Themes.THEMES:
		var amb: Color = Themes.ambient_for(theme)
		var lum := (amb.r + amb.g + amb.b) / 3.0
		_check(lum > 0.4 and lum < 0.95, "%s ambient stays readable" % theme.id)

	# Every biome has a non-empty prop roster of valid, drawable props.
	var bad_prop := ""
	for theme in Themes.THEMES:
		var roster: Array = Props.roster_for(theme.id)
		if roster.is_empty():
			bad_prop = "%s has no props" % theme.id
			break
		for id in roster:
			if Props.rects(id, 0).is_empty():
				bad_prop = "%s prop '%s' draws nothing" % [theme.id, id]
				break
		if bad_prop != "":
			break
	_eq(bad_prop, "", "every biome has drawable props")

	# Prop rects are well-formed (positive sizes, sane bounds).
	var bad_rect := ""
	for id in Props.all_ids():
		for e in Props.rects(id, 0):
			if int(e[2]) <= 0 or int(e[3]) <= 0 or absi(int(e[0])) > 10 or e[1] < -16 or e[1] > 4:
				bad_rect = "%s has an out-of-bounds rect" % id
				break
		if bad_rect != "":
			break
	_eq(bad_rect, "", "prop rects are well-formed")

	# Light props are classified and animated props actually change frames.
	_check(Props.is_light("torch") and not Props.is_light("skeleton"), "light props are classified")
	_check(Props.light_color("torch") != Color.WHITE, "light props carry a colour")
	_check(str(Props.rects("torch", 0)) != str(Props.rects("torch", 1)), "animated props flicker between frames")

	# LightForge: a sized texture and a ready PointLight2D.
	var tex := Lights.radial()
	_eq(tex.get_width(), Lights.SIZE, "light texture is the expected size")
	var light = Lights.make_light(Color("#ffcc88"), 100.0, 1.0)
	_check(light is PointLight2D and light.texture != null, "make_light returns a textured PointLight2D")
	_check(not light.shadow_enabled, "prop lights cast no shadows (mobile perf)")
	light.free()


# --- Swipe / corridor-follow movement --------------------------------------

func _test_movement() -> void:
	print("\n[movement]")
	var maze = MazeGen.generate(8, 8, 42)

	var open := Slide.open_dirs(maze, maze.start)
	_check(open.size() >= 1, "start cell has at least one exit")

	var path := Slide.compute(maze, maze.start, open[0])
	_check(path.size() >= 1, "a swipe moves at least one cell")

	# The run stops at a real decision point: the exit, a dead-end, or a junction.
	var last: Vector2i = path[path.size() - 1]
	var last_deg := Slide.open_dirs(maze, last).size()
	_check(last == maze.exit or last_deg == 1 or last_deg >= 3, "slide stops at exit / dead-end / junction")

	# Everything it flowed through (before the stop) was a plain 2-way corridor.
	var mids_are_corridors := true
	for i in range(0, path.size() - 1):
		if Slide.open_dirs(maze, path[i]).size() != 2:
			mids_are_corridors = false
			break
	_check(mids_are_corridors, "slide auto-follows only through 2-way corridors (incl. bends)")

	# A swipe straight into a wall does nothing. (0,0) has walls to the N and W.)
	var walled := Vector2i.ZERO
	for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		if not (d in open):
			walled = d
			break
	_check(walled != Vector2i.ZERO, "a walled direction exists at the corner start")
	_check(Slide.compute(maze, maze.start, walled).is_empty(), "swiping into a wall yields no movement")

	# Deterministic for a fixed maze + direction.
	_eq(str(Slide.compute(maze, maze.start, open[0])), str(path), "slide path is deterministic")

	# The junctions the nav guide will dot match the maze's own metric.
	var junctions := 0
	for cy in maze.height:
		for cx in maze.width:
			if Slide.open_dirs(maze, Vector2i(cx, cy)).size() >= 3:
				junctions += 1
	_eq(junctions, maze.junction_count, "open_dirs junction count matches maze metrics")


# --- Speed / XP progression ------------------------------------------------

func _test_player_progress() -> void:
	print("\n[player_progress]")
	Progress.reset()
	_eq(Progress.total_xp(), 0, "fresh progress has 0 XP")
	_eq(Progress.xp_for_win(1), 10, "tier 1 win = 10 XP")
	_eq(Progress.xp_for_win(2), 15, "tier 2 win = 15 XP")
	_eq(Progress.xp_for_win(5), 30, "tier 5 win = 30 XP")

	_eq(Progress.SPEEDS.size(), 5, "five speed tiers")
	var ascending := true
	var prev_speed := -1.0
	var prev_xp := -1
	for s in Progress.SPEEDS:
		if float(s["speed"]) <= prev_speed or int(s["unlock_xp"]) < prev_xp:
			ascending = false
			break
		prev_speed = float(s["speed"])
		prev_xp = int(s["unlock_xp"])
	_check(ascending, "speeds rise in speed and unlock cost")

	_check(Progress.is_unlocked(0), "first speed is always unlocked")
	_check(not Progress.is_unlocked(1), "second speed is locked at 0 XP")
	_eq(Progress.selected_index(), 0, "default selection is the first speed")
	_check(not Progress.select_speed(1), "cannot select a locked speed")

	var newly := Progress.add_xp(int(Progress.SPEEDS[1]["unlock_xp"]))
	_check(1 in newly, "crossing a threshold reports the new unlock")
	_check(Progress.is_unlocked(1), "second speed unlocks after enough XP")
	_check(Progress.select_speed(1), "an unlocked speed can be selected")
	_eq(Progress.selected_index(), 1, "selection is applied")
	_check(Progress.current_speed() == float(Progress.SPEEDS[1]["speed"]), "current speed matches selection")
	Progress.reset()


# --- Per-mode control settings ---------------------------------------------

func _test_settings() -> void:
	print("\n[settings]")
	Settings.reset()
	_eq(Settings.control_for("classic"), Settings.SWIPE, "classic defaults to swipe")
	_eq(Settings.control_for("endless"), Settings.SWIPE, "endless defaults to swipe")
	_eq(Settings.control_for("trap"), Settings.JOYSTICK, "trap defaults to joystick")
	_check(Settings.is_swipe("endless"), "is_swipe true for a swipe mode")

	Settings.set_control("trap", Settings.SWIPE)
	_eq(Settings.control_for("trap"), Settings.SWIPE, "a mode's control can be changed")
	Settings.set_control("classic", "nonsense")
	_eq(Settings.control_for("classic"), Settings.JOYSTICK, "unknown scheme normalises to joystick")

	Settings.reset()
	_eq(Settings.control_for("trap"), Settings.JOYSTICK, "reset restores defaults")
