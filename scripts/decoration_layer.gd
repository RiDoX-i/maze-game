class_name DecorationLayer
extends Node2D

## Scatters cosmetic [PropForge] decorations through a maze and draws them in world
## space (mirrors [Collectibles]). Props are non-colliding and never block the
## route: they're placed on floor cells, avoiding the start/exit and the cells the
## caller marks (the solution path, coins, traps). Light-emitting props get a real
## [PointLight2D] child so torches/campfires/crystals actually glow.
##
## Everything is deterministic from the maze seed, so a given map always decorates
## the same way; flames and glows animate via _process.

const PX := 2.0                ## Fat-pixel size (matches CharacterVisual).
const MAX_PROPS := 26          ## Hard cap so big mazes stay cheap/uncluttered.
const MAX_LIGHTS := 6          ## Cap on prop point-lights (mobile perf).
const CELLS_PER_PROP := 13     ## Roughly one prop per this many eligible cells.
const FLICKER_RATE := 7.0      ## Flame frame swaps per second.

var _props: Array = []         ## [{pos, id, t, flip, animated}]
var _lights: Array = []        ## [{node:PointLight2D, base_energy, fire:bool, t}]
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Decorate [param maze] for a biome. [param avoid] is a set ({Vector2i: true}) of
## cells to keep clear (solution path, coins, traps). [param renderer] supplies
## cell -> world positions.
func setup(maze, theme_id: String, seed_value: int, renderer, avoid: Dictionary) -> void:
	clear()
	if maze == null:
		return
	_rng.seed = hash("decor_%d_%s" % [seed_value, theme_id])

	var roster := PropForge.roster_for(theme_id)
	if roster.is_empty():
		return

	# Eligible floor cells: every cell except start/exit, the spawn neighbourhood,
	# and whatever the caller wants kept clear.
	var candidates: Array[Vector2i] = []
	for cy in maze.height:
		for cx in maze.width:
			var cell := Vector2i(cx, cy)
			if cell == maze.start or cell == maze.exit:
				continue
			if absi(cx - maze.start.x) + absi(cy - maze.start.y) < 2:
				continue
			if avoid.has(cell):
				continue
			candidates.append(cell)
	if candidates.is_empty():
		return

	_shuffle(candidates)
	var target: int = clampi(candidates.size() / CELLS_PER_PROP, 0, MAX_PROPS)
	var light_count := 0
	for i in target:
		var cell: Vector2i = candidates[i]
		var id: String = roster[_rng.randi() % roster.size()]
		# Respect the light cap: swap a would-be light prop for a dark one once full.
		if PropForge.is_light(id) and light_count >= MAX_LIGHTS:
			id = _dark_prop(roster)
		var pos: Vector2 = renderer.cell_center_world(cell)
		_props.append({
			"pos": pos, "id": id, "t": _rng.randf() * TAU,
			"flip": _rng.randf() < 0.5, "animated": PropForge.is_animated(id),
		})
		if PropForge.is_light(id) and light_count < MAX_LIGHTS:
			_add_light(id, pos)
			light_count += 1

	# Draw nearer (lower) props on top.
	_props.sort_custom(func(a, b): return a["pos"].y < b["pos"].y)
	queue_redraw()


func clear() -> void:
	for l in _lights:
		var node: Node = l["node"]
		if is_instance_valid(node):
			node.queue_free()
	_lights.clear()
	_props.clear()
	queue_redraw()


func _process(delta: float) -> void:
	var needs_redraw := false
	for p in _props:
		if p["animated"]:
			p["t"] = float(p["t"]) + delta
			needs_redraw = true
	# Fire lights flicker subtly around their base energy.
	for l in _lights:
		if l["fire"]:
			l["t"] = float(l["t"]) + delta
			var node: PointLight2D = l["node"]
			if is_instance_valid(node):
				node.energy = float(l["base_energy"]) * (0.85 + 0.15 * sin(float(l["t"]) * 9.0 + node.position.x))
	if needs_redraw:
		queue_redraw()


# --- Lights ----------------------------------------------------------------

func _add_light(id: String, pos: Vector2) -> void:
	var color := PropForge.light_color(id)
	var radius := _light_radius(id)
	var energy := 0.95 if id in ["torch", "campfire", "lantern", "lavarock"] else 0.7
	var light := LightForge.make_light(color, radius, energy)
	light.position = pos + Vector2(0, -8.0)
	add_child(light)
	_lights.append({
		"node": light, "base_energy": energy,
		"fire": id in ["torch", "campfire", "lavarock"], "t": _rng.randf() * TAU,
	})


func _light_radius(id: String) -> float:
	match id:
		"torch", "campfire": return 104.0
		"lantern": return 92.0
		"lavarock": return 84.0
		"crystal": return 74.0
		"mushrooms": return 60.0
		_: return 80.0


func _dark_prop(roster: Array) -> String:
	# Prefer a non-light prop when the light budget is spent.
	for _try in 6:
		var id: String = roster[_rng.randi() % roster.size()]
		if not PropForge.is_light(id):
			return id
	return "bones"


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


# --- Drawing ---------------------------------------------------------------

func _draw() -> void:
	for p in _props:
		var pos: Vector2 = p["pos"]
		var frame := int(float(p["t"]) * FLICKER_RATE) % 2 if p["animated"] else 0
		_draw_shadow(pos, p["id"])
		for e in PropForge.rects(String(p["id"]), frame):
			var lx: float = e[0]
			var ly: float = e[1]
			var w: float = e[2]
			var h: float = e[3]
			var x := -(lx + w) * PX if p["flip"] else lx * PX
			draw_rect(Rect2(pos + Vector2(x, ly * PX), Vector2(w * PX, h * PX)), e[4], true)


func _draw_shadow(pos: Vector2, id: String) -> void:
	# A soft flattened contact shadow grounds the prop on the floor.
	var w := 7.0 if id in ["chest", "campfire", "shrine", "statue", "skeleton"] else 5.0
	draw_set_transform(pos + Vector2(0, 1.0), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, w, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
