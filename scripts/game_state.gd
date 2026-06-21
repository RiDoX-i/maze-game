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

## CLASSIC is the new 1000-level campaign (validate a level to unlock the next;
## infinite same-difficulty retries, no hearts). ENDLESS is the original tier
## machine (3 mazes/tier, hearts, World Records). TRAP is the fixed campaign.
enum GameMode { CLASSIC, ENDLESS, TRAP }

# Difficulty scaling.
#
# Size grows only modestly and caps early — bigger maps are NOT the difficulty
# lever. The real lever is "branchiness": how much the maze forks into extra
# junctions and dead-end branches (misleading routes) between you and the
# (farthest-placed) exit. See MazeGenerator for the Growing-Tree mix.
const BASE_SIZE := 9            ## Maze WIDTH in cells at tier 1.
const SIZE_INCREMENT := 1       ## Extra width per tier (small).
const MAX_SIZE := 17            ## Width cap so cells stay phone-readable.
const MAX_SIZE_TIER := 9        ## Past this tier, size stops growing; only
                               ## branchiness keeps rising.
## Mazes are PORTRAIT rectangles (height = width * ratio) so they fill the tall
## phone screen instead of leaving big empty borders. ~16:9 matches the viewport.
const PORTRAIT_RATIO := 1.7

const BASE_BRANCH := 0.05       ## Almost pure backtracker at tier 1 (gentle).
const BRANCH_PER_TIER := 0.08   ## Added per tier -> more forks / dead ends.
const MAX_BRANCH := 0.75        ## Cap (kept below 1.0 to retain some long routes).

## Endless mazes play this many tiers harder than their displayed tier (size +
## branchiness + tighter time). The on-screen "TIER N", themes and records still
## use the real tier; only the generated challenge is bumped.
const DIFFICULTY_OFFSET := 2

# --- Classic campaign (1000 levels) ----------------------------------------
#
# Campaign difficulty is a DETERMINISTIC function of the level number, so every
# retry of level N plays at exactly the same difficulty (a fresh random layout,
# the same challenge). Width grows slowly to a phone-readable cap; branchiness
# (the real difficulty lever) keeps climbing across the whole 1000-level span,
# and the timer buffer eases from generous to tight.
const CAMPAIGN_TOTAL_LEVELS := 1000
const CAMPAIGN_LEVELS_PER_CHAPTER := 10   ## Each chapter shares one art theme.
const CAMPAIGN_MAX_WIDTH := 17            ## Phone-readable width cap (matches MAX_SIZE).
const CAMPAIGN_WIDTH_SPAN := 400          ## Levels taken to grow BASE_SIZE -> the cap.
const CAMPAIGN_MIN_BRANCH := 0.05         ## Gentle forks at level 1.
const CAMPAIGN_MAX_BRANCH := 0.9          ## Dense misleading routes by level 1000.
const CAMPAIGN_MAX_TIMER_TIER := 20       ## Timer buffer tightens across levels 1..1000.

# --- Signals ---------------------------------------------------------------

signal hearts_changed(hearts: int)
signal progress_changed(tier: int, maze_in_tier: int)
signal bonus_heart_won()                 ## The rare 20% +1 heart roll succeeded.
signal game_over(tier_reached: int)      ## Hearts hit 0; a full reset happened.
signal campaign_level_changed(level: int)  ## CLASSIC: the active level changed.

# --- State -----------------------------------------------------------------

var hearts: int = MAX_HEARTS
var current_tier: int = 1
var maze_in_tier: int = 1
var tier_clean_run: bool = true          ## No death since this tier began.
var last_tier_reached: int = 1           ## Tier reached before the last reset.
var game_mode: GameMode = GameMode.ENDLESS
var campaign_level: int = 1              ## CLASSIC: level currently selected/played.

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_register_input_actions()


## Select a mode and start a completely fresh run (ENDLESS / TRAP). CLASSIC starts
## via [method start_campaign] instead (it is level-based, not run-based).
func start_run(mode: GameMode, emit: bool = true) -> void:
	game_mode = mode
	reset_run(emit)


## Start the CLASSIC campaign at a specific level (from the level-select screen).
func start_campaign(level: int) -> void:
	game_mode = GameMode.CLASSIC
	campaign_level = clampi(level, 1, CAMPAIGN_TOTAL_LEVELS)
	campaign_level_changed.emit(campaign_level)


## Advance to the next campaign level after a win. Returns false if there is no
## next level (the campaign is finished).
func campaign_advance() -> bool:
	if campaign_level >= CAMPAIGN_TOTAL_LEVELS:
		return false
	campaign_level += 1
	campaign_level_changed.emit(campaign_level)
	return true


func is_final_campaign_level() -> bool:
	return campaign_level >= CAMPAIGN_TOTAL_LEVELS


func is_trap_mode() -> bool:
	return game_mode == GameMode.TRAP


func is_endless_mode() -> bool:
	return game_mode == GameMode.ENDLESS


func is_classic_mode() -> bool:
	return game_mode == GameMode.CLASSIC


## Reset everything to a brand-new run. Emits the relevant change signals.
func reset_run(emit: bool = true) -> void:
	hearts = MAX_HEARTS
	current_tier = 1
	maze_in_tier = 1
	tier_clean_run = true
	if emit:
		hearts_changed.emit(hearts)
		progress_changed.emit(current_tier, maze_in_tier)


## Player reached the exit (before time in Classic, or alive in Trap Mode).
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


## The player failed the maze (timer or trap). Trap retries can keep the current
## maze/progress so the player can learn the trap pattern.
## Returns true if this loss ended the run (full reset to tier 1).
func on_maze_lost(retry_current: bool = false) -> bool:
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
	# Classic retries the tier. Trap mode retries the exact current maze.
	if not retry_current:
		maze_in_tier = 1
	progress_changed.emit(current_tier, maze_in_tier)
	return false


## The tier used to scale the actual challenge (current tier + difficulty offset).
func difficulty_tier() -> int:
	return current_tier + DIFFICULTY_OFFSET


## Maze dimensions (in cells) for the current tier: a portrait rectangle that
## fills the screen. Width is capped; height follows the portrait ratio.
func get_maze_dimensions() -> Vector2i:
	var effective_tier: int = mini(difficulty_tier(), MAX_SIZE_TIER)
	var width: int = mini(BASE_SIZE + (effective_tier - 1) * SIZE_INCREMENT, MAX_SIZE)
	var height: int = int(round(width * PORTRAIT_RATIO))
	return Vector2i(width, height)


## Forking bias (0..1) for the current tier — the primary difficulty lever.
## Keeps rising even after maze dimensions stop growing.
func get_branchiness() -> float:
	return minf(BASE_BRANCH + (difficulty_tier() - 1) * BRANCH_PER_TIER, MAX_BRANCH)


# --- Classic campaign difficulty (deterministic per level) -----------------

## Zero-based chapter index for a level (each chapter is 10 consecutive levels,
## all sharing one art theme).
func campaign_chapter(level: int) -> int:
	return (clampi(level, 1, CAMPAIGN_TOTAL_LEVELS) - 1) / CAMPAIGN_LEVELS_PER_CHAPTER


## Maze dimensions for a campaign level: a portrait rectangle whose width grows
## slowly to a phone-readable cap (then holds; only branchiness keeps rising).
func campaign_dimensions(level: int) -> Vector2i:
	var l: int = clampi(level, 1, CAMPAIGN_TOTAL_LEVELS)
	var grown: int = BASE_SIZE + (l - 1) * (CAMPAIGN_MAX_WIDTH - BASE_SIZE) / CAMPAIGN_WIDTH_SPAN
	var width: int = mini(grown, CAMPAIGN_MAX_WIDTH)
	var height: int = int(round(width * PORTRAIT_RATIO))
	return Vector2i(width, height)


## Forking bias (0..1) for a campaign level — rises smoothly across all 1000.
func campaign_branchiness(level: int) -> float:
	var p := float(clampi(level, 1, CAMPAIGN_TOTAL_LEVELS) - 1) / float(CAMPAIGN_TOTAL_LEVELS - 1)
	return lerpf(CAMPAIGN_MIN_BRANCH, CAMPAIGN_MAX_BRANCH, p)


## Effective "tier" fed to TimerManager so the time buffer eases from generous
## (level 1) to tight (level 1000).
func campaign_timer_tier(level: int) -> int:
	var l: int = clampi(level, 1, CAMPAIGN_TOTAL_LEVELS)
	return 1 + (l - 1) * (CAMPAIGN_MAX_TIMER_TIER - 1) / (CAMPAIGN_TOTAL_LEVELS - 1)


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
