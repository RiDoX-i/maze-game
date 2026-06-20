class_name TimerManager
extends RefCounted

## Pure, engine-decoupled time-limit calculation.
##
## The limit is anchored to how hard the maze actually is to SOLVE, measured as
## two real walking times at the player's speed:
##   * optimal_time -- walk the shortest start->exit route (an expert who can
##     already see the path).
##   * blind_time   -- a wall-follower's route (someone discovering the maze);
##     this grows a lot with misleading branches, so it tracks real difficulty.
##
##     time_limit = optimal_time + g * (blind_time - optimal_time)
##
## g (generosity, 0..1) places you between expert and blind. It starts generous
## and eases down as tiers climb, so harder mazes give MORE absolute time (more
## to solve) while expecting a little more skill.

const G_START := 0.55    ## Generosity at tier 1.
const G_DECAY := 0.015   ## Reduced per tier.
const G_MIN := 0.35      ## Floor.


## Generosity factor for a tier.
static func generosity(tier: int) -> float:
	return clampf(G_START - float(maxi(tier, 1) - 1) * G_DECAY, G_MIN, G_START)


## Time limit (seconds) from the two route lengths in pixels.
static func compute_time_limit(optimal_px: float, blind_px: float, tier: int, speed: float) -> float:
	var s := maxf(speed, 1.0)
	var optimal := optimal_px / s
	var blind := blind_px / s
	return optimal + generosity(tier) * maxf(blind - optimal, 0.0)


## Convenience overload from a maze. [param step_px] is the world distance per
## step (centre-to-centre of adjacent cells).
static func compute_for_maze(maze: MazeGenerator.MazeData, tier: int, step_px: float, speed: float) -> float:
	return compute_time_limit(
		float(maze.solution_length) * step_px,
		float(maze.explore_length) * step_px,
		tier, speed)
