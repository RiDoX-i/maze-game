extends SceneTree

## Diagnostic: how long does each tier actually take to SOLVE vs the time we
## grant? Compares the shortest path (perfect play) against a wall-follower
## (blind solve) so we can see whether the time budget tracks real difficulty.
## Run: godot --headless --path . --script res://tools/verify_timing.gd

const MG := preload("res://scripts/maze_generator.gd")
const GS := preload("res://scripts/game_state.gd")
const TM := preload("res://scripts/timer_manager.gd")

const STEP := 64.0     # world px per cell step (2 * TILE)
const SPEED := 275.0   # player px/s
const SEEDS := 12

const DV := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]  # N E S W
const DB := [1, 2, 4, 8]


func _initialize() -> void:
	var gs = GS.new()
	print("tier | size | branch | sol | junc | dead | wallFollow | optTime | wfTime | CURRENT_limit")
	for tier in [1, 2, 3, 5, 8, 10, 12, 15]:
		gs.current_tier = tier
		var dims: Vector2i = gs.get_maze_dimensions()
		var branch: float = gs.get_branchiness()
		var sol := 0.0
		var junc := 0.0
		var dead := 0.0
		var wf := 0.0
		for s in SEEDS:
			var m = MG.generate(dims.x, dims.y, 1000 + s, branch)
			sol += m.solution_length
			junc += m.junction_count
			dead += m.dead_end_count
			wf += _wall_follow(m)
		sol /= SEEDS; junc /= SEEDS; dead /= SEEDS; wf /= SEEDS
		var opt_time := sol * STEP / SPEED
		var wf_time := wf * STEP / SPEED
		var budget := TM.compute_time_limit(sol * STEP, wf * STEP, tier, SPEED)
		print("%4d | %4d | %.2f | %4.0f | %4.0f | %4.0f | %9.0f | %6.1f | %6.1f | %7.1f"
			% [tier, dims.x, branch, sol, junc, dead, wf, opt_time, wf_time, budget])
	quit(0)


## Right-hand wall follower step count from start to exit (solves perfect mazes).
func _wall_follow(m) -> int:
	var pos: Vector2i = m.start
	var facing := 1  # E
	var steps := 0
	var cap: int = m.cell_count * 8
	while pos != m.exit and steps < cap:
		for off in [1, 0, 3, 2]:  # right, straight, left, back
			var ni: int = (facing + int(off)) % 4
			if (m.cells[pos.x][pos.y] & DB[ni]) == 0:
				facing = ni
				pos += DV[ni]
				steps += 1
				break
	return steps
