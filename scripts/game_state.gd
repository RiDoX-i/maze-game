extends Node

## Authoritative run state + state machine for Maze Runner.
##
## Registered as the "GameState" autoload singleton so any scene can read the
## current hearts / tier / maze and react to the signals below. The transition
## logic mirrors section 3 of the project brief exactly.
##
## The script also owns difficulty scaling (it knows the current tier) and a
## seedable RNG so the bonus-heart roll and difficulty are deterministic in
## tests.

# --- Tuning constants ------------------------------------------------------

const MAX_HEARTS := 3
const MAZES_PER_TIER := 3
const BONUS_HEART_CHANCE := 20  ## Percent chance (roll 0-99 < this).

# Difficulty scaling.
#
# Size grows only modestly and caps early — bigger maps are NOT the difficulty
# lever. The real lever is "branchiness": how much the maze forks into extra
# junctions and dead-end branches (misleading routes) between you and the
# (farthest-placed) exit. See MazeGenerator for the Growing-Tree mix.
const BASE_SIZE := 9            ## Cells per side at tier 1.
const SIZE_INCREMENT := 1       ## Extra cells per side per tier (small).
const MAX_SIZE := 17            ## Cap so mazes stay phone-readable.
const MAX_SIZE_TIER := 9        ## Past this tier, size stops growing; only
                               ## branchiness keeps rising.

const BASE_BRANCH := 0.05       ## Almost pure backtracker at tier 1 (gentle).
const BRANCH_PER_TIER := 0.08   ## Added per tier -> more forks / dead ends.
const MAX_BRANCH := 0.75        ## Cap (kept below 1.0 to retain some long routes).

# --- Signals ---------------------------------------------------------------

signal hearts_changed(hearts: int)
signal progress_changed(tier: int, maze_in_tier: int)
signal bonus_heart_won()                 ## The rare 20% +1 heart roll succeeded.
signal game_over(tier_reached: int)      ## Hearts hit 0; a full reset happened.

# --- State -----------------------------------------------------------------

var hearts: int = MAX_HEARTS
var current_tier: int = 1
var maze_in_tier: int = 1
var tier_clean_run: bool = true          ## No death since this tier began.
var last_tier_reached: int = 1           ## Tier reached before the last reset.

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_register_input_actions()


## Reset everything to a brand-new run. Emits the relevant change signals.
func reset_run(emit: bool = true) -> void:
	hearts = MAX_HEARTS
	current_tier = 1
	maze_in_tier = 1
	tier_clean_run = true
	if emit:
		hearts_changed.emit(hearts)
		progress_changed.emit(current_tier, maze_in_tier)


## Player reached the exit in time.
func on_maze_won() -> void:
	if maze_in_tier < MAZES_PER_TIER:
		maze_in_tier += 1
	else:
		# Tier cleared (maze 3 done) -> advance tier.
		current_tier += 1
		maze_in_tier = 1
		if tier_clean_run:
			# Zero deaths this tier: roll the rare bonus-heart chance.
			if _rng.randi_range(0, 99) < BONUS_HEART_CHANCE and hearts < MAX_HEARTS:
				hearts += 1
				hearts_changed.emit(hearts)
				bonus_heart_won.emit()
		tier_clean_run = true
	progress_changed.emit(current_tier, maze_in_tier)


## Timer ran out before the player escaped.
## Returns true if this loss ended the run (full reset to tier 1).
func on_maze_lost() -> bool:
	hearts -= 1
	tier_clean_run = false
	hearts_changed.emit(hearts)
	if hearts <= 0:
		last_tier_reached = current_tier
		reset_run(false)
		hearts_changed.emit(hearts)
		progress_changed.emit(current_tier, maze_in_tier)
		game_over.emit(last_tier_reached)
		return true
	# Survived: retry the tier from its first maze, keep tier progress.
	maze_in_tier = 1
	progress_changed.emit(current_tier, maze_in_tier)
	return false


## Maze dimensions (in cells) for the current tier, with the size cap applied.
func get_maze_dimensions() -> Vector2i:
	var effective_tier: int = mini(current_tier, MAX_SIZE_TIER)
	var size: int = mini(BASE_SIZE + (effective_tier - 1) * SIZE_INCREMENT, MAX_SIZE)
	return Vector2i(size, size)


## Forking bias (0..1) for the current tier — the primary difficulty lever.
## Keeps rising even after maze dimensions stop growing.
func get_branchiness() -> float:
	return minf(BASE_BRANCH + (current_tier - 1) * BRANCH_PER_TIER, MAX_BRANCH)


## Set the RNG seed (used by tests for deterministic bonus-heart rolls).
func set_seed(value: int) -> void:
	_rng.seed = value


func _register_input_actions() -> void:
	# Register movement actions at runtime so we don't depend on hand-authored
	# InputEventKey blocks in project.godot. Arrow keys + WASD for desktop dev;
	# the virtual joystick drives movement on mobile.
	var actions := {
		"move_left": [KEY_LEFT, KEY_A],
		"move_right": [KEY_RIGHT, KEY_D],
		"move_up": [KEY_UP, KEY_W],
		"move_down": [KEY_DOWN, KEY_S],
	}
	for action_name in actions:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		for keycode in actions[action_name]:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			InputMap.action_add_event(action_name, ev)
