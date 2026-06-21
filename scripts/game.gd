extends Node2D

## Orchestrates both game modes. Classic generates timed mazes; Trap Mode loads
## a fixed prepared campaign and replays the current map after a hit.
##
## Also owns the game-feel layer: themed backdrop, screen-shake (distinct for a
## heart loss vs. clearing a tier), colour flashes, the deferred pause flow, and
## the occasional "wrong path" speech bubble.

const GAME_OVER_SCENE := "res://scenes/game_over.tscn"
const CAMPAIGN_COMPLETE_SCENE := "res://scenes/campaign_complete.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const EXIT_REACH_RADIUS := 16.0   ## How close (px) to the exit centre counts as escaped.
const TRANSITION_DELAY := 0.45    ## Brief pause between mazes so feedback registers.
const TIER_CLEAR_DELAY := 0.95    ## Longer, so the tier-clear celebration plays out.
const WRONG_PATH_CHANCE := 0.20   ## Real 20% chance, rolled ONCE per wrong turn.
const WRONG_PATH_SAY_COOLDOWN := 3.0   ## After a bubble shows, stay quiet this long.
const WRONG_PATH_MISS_COOLDOWN := 0.6  ## Anti-jitter only (a failed roll won't re-roll instantly).
const TRAP_VIEW_TILES := 30       ## Grid tiles tall the follow-cam shows in Trap Mode.

## Short, varied "wrong path" lines (only characters the pixel font supports).
const WRONG_MESSAGES := [
	"WRONG WAY", "NOT THIS WAY", "DEAD END AHEAD", "NOPE", "BAD TURN",
	"OOPS", "GOING WRONG", "NOT HERE", "HMM... NO", "TRY ELSEWHERE",
]

@onready var _renderer: MazeRenderer = $MazeRenderer
@onready var _traps: TrapLayer = $TrapLayer
@onready var _player: PlayerController = $Player
@onready var _camera: Camera2D = $Camera2D
@onready var _hud = $UI/HUD
@onready var _bg = $BG/GameBackground
@onready var _flash: ColorRect = $UI/Flash
@onready var _pause_menu = $UI/PauseMenu
@onready var _bubble = $Player/SpeechBubble
@onready var _collectibles = $Collectibles
@onready var _path_guide = $PathGuide
@onready var _decorations: DecorationLayer = $Decorations
@onready var _ambient: CanvasModulate = $Ambient
@onready var _run_trail: RunTrail = $Player/RunTrail
@onready var _swipe_input: Control = $UI/SwipeInput
@onready var _joystick_ui: Control = $UI/VirtualJoystick
@onready var _nav: NavGuide = $NavGuide

# Procedural lighting (created in _ready). PlayerLight follows the player; the
# ExitLight is a pulsing beacon repositioned each maze.
const EXIT_LIGHT_ENERGY := 1.1
const TRAP_AMBIENT := Color(0.82, 0.84, 0.9)   ## Near-neutral so trap maps stay readable.
var _player_light: PointLight2D
var _exit_light: PointLight2D
var _anim_t := 0.0

var _time_left: float = 0.0
var _time_full: float = 0.0          ## Full budget for the current maze (for the guide restart).
var _exit_world := Vector2.ZERO
var _running := false
var _maze_seed := -1
var _maze: MazeGenerator.MazeData

# Wrong-path detection.
var _dist: Dictionary = {}          ## cell (Vector2i) -> graph distance to exit.
var _path_cells: Dictionary = {}    ## cells on the unique correct route start->exit.
var _path_order: Array[Vector2i] = []  ## same route, ordered start->exit (for coin placement).
var _player_cell := Vector2i(-1, -1)
var _bubble_cd := 0.0
var _last_message := -1

# Camera follow (Trap Mode's big maps) + classic record tracking.
var _follow_cam := false
var _record_to_beat := 0
var _record_announced := false

# Deferred pause (only takes effect between maps).
var _pause_requested := false
var _pending_reuse := false

# Screen shake (applied to the camera offset in _process).
var _shake_mag := 0.0
var _shake_time := 0.0
var _shake_dur := 0.0001


func _ready() -> void:
	# Block screenshots / screen recording during ENDLESS play (the only mode with
	# a competitive World Records board). Classic campaign / Trap stay capturable.
	ScreenSecurity.set_secure(GameState.is_endless_mode())
	_traps.player_hit.connect(_on_trap_hit)
	if _hud.has_signal("pause_pressed"):
		_hud.pause_pressed.connect(_on_pause_pressed)
	_pause_menu.resume_requested.connect(_on_resume)
	_pause_menu.menu_requested.connect(_on_exit_to_menu)
	if GameState.is_endless_mode():
		_record_to_beat = HighScores.best_tier()

	# Procedural lighting: a warm glow carried by the player + a beacon at the exit.
	_player_light = LightForge.make_light(Color("#ffd9a0"), 150.0, 1.0)
	_player.add_child(_player_light)
	_exit_light = LightForge.make_light(Color("#ffd23f"), 120.0, EXIT_LIGHT_ENERGY)
	add_child(_exit_light)

	_start_maze(false)


func _exit_tree() -> void:
	# Re-allow screenshots once we leave gameplay (menus, game over, records).
	ScreenSecurity.set_secure(false)


func _physics_process(delta: float) -> void:
	if not _running:
		return

	if not GameState.is_trap_mode():
		_time_left -= delta
		var picked: Array = _collectibles.collect_at(_player.global_position)
		if not picked.is_empty():
			var time_count := 0
			for kind in picked:
				if kind == "guide":
					_activate_guide()
				else:
					time_count += 1
			if time_count > 0:
				_collect_time_bonus(time_count)
		_hud.set_time(_time_left)

	_update_wrong_path(delta)

	if _player.global_position.distance_to(_exit_world) <= EXIT_REACH_RADIUS:
		_on_win()
	elif not GameState.is_trap_mode() and _time_left <= 0.0:
		_on_lose()


func _process(delta: float) -> void:
	_anim_t += delta
	if _exit_light != null and is_instance_valid(_exit_light):
		_exit_light.energy = EXIT_LIGHT_ENERGY * (0.8 + 0.2 * sin(_anim_t * 3.0))

	if _follow_cam and _player != null and is_instance_valid(_player):
		_camera.position = _player.global_position

	if _shake_time > 0.0:
		_shake_time -= delta
		var f := clampf(_shake_time / _shake_dur, 0.0, 1.0)
		var amp := _shake_mag * f * f
		_camera.offset = Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
	elif _camera.offset != Vector2.ZERO:
		_camera.offset = Vector2.ZERO


func _start_maze(reuse_current: bool = false) -> void:
	var maze: MazeGenerator.MazeData
	var prepared: Dictionary = {}
	if GameState.is_trap_mode():
		# Trap Mode only reads the fixed campaign catalogue; it never generates maps.
		prepared = PreparedTrapMaps.for_progress(GameState.current_tier, GameState.maze_in_tier)
		maze = prepared["maze"]
	else:
		if not reuse_current or _maze_seed < 0:
			_maze_seed = randi_range(0, 2147483647)
		var dims := _maze_dimensions()
		maze = MazeGenerator.generate(dims.x, dims.y, _maze_seed, _maze_branchiness())
	_maze = maze
	var theme_tier := _theme_tier()
	var theme := MazeTheme.for_tier(theme_tier)
	var accent := _chapter_accent()
	_renderer.render(maze, theme_tier, Color.WHITE.lerp(accent, 0.16))
	_bg.set_palette(theme.get("id", "grove"))

	_player.place_at(_renderer.cell_center_world(maze.start))
	_player.set_footstep_surface(theme.get("step", "stone"))
	# Input + speed: control scheme is per-mode and player-configurable (defaults:
	# swipe for CLASSIC & ENDLESS, joystick for TRAP).
	var swipe := GameSettings.is_swipe(_mode_key())
	_player.swipe_mode = swipe
	_player.glide_speed = PlayerProgress.current_speed()
	_player.begin_maze(maze, _renderer)
	_swipe_input.visible = swipe
	_joystick_ui.visible = not swipe
	_run_trail.set_style(PlayerProgress.current_vfx(), theme.get("step", "stone"))
	_run_trail.clear()
	# Junction dots + heading guide only make sense for swipe/corridor play.
	if swipe:
		_nav.setup(maze, _renderer, _player)
	else:
		_nav.clear()
	_player.play_spawn_step()
	_player.active = true
	_exit_world = _renderer.cell_center_world(maze.exit)
	_apply_lighting(theme, accent)

	_dist = _compute_exit_distance(maze)
	_path_order = _compute_path_order(maze)
	_path_cells = {}
	for cell in _path_order:
		_path_cells[cell] = true
	_player_cell = maze.start
	_bubble_cd = 1.5
	if _hud.has_method("set_pause_queued"):
		_hud.set_pause_queued(false)

	if GameState.is_trap_mode():
		var trap_definitions: Array[Dictionary] = prepared["traps"]
		_traps.setup(
			trap_definitions, _renderer.tile_size(), _player,
			_renderer.cell_center_world(maze.start), maze.grid
		)
		_collectibles.clear_coins()   # time pickups are a Classic-mode feature
		_path_guide.clear_path()
		_decorations.clear()          # keep dense trap maps uncluttered
		# Big Trap-Mode maps: follow the player zoomed in (you can't see it all).
		_setup_follow_camera(maze)
	else:
		_traps.clear_traps()
		# World distance per solution step is two grid tiles (cell centre to centre).
		var step_px := _renderer.tile_size() * 2.0
		_time_left = TimerManager.compute_for_maze(maze, _timer_tier(), step_px, _player.base_speed)
		_time_full = _time_left
		_hud.set_time(_time_left)
		_collectibles.setup(_coin_positions(maze), _guide_positions(maze))
		_path_guide.clear_path()
		# Scatter cosmetic props off the solution route (and clear of coins/start/exit).
		_decorations.setup(maze, theme.get("id", "grove"), _maze_seed, _renderer, _path_cells)
		_follow_cam = false
		_camera.offset = Vector2.ZERO
		_fit_camera(maze)

	_running = true


# --- Difficulty / theme source (CLASSIC campaign vs ENDLESS tiers) ---------

func _maze_dimensions() -> Vector2i:
	if GameState.is_classic_mode():
		return GameState.campaign_dimensions(GameState.campaign_level)
	return GameState.get_maze_dimensions()


func _maze_branchiness() -> float:
	if GameState.is_classic_mode():
		return GameState.campaign_branchiness(GameState.campaign_level)
	return GameState.get_branchiness()


## The tier whose theme this maze wears (CLASSIC: one theme per 10-level chapter).
func _theme_tier() -> int:
	if GameState.is_classic_mode():
		return GameState.campaign_chapter(GameState.campaign_level) + 1
	return GameState.current_tier


## The tier fed to TimerManager for the time budget.
func _timer_tier() -> int:
	if GameState.is_classic_mode():
		return GameState.campaign_timer_tier(GameState.campaign_level)
	return GameState.difficulty_tier()


## Vivid per-chapter accent (CLASSIC: per chapter; ENDLESS: per tier). Drives the
## exit beacon colour, the ambient lean and the subtle tile tint.
func _chapter_accent() -> Color:
	if GameState.is_classic_mode():
		return MazeTheme.chapter_accent(GameState.campaign_chapter(GameState.campaign_level))
	if GameState.is_endless_mode():
		return MazeTheme.chapter_accent(GameState.current_tier)
	return Color.WHITE


## Settings key for the current mode (control-scheme lookup).
func _mode_key() -> String:
	if GameState.is_classic_mode():
		return "classic"
	if GameState.is_trap_mode():
		return "trap"
	return "endless"


## The difficulty tier of the map just cleared (drives the XP reward).
func _reward_tier() -> int:
	if GameState.is_classic_mode():
		return GameState.campaign_chapter(GameState.campaign_level) + 1
	if GameState.is_trap_mode():
		return PreparedTrapMaps.index_for_progress(GameState.current_tier, GameState.maze_in_tier) + 1
	return GameState.current_tier


## Grant XP for a win (10 + 5 per tier) and celebrate any speed unlocks.
func _award_win_xp() -> void:
	var xp := PlayerProgress.xp_for_win(_reward_tier())
	var unlocked := PlayerProgress.add_xp(xp)
	if _hud.has_method("announce"):
		_hud.announce("+%d XP" % xp, Color("#9be7ff"))
		if not unlocked.is_empty():
			var top: int = unlocked[unlocked.size() - 1]
			_hud.announce("SPEED UNLOCKED: %s" % str(PlayerProgress.SPEEDS[top]["name"]), Color("#ffd23f"))


## Set the world ambient (CanvasModulate) + exit beacon for this maze. Ambient is
## kept bright enough that the maze is always readable; Trap stays near-neutral.
func _apply_lighting(theme: Dictionary, accent: Color) -> void:
	if GameState.is_trap_mode():
		_ambient.color = TRAP_AMBIENT
	elif _is_dark_map():
		# ~30% of maps spawn in the moody, lit-by-torchlight dark style.
		_ambient.color = MazeTheme.ambient_for(theme).lerp(accent, 0.08)
	else:
		# The rest are bright daylight (decorations + lights still present, subtle).
		_ambient.color = MazeTheme.daylight_for(theme).lerp(accent, 0.05)
	if _exit_light != null:
		_exit_light.position = _exit_world
		_exit_light.color = Color("#ffd23f").lerp(accent, 0.5)


## 30% chance a generated map is "dark mode"; deterministic per map seed.
func _is_dark_map() -> bool:
	return absi(hash(_maze_seed)) % 100 < 30


func _on_win() -> void:
	_end_round()
	if GameState.is_classic_mode():
		_on_campaign_win()
		return
	_award_win_xp()
	if GameState.is_trap_mode() and PreparedTrapMaps.is_final_progress(
		GameState.current_tier, GameState.maze_in_tier
	):
		get_tree().change_scene_to_file(CAMPAIGN_COMPLETE_SCENE)
		return
	# A tier is cleared when maze 3 of the tier is the one we just won.
	var tier_cleared := GameState.maze_in_tier == GameState.MAZES_PER_TIER
	GameState.on_maze_won()
	_maybe_announce_record()
	if tier_cleared:
		_play_tier_clear()
		_queue_next_maze(false, TIER_CLEAR_DELAY)
	else:
		_queue_next_maze(false)


## CLASSIC: the level is beaten -> mark it complete (it can never be replayed),
## then either finish the campaign or unlock + auto-advance to the next level.
func _on_campaign_win() -> void:
	_award_win_xp()
	var campaign_done := CampaignProgress.complete_level(GameState.campaign_level)
	if campaign_done or GameState.is_final_campaign_level():
		get_tree().change_scene_to_file(CAMPAIGN_COMPLETE_SCENE)
		return
	_play_level_clear()
	GameState.campaign_advance()
	_queue_next_maze(false, TIER_CLEAR_DELAY)


## Endless only: once you pass the previous best tier, celebrate but keep playing.
## The name is only entered at the end of the run (in _finish_run).
func _maybe_announce_record() -> void:
	if not GameState.is_endless_mode() or _record_announced:
		return
	if _record_to_beat >= 1 and GameState.current_tier > _record_to_beat:
		_record_announced = true
		if _hud.has_method("announce"):
			_hud.announce("NEW RECORD!", Color("#ffd23f"))
		_haptic(40)


func _on_lose() -> void:
	_end_round()
	# CLASSIC: no hearts, no game over. Just reload a fresh map of the SAME
	# difficulty for this level so the player can keep trying.
	if GameState.is_classic_mode():
		_retry_feedback()
		_queue_next_maze(false)
		return
	_hurt_feedback()
	var run_over := GameState.on_maze_lost(false)
	if run_over:
		_finish_run()
	else:
		_queue_next_maze(false)


func _on_trap_hit() -> void:
	if not _running or not GameState.is_trap_mode():
		return
	_end_round()
	_hurt_feedback()
	var run_over := GameState.on_maze_lost(true)
	if run_over:
		_finish_run()
	else:
		_queue_next_maze(true)


func _end_round() -> void:
	_running = false
	_player.active = false
	_traps.set_enabled(false)
	_path_guide.clear_path()


## A run ended (hearts hit 0). Endless runs may qualify for the records board.
func _finish_run() -> void:
	if GameState.is_endless_mode() and HighScores.qualifies(GameState.last_tier_reached):
		get_tree().change_scene_to_file("res://scenes/name_entry.tscn")
	else:
		get_tree().change_scene_to_file(GAME_OVER_SCENE)


func _queue_next_maze(reuse_current: bool, delay: float = TRANSITION_DELAY) -> void:
	# Small delay so heart/win feedback is visible before loading the next round.
	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(_after_transition.bind(reuse_current))


func _after_transition(reuse_current: bool) -> void:
	# A pause requested mid-map only takes effect now, between maps.
	if _pause_requested:
		_pending_reuse = reuse_current
		_pause_menu.open(_score_text())
	else:
		_start_maze(reuse_current)


# --- Feedback --------------------------------------------------------------

func _hurt_feedback() -> void:
	# Sharp, short red jolt — clearly different from the tier-clear celebration.
	_shake(13.0, 0.32)
	_screen_flash(Color("#ff3b3b"), 0.42, 0.45)
	_haptic(90)


func _play_tier_clear() -> void:
	# Bigger, golden, celebratory shake + banner — distinct from a heart loss.
	_shake(24.0, 0.6)
	_screen_flash(Color("#ffd23f"), 0.5, 0.7)
	if _hud.has_method("announce"):
		_hud.announce("TIER CLEAR", Color("#ffd23f"))
	_haptic(40)


## CLASSIC: a level was cleared (announces the level just beaten, before advance).
func _play_level_clear() -> void:
	_shake(20.0, 0.5)
	_screen_flash(Color("#ffd23f"), 0.45, 0.6)
	if _hud.has_method("announce"):
		_hud.announce("LEVEL %d CLEAR" % GameState.campaign_level, Color("#ffd23f"))
	_haptic(40)


## CLASSIC: the timer ran out — a soft, non-punishing "try again" cue (no heart
## loss), clearly gentler than ENDLESS's red hurt jolt.
func _retry_feedback() -> void:
	_shake(10.0, 0.28)
	_screen_flash(Color("#ff9b5b"), 0.34, 0.4)
	if _hud.has_method("announce"):
		_hud.announce("TIME UP - RETRY", Color("#ff9b5b"))
	_haptic(60)


func _shake(magnitude: float, duration: float) -> void:
	_shake_mag = magnitude
	_shake_dur = maxf(duration, 0.0001)
	_shake_time = _shake_dur


func _screen_flash(color: Color, peak_alpha: float, duration: float) -> void:
	if _flash == null:
		return
	_flash.color = Color(color.r, color.g, color.b, peak_alpha)
	var tween := create_tween()
	tween.tween_property(_flash, "color:a", 0.0, duration)


func _haptic(milliseconds: int) -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(milliseconds)


# --- Pause -----------------------------------------------------------------

func _on_pause_pressed() -> void:
	if not _running or _pause_requested:
		return
	_pause_requested = true
	if _hud.has_method("set_pause_queued"):
		_hud.set_pause_queued(true)
	if _hud.has_method("announce"):
		_hud.announce("PAUSE AFTER MAP", Color("#7ee0ff"))


func _on_resume() -> void:
	_pause_requested = false
	_start_maze(_pending_reuse)


func _on_exit_to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


func _score_text() -> String:
	if GameState.is_classic_mode():
		return "LEVEL %d/%d" % [GameState.campaign_level, GameState.CAMPAIGN_TOTAL_LEVELS]
	if GameState.is_trap_mode():
		var level := PreparedTrapMaps.index_for_progress(
			GameState.current_tier, GameState.maze_in_tier) + 1
		return "LEVEL %d/%d\nHEARTS %d" % [level, PreparedTrapMaps.count(), GameState.hearts]
	return "TIER %d  MAZE %d/%d\nHEARTS %d   BEST %d" % [
		GameState.current_tier, GameState.maze_in_tier, GameState.MAZES_PER_TIER,
		GameState.hearts, maxi(HighScores.best_tier(), GameState.current_tier),
	]


# --- Wrong-path hint -------------------------------------------------------

func _update_wrong_path(delta: float) -> void:
	_bubble_cd = maxf(_bubble_cd - delta, 0.0)
	if _path_cells.is_empty():
		return
	var cell := _nearest_cell()
	if cell == Vector2i(-1, -1) or cell == _player_cell:
		return
	var prev := _player_cell
	_player_cell = cell
	if _bubble_cd > 0.0:
		return
	# A wrong CHOICE is a single event: leaving the correct route at a fork. We
	# roll the 20% exactly once per departure (not once per cell walked).
	if _path_cells.has(prev) and not _path_cells.has(cell):
		if randf() < WRONG_PATH_CHANCE:
			_bubble.say(_pick_message())
			_bubble_cd = WRONG_PATH_SAY_COOLDOWN
		else:
			_bubble_cd = WRONG_PATH_MISS_COOLDOWN


## A random wrong-path line, never the same one twice in a row.
func _pick_message() -> String:
	var index := randi() % WRONG_MESSAGES.size()
	if index == _last_message:
		index = (index + 1) % WRONG_MESSAGES.size()
	_last_message = index
	return WRONG_MESSAGES[index]


## Cell the player is currently standing on, or (-1,-1) if between cells.
func _nearest_cell() -> Vector2i:
	if _maze == null:
		return Vector2i(-1, -1)
	var ts := float(_renderer.tile_size())
	var cx := int(round((_player.global_position.x / ts - 1.5) / 2.0))
	var cy := int(round((_player.global_position.y / ts - 1.5) / 2.0))
	if cx < 0 or cy < 0 or cx >= _maze.width or cy >= _maze.height:
		return Vector2i(-1, -1)
	var cell := Vector2i(cx, cy)
	if _player.global_position.distance_to(_renderer.cell_center_world(cell)) > ts * 0.6:
		return Vector2i(-1, -1)   # still in a corridor between cells
	return cell


## BFS distance from the exit to every reachable cell, over the maze passages.
func _compute_exit_distance(maze: MazeGenerator.MazeData) -> Dictionary:
	var dirs := {
		MazeGenerator.WALL_N: Vector2i(0, -1), MazeGenerator.WALL_E: Vector2i(1, 0),
		MazeGenerator.WALL_S: Vector2i(0, 1), MazeGenerator.WALL_W: Vector2i(-1, 0),
	}
	var dist := {maze.exit: 0}
	var queue: Array[Vector2i] = [maze.exit]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		var mask: int = maze.cells[cur.x][cur.y]
		for wall in dirs:
			if (mask & wall) != 0:
				continue   # wall present -> no passage this way
			var nxt: Vector2i = cur + dirs[wall]
			if nxt.x < 0 or nxt.y < 0 or nxt.x >= maze.width or nxt.y >= maze.height:
				continue
			if dist.has(nxt):
				continue
			dist[nxt] = int(dist[cur]) + 1
			queue.append(nxt)
	return dist


## The single correct route start->exit (a perfect maze has exactly one), ordered
## from start to exit. Used for wrong-turn detection and coin placement.
func _compute_path_order(maze: MazeGenerator.MazeData) -> Array[Vector2i]:
	var dirs := {
		MazeGenerator.WALL_N: Vector2i(0, -1), MazeGenerator.WALL_E: Vector2i(1, 0),
		MazeGenerator.WALL_S: Vector2i(0, 1), MazeGenerator.WALL_W: Vector2i(-1, 0),
	}
	var order: Array[Vector2i] = [maze.start]
	var cur: Vector2i = maze.start
	var guard := 0
	var cap := maze.cell_count * 2
	while cur != maze.exit and guard < cap:
		guard += 1
		var mask: int = maze.cells[cur.x][cur.y]
		var stepped := false
		for wall in dirs:
			if (mask & wall) != 0:
				continue
			var nxt: Vector2i = cur + dirs[wall]
			# The neighbour one step closer to the exit is the correct move.
			if _dist.has(nxt) and int(_dist[nxt]) == int(_dist.get(cur, 0)) - 1:
				cur = nxt
				order.append(cur)
				stepped = true
				break
		if not stepped:
			break
	return order


## How many +5s coins this map gets: easy maps 4, mid 1, hard 0.
func _coin_count() -> int:
	if GameState.is_classic_mode():
		# Early campaign levels are generous with time pickups; they fade out as
		# the player gets comfortable.
		var lvl := GameState.campaign_level
		if lvl <= 30:
			return 4
		elif lvl <= 100:
			return 1
		return 0
	var tier := GameState.current_tier
	if tier <= 3:
		return 4
	elif tier <= 6:
		return 1
	return 0


## +5s coin positions, placed ON the correct route to the exit (so collecting
## them means you're heading the right way), spread evenly across the path.
func _coin_positions(maze: MazeGenerator.MazeData) -> Array:
	var count := _coin_count()
	var positions: Array = []
	if count <= 0 or _path_order.size() < 4:
		return positions
	var used := {}
	for i in count:
		var fraction := float(i + 1) / float(count + 1)
		var index: int = clampi(int(_path_order.size() * fraction), 1, _path_order.size() - 2)
		if used.has(index):
			continue
		used[index] = true
		positions.append(_renderer.cell_center_world(_path_order[index]))
	return positions


## The rare guide orb: 30% of maps get one, dropped on ANY reachable cell (not
## necessarily toward the exit). Returns [] or [world_pos].
func _guide_positions(maze: MazeGenerator.MazeData) -> Array:
	if randf() >= 0.30:
		return []
	var candidates: Array = []
	for cell in _dist.keys():
		if cell == maze.exit:
			continue
		if absi(cell.x - maze.start.x) + absi(cell.y - maze.start.y) < 3:
			continue   # not right on top of the spawn
		candidates.append(cell)
	if candidates.is_empty():
		return []
	var chosen: Vector2i = candidates[randi() % candidates.size()]
	return [_renderer.cell_center_world(chosen)]


## Apply a collected +5s time bonus with a small celebratory cue.
func _collect_time_bonus(count: int) -> void:
	_time_left += count * _collectibles.BONUS_SECONDS
	if _hud.has_method("announce"):
		_hud.announce("+%d SEC" % int(count * _collectibles.BONUS_SECONDS), _collectibles.TIME_COLOR)
	_screen_flash(_collectibles.TIME_COLOR, 0.22, 0.3)
	_haptic(25)


## Guide orb collected: refill the timer and reveal the route to the exit for just
## long enough to run it at the player's speed.
func _activate_guide() -> void:
	_time_left = _time_full
	_hud.set_time(_time_left)
	var from := _nearest_cell()
	if from == Vector2i(-1, -1):
		from = _player_cell
	var route := _route_from(from)
	var points: Array = []
	for cell in route:
		points.append(_renderer.cell_center_world(cell))
	var distance := 0.0
	for i in range(1, points.size()):
		distance += points[i].distance_to(points[i - 1])
	var duration := distance / maxf(_player.glide_speed, 1.0) + 1.5   # +buffer so it lasts the run
	_path_guide.show_path(points, duration)
	if _hud.has_method("announce"):
		_hud.announce("FOLLOW THE PATH", _collectibles.GUIDE_COLOR)
	_screen_flash(_collectibles.GUIDE_COLOR, 0.3, 0.4)
	_haptic(40)


## Ordered cells from [param cell] to the exit, following the route (decreasing
## distance-to-exit). Works from any cell, unlike the start-only path.
func _route_from(cell: Vector2i) -> Array[Vector2i]:
	var dirs := {
		MazeGenerator.WALL_N: Vector2i(0, -1), MazeGenerator.WALL_E: Vector2i(1, 0),
		MazeGenerator.WALL_S: Vector2i(0, 1), MazeGenerator.WALL_W: Vector2i(-1, 0),
	}
	var order: Array[Vector2i] = [cell]
	var cur := cell
	var guard := 0
	var cap := _maze.cell_count * 2 if _maze != null else 0
	while _maze != null and cur != _maze.exit and guard < cap:
		guard += 1
		var mask: int = _maze.cells[cur.x][cur.y]
		var stepped := false
		for wall in dirs:
			if (mask & wall) != 0:
				continue
			var nxt: Vector2i = cur + dirs[wall]
			if _dist.has(nxt) and int(_dist[nxt]) == int(_dist.get(cur, 0)) - 1:
				cur = nxt
				order.append(cur)
				stepped = true
				break
		if not stepped:
			break
	return order


func _setup_follow_camera(maze: MazeGenerator.MazeData) -> void:
	_follow_cam = true
	_camera.offset = Vector2.ZERO
	var ts := float(_renderer.tile_size())
	var viewport := get_viewport_rect().size
	var zoom_factor: float = viewport.y / (ts * TRAP_VIEW_TILES)
	_camera.zoom = Vector2(zoom_factor, zoom_factor)
	_camera.position = _player.global_position
	# Keep the view inside the maze bounds.
	var maze_px := _renderer.pixel_size()
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(maze_px.x)
	_camera.limit_bottom = int(maze_px.y)


func _fit_camera(maze: MazeGenerator.MazeData) -> void:
	# Centre the camera on the maze and zoom so the whole thing fits the screen.
	# Reset any limits a previous Trap-Mode follow-cam left behind.
	_camera.limit_left = -10000000
	_camera.limit_top = -10000000
	_camera.limit_right = 10000000
	_camera.limit_bottom = 10000000
	var maze_px := _renderer.pixel_size()
	_camera.position = maze_px * 0.5
	var viewport := get_viewport_rect().size
	var margin := 1.04  # fill almost the whole screen (just a sliver of breathing room)
	var zoom_factor: float = minf(
		viewport.x / (maze_px.x * margin),
		viewport.y / (maze_px.y * margin)
	)
	_camera.zoom = Vector2(zoom_factor, zoom_factor)
