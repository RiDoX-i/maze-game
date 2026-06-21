class_name TimerManager
extends RefCounted

## Pure, engine-decoupled time-limit calculation.
##
## The limit is anchored to the SHORTEST start->exit route walked at the
## character's speed (the maze is "perfect" -- exactly one route between any two
## cells -- so the start->exit distance IS the shortest path):
##
##     base       = shortest_path_px / speed         # optimal walking time
##     time_limit = base + (X / 3) * base = base * (1 + X / 3)
##
## X is a per-tier buffer that starts generous and eases toward tight as mazes
## get harder. It begins at X_START (3) on tier 1 -> the player gets a full
## extra base of time (2x the optimal walk, lots of room to explore), and decays
## smoothly toward X_MIN (1) -> 1.33x the optimal walk on the hardest tiers.
##
## The decay is exponential with an e-folding length of X_DECAY_TIERS tiers, so
## it eases down gradually -- "not fast, not slow" -- and approaches, without
## ever dropping below, X_MIN.

const X_START := 3.0        ## Buffer X at tier 1.
const X_MIN := 1.0          ## Asymptotic floor X as tiers climb.
const X_DECAY_TIERS := 7.0  ## e-folding length (in tiers) of the ease toward X_MIN.
const EXTRA_SECONDS := 5.0  ## Flat bonus added to every maze on every tier.


## Per-tier buffer factor X: starts at X_START, eases asymptotically toward X_MIN.
static func buffer_factor(tier: int) -> float:
	var t := float(maxi(tier, 1) - 1)
	return X_MIN + (X_START - X_MIN) * exp(-t / X_DECAY_TIERS)


## Time limit (seconds) from the shortest-path length in pixels.
static func compute_time_limit(shortest_px: float, tier: int, speed: float) -> float:
	var base := shortest_px / maxf(speed, 1.0)
	return base * (1.0 + buffer_factor(tier) / 3.0) + EXTRA_SECONDS


## Convenience overload from a maze. [param step_px] is the world distance per
## step (centre-to-centre of adjacent cells).
static func compute_for_maze(maze: MazeGenerator.MazeData, tier: int, step_px: float, speed: float) -> float:
	return compute_time_limit(float(maze.solution_length) * step_px, tier, speed)
