class_name TrapLayer
extends Node2D

## Runtime for the fixed campaign's eight trap families. PreparedTrapMaps owns
## placement/type data; this node owns telegraphs, movement, hit tests and art.

signal player_hit()

const TYPE_SPIKE := "spike"
const TYPE_MINE := "mine"
const TYPE_DART := "dart"
const TYPE_LASER := "laser"
const TYPE_CRUSHER := "crusher"
const TYPE_SAW := "saw"
const TYPE_TELEPORT := "teleport"
const TYPE_FIRE := "fire"
const TYPE_ARROW := "arrow"       ## Step on the hidden plate -> arrows sweep the corridor.
const TYPE_BOULDER := "boulder"   ## Hidden until near -> a rock rolls; outrun it.

const HIDDEN := 0
const ARMING := 1
const ACTIVE := 2
const SPENT := 3

var _traps: Array[Dictionary] = []
var _player: Node2D
var _enabled := false
var _tile_size := 32
var _spawn_position := Vector2.ZERO
var _grid: Array = []


func setup(
	definitions: Array[Dictionary], tile_size: int, player: Node2D,
	spawn_position: Vector2, maze_grid: Array
) -> void:
	_tile_size = tile_size
	_player = player
	_spawn_position = spawn_position
	_grid = maze_grid
	_enabled = true
	_traps.clear()
	for definition in definitions:
		var cell: Vector2i = definition["cell"]
		var trap: Dictionary = definition.duplicate(true)
		trap["center"] = _cell_center(cell)
		trap["state"] = HIDDEN
		trap["time"] = 0.0
		trap["phase"] = float(int(definition["variant"])) * 0.71
		trap["projectile"] = trap["center"]
		trap["velocity"] = Vector2.ZERO
		trap["direction"] = _best_floor_direction(cell, int(definition["variant"]))
		# Every trap starts HIDDEN (invisible) and only reveals the instant it
		# triggers, so the campaign maps stay a surprise even after a restart.
		_traps.append(trap)
	queue_redraw()


func clear_traps() -> void:
	_enabled = false
	_player = null
	_grid.clear()
	_traps.clear()
	queue_redraw()


func set_enabled(value: bool) -> void:
	_enabled = value


func trap_type_count() -> int:
	var types := {}
	for trap in _traps:
		types[trap["type"]] = true
	return types.size()


func _physics_process(delta: float) -> void:
	if not _enabled or _player == null or not is_instance_valid(_player):
		return
	for trap in _traps:
		trap["phase"] = float(trap["phase"]) + delta
		var hit := false
		match String(trap["type"]):
			TYPE_SPIKE:
				hit = _update_spike(trap, delta)
			TYPE_MINE:
				hit = _update_mine(trap, delta)
			TYPE_DART:
				hit = _update_dart(trap, delta)
			TYPE_LASER:
				hit = _update_laser(trap, delta)
			TYPE_CRUSHER:
				hit = _update_crusher(trap, delta)
			TYPE_SAW:
				hit = _update_saw(trap)
			TYPE_TELEPORT:
				_update_teleport(trap, delta)
			TYPE_FIRE:
				hit = _update_fire(trap, delta)
			TYPE_ARROW:
				hit = _update_arrow(trap, delta)
			TYPE_BOULDER:
				hit = _update_boulder(trap, delta)
		if hit:
			_enabled = false
			player_hit.emit()
			queue_redraw()
			return
	queue_redraw()


func _update_spike(trap: Dictionary, delta: float) -> bool:
	var distance := _distance_to_player(trap)
	var level := int(trap["level"])
	match int(trap["state"]):
		HIDDEN:
			if distance <= 34.0:
				trap["state"] = ARMING
				trap["time"] = maxf(0.07, 0.14 - level * 0.0025)
		ARMING:
			trap["time"] = float(trap["time"]) - delta
			if trap["time"] <= 0.0:
				trap["state"] = ACTIVE
				trap["time"] = 0.72
		ACTIVE:
			trap["time"] = float(trap["time"]) - delta
			if distance <= 17.0:
				return true
			if trap["time"] <= 0.0:
				trap["state"] = SPENT
	return false


func _update_mine(trap: Dictionary, delta: float) -> bool:
	var distance := _distance_to_player(trap)
	var level := int(trap["level"])
	match int(trap["state"]):
		HIDDEN:
			if distance <= 27.0:
				trap["state"] = ARMING
				trap["time"] = maxf(0.25, 0.48 - level * 0.01)
		ARMING:
			trap["time"] = float(trap["time"]) - delta
			if trap["time"] <= 0.0:
				trap["state"] = ACTIVE
				trap["time"] = 0.18
		ACTIVE:
			trap["time"] = float(trap["time"]) - delta
			if distance <= 46.0:
				return true
			if trap["time"] <= 0.0:
				trap["state"] = SPENT
	return false


func _update_dart(trap: Dictionary, delta: float) -> bool:
	match int(trap["state"]):
		HIDDEN:
			if _dart_has_target(trap):
				var center: Vector2 = trap["center"]
				var direction := center.direction_to(_player.global_position)
				trap["velocity"] = direction * (350.0 + int(trap["level"]) * 9.0)
				trap["projectile"] = center
				trap["state"] = ACTIVE
				trap["time"] = 1.2
		ACTIVE:
			trap["time"] = float(trap["time"]) - delta
			trap["projectile"] = Vector2(trap["projectile"]) + Vector2(trap["velocity"]) * delta
			if Vector2(trap["projectile"]).distance_to(_player.global_position) <= 12.0:
				return true
			if trap["time"] <= 0.0 or not _world_is_floor(Vector2(trap["projectile"])):
				trap["state"] = SPENT
	return false


func _update_laser(trap: Dictionary, delta: float) -> bool:
	if int(trap["state"]) == HIDDEN:
		if _laser_in_range(trap):
			trap["state"] = ARMING
			trap["time"] = 0.3
		return false
	trap["time"] = float(trap["time"]) - delta
	if int(trap["state"]) == ARMING and trap["time"] <= 0.0:
		trap["state"] = ACTIVE
		trap["time"] = 0.52
	elif int(trap["state"]) == ACTIVE:
		var segment := _laser_segment(trap)
		if _point_segment_distance(_player.global_position, segment[0], segment[1]) <= 7.0:
			return true
		if trap["time"] <= 0.0:
			trap["state"] = ARMING
			trap["time"] = maxf(0.48, 1.15 - int(trap["level"]) * 0.025)
	return false


func _update_crusher(trap: Dictionary, delta: float) -> bool:
	var distance := _distance_to_player(trap)
	match int(trap["state"]):
		HIDDEN:
			if distance <= 45.0:
				trap["state"] = ARMING
				trap["time"] = maxf(0.28, 0.58 - int(trap["level"]) * 0.014)
		ARMING:
			trap["time"] = float(trap["time"]) - delta
			if trap["time"] <= 0.0:
				trap["state"] = ACTIVE
				trap["time"] = 0.26
		ACTIVE:
			trap["time"] = float(trap["time"]) - delta
			if distance <= 22.0:
				return true
			if trap["time"] <= 0.0:
				trap["state"] = SPENT
	return false


func _update_saw(trap: Dictionary) -> bool:
	if int(trap["state"]) == HIDDEN:
		if _distance_to_player(trap) <= 72.0:
			trap["state"] = ACTIVE
		return false
	return _saw_position(trap).distance_to(_player.global_position) <= 14.0


func _update_teleport(trap: Dictionary, delta: float) -> void:
	trap["time"] = maxf(float(trap["time"]) - delta, 0.0)
	if int(trap["state"]) == ACTIVE and trap["time"] <= 0.0:
		trap["state"] = HIDDEN
	if int(trap["state"]) == HIDDEN and _distance_to_player(trap) <= 17.0:
		trap["state"] = ACTIVE
		trap["time"] = 0.7
		if _player.has_method("place_at"):
			_player.call("place_at", _spawn_position)
		else:
			_player.global_position = _spawn_position


func _update_fire(trap: Dictionary, delta: float) -> bool:
	if int(trap["state"]) == HIDDEN:
		if _distance_to_player(trap) <= 52.0:
			trap["state"] = ARMING
			trap["time"] = 0.3
		return false
	trap["time"] = float(trap["time"]) - delta
	if int(trap["state"]) == ARMING and trap["time"] <= 0.0:
		trap["state"] = ACTIVE
		trap["time"] = 0.43
	elif int(trap["state"]) == ACTIVE:
		var segment := _fire_segment(trap)
		if _point_segment_distance(_player.global_position, segment[0], segment[1]) <= 11.0:
			return true
		if trap["time"] <= 0.0:
			trap["state"] = ARMING
			trap["time"] = maxf(0.42, 1.05 - int(trap["level"]) * 0.022)
	return false


## Pressure-plate arrow trap. Hidden until the player steps on the plate; after a
## short tell, arrows sweep in along the corridor from both sides.
func _update_arrow(trap: Dictionary, delta: float) -> bool:
	match int(trap["state"]):
		HIDDEN:
			if _distance_to_player(trap) <= 16.0:
				trap["state"] = ARMING
				trap["time"] = 0.3
		ARMING:
			trap["time"] = float(trap["time"]) - delta
			if trap["time"] <= 0.0:
				trap["state"] = ACTIVE
				trap["time"] = 1.3
				var center: Vector2 = trap["center"]
				var axis: Vector2 = trap["direction"]
				var speed := 320.0 + int(trap["level"]) * 8.0
				var reach := _tile_size * 2.6
				trap["arrows"] = [
					{"pos": center + axis * reach, "vel": -axis * speed},
					{"pos": center - axis * reach, "vel": axis * speed},
				]
		ACTIVE:
			trap["time"] = float(trap["time"]) - delta
			var alive: Array = []
			for arrow in trap["arrows"]:
				arrow["pos"] = Vector2(arrow["pos"]) + Vector2(arrow["vel"]) * delta
				if Vector2(arrow["pos"]).distance_to(_player.global_position) <= 11.0:
					return true
				if _world_is_floor(Vector2(arrow["pos"])):
					alive.append(arrow)
			trap["arrows"] = alive
			if trap["time"] <= 0.0 or alive.is_empty():
				trap["state"] = SPENT
	return false


## Rolling boulder. Hidden until the player is near, then a rock rolls down the
## corridor (toward the player) until it hits a wall — outrun it or duck aside.
func _update_boulder(trap: Dictionary, delta: float) -> bool:
	match int(trap["state"]):
		HIDDEN:
			if _distance_to_player(trap) <= 64.0:
				trap["state"] = ACTIVE
				trap["time"] = 4.5
				var center: Vector2 = trap["center"]
				var dir: Vector2 = trap["direction"]
				# Roll toward the player along the corridor.
				if (_player.global_position - center).dot(dir) < 0.0:
					dir = -dir
				trap["roll"] = dir
				trap["boulder"] = center
		ACTIVE:
			trap["time"] = float(trap["time"]) - delta
			var roll: Vector2 = trap["roll"]
			var speed := 150.0 + int(trap["level"]) * 4.0
			trap["boulder"] = Vector2(trap["boulder"]) + roll * speed * delta
			if Vector2(trap["boulder"]).distance_to(_player.global_position) <= 16.0:
				return true
			var ahead := Vector2(trap["boulder"]) + roll * (_tile_size * 0.5)
			if not _world_is_floor(ahead) or trap["time"] <= 0.0:
				trap["state"] = SPENT
	return false


func _dart_has_target(trap: Dictionary) -> bool:
	var cell: Vector2i = trap["cell"]
	var player_cell := _world_to_cell(_player.global_position)
	if cell.x != player_cell.x and cell.y != player_cell.y:
		return false
	if _cell_center(cell).distance_to(_player.global_position) > 170.0:
		return false
	var step := Vector2i(signi(player_cell.x - cell.x), signi(player_cell.y - cell.y))
	var current := cell + step
	while current != player_cell:
		if not _grid_is_floor(current):
			return false
		current += step
	return true


func _best_floor_direction(cell: Vector2i, variant: int) -> Vector2:
	var directions: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
	var best: Vector2i = directions[variant % directions.size()]
	var best_length := -1
	for offset in directions.size():
		var direction: Vector2i = directions[(variant + offset) % directions.size()]
		var run := 0
		for distance in range(1, 4):
			if not _grid_is_floor(cell + direction * distance):
				break
			run += 1
		if run > best_length:
			best = direction
			best_length = run
	return Vector2(best)


func _distance_to_player(trap: Dictionary) -> float:
	return Vector2(trap["center"]).distance_to(_player.global_position)


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * _tile_size + _tile_size * 0.5, cell.y * _tile_size + _tile_size * 0.5)


func _world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / _tile_size), floori(world_position.y / _tile_size))


func _world_is_floor(world_position: Vector2) -> bool:
	return _grid_is_floor(_world_to_cell(world_position))


func _grid_is_floor(cell: Vector2i) -> bool:
	return (
		cell.x >= 0 and cell.y >= 0 and cell.x < _grid.size()
		and cell.y < _grid[cell.x].size() and _grid[cell.x][cell.y] == 0
	)


func _laser_in_range(trap: Dictionary) -> bool:
	var segment := _laser_segment(trap)
	return _point_segment_distance(_player.global_position, segment[0], segment[1]) <= 46.0


func _laser_segment(trap: Dictionary) -> Array[Vector2]:
	var center: Vector2 = trap["center"]
	var axis := Vector2.RIGHT if int(trap["variant"]) % 2 == 0 else Vector2.DOWN
	var half := _tile_size * 0.47
	return [center - axis * half, center + axis * half]


func _fire_segment(trap: Dictionary) -> Array[Vector2]:
	var center: Vector2 = trap["center"]
	var direction: Vector2 = trap["direction"]
	return [center + direction * 5.0, center + direction * _tile_size * 2.6]


func _saw_position(trap: Dictionary) -> Vector2:
	var center: Vector2 = trap["center"]
	var axis := Vector2.RIGHT if int(trap["variant"]) % 2 == 0 else Vector2.DOWN
	var speed := 2.2 + int(trap["level"]) * 0.075
	return center + axis * sin(float(trap["phase"]) * speed) * _tile_size * 0.72


static func _point_segment_distance(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.001:
		return point.distance_to(start)
	var amount := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * amount)


func _draw() -> void:
	for trap in _traps:
		# Hidden traps are completely invisible — nothing hints at them until they
		# spring. This is the core of the "Trap Adventure" surprise.
		if int(trap["state"]) == HIDDEN:
			continue
		match String(trap["type"]):
			TYPE_SPIKE:
				_draw_spike(trap)
			TYPE_MINE:
				_draw_mine(trap)
			TYPE_DART:
				_draw_dart(trap)
			TYPE_LASER:
				_draw_laser(trap)
			TYPE_CRUSHER:
				_draw_crusher(trap)
			TYPE_SAW:
				_draw_saw(trap)
			TYPE_TELEPORT:
				_draw_teleport(trap)
			TYPE_FIRE:
				_draw_fire(trap)
			TYPE_ARROW:
				_draw_arrow(trap)
			TYPE_BOULDER:
				_draw_boulder(trap)


func _draw_arrow(trap: Dictionary) -> void:
	var center: Vector2 = trap["center"]
	var axis: Vector2 = trap["direction"]
	# Plate that just revealed itself.
	_draw_plate(center, Color("#7a5cff"))
	if int(trap["state"]) == ARMING:
		# A brief warning glint along the firing line.
		draw_line(center - axis * _tile_size * 0.4, center + axis * _tile_size * 0.4,
			Color("#ffd166"), 2.0)
	elif int(trap["state"]) == ACTIVE:
		for arrow in trap.get("arrows", []):
			var pos := Vector2(arrow["pos"])
			var dir := Vector2(arrow["vel"]).normalized()
			var perp := Vector2(-dir.y, dir.x)
			draw_line(pos - dir * 7.0, pos + dir * 5.0, Color("#f4f0ff"), 2.0)
			draw_colored_polygon(PackedVector2Array([
				pos + dir * 6.0, pos - dir * 1.0 + perp * 3.0, pos - dir * 1.0 - perp * 3.0,
			]), Color("#ff5d8f"))


func _draw_boulder(trap: Dictionary) -> void:
	if int(trap["state"]) != ACTIVE:
		return
	var pos := Vector2(trap["boulder"])
	draw_circle(pos + Vector2(0, 3), 13.0, Color(0, 0, 0, 0.28))   # shadow
	draw_circle(pos, 13.0, Color("#5a524b"))   # dark rim
	draw_circle(pos, 11.5, Color("#8b8178"))   # rock body
	draw_arc(pos, 11.5, 0.0, TAU, 18, Color("#cdc3b8"), 2.0)
	# A couple of rotating cracks so it reads as rolling.
	var spin := float(trap["phase"]) * 6.0
	for c in 3:
		var a := spin + c * TAU / 3.0
		draw_line(pos, pos + Vector2.from_angle(a) * 9.0, Color("#5a524b"), 2.0)


func _draw_spike(trap: Dictionary) -> void:
	var center: Vector2 = trap["center"]
	var state := int(trap["state"])
	_draw_plate(center, Color(0.42, 0.10, 0.12, 0.55 if state == HIDDEN else 0.95))
	if state == ARMING:
		_draw_spike_teeth(center, Color("#ffb347"), 0.45)
	elif state == ACTIVE:
		_draw_spike_teeth(center, Color("#f7f1e3"), 1.0)
	elif state == SPENT:
		_draw_spike_teeth(center, Color("#514b57"), 0.3)


func _draw_mine(trap: Dictionary) -> void:
	var center: Vector2 = trap["center"]
	var state := int(trap["state"])
	draw_circle(center, 10.0, Color("#292331"))
	draw_arc(center, 10.0, 0.0, TAU, 16, Color("#ffcf4a"), 2.0)
	draw_line(center - Vector2(5, 0), center + Vector2(5, 0), Color("#ff675b"), 2.0)
	draw_line(center - Vector2(0, 5), center + Vector2(0, 5), Color("#ff675b"), 2.0)
	if state == ARMING:
		draw_circle(center, 4.0 + sin(float(trap["phase"]) * 22.0) * 2.0, Color("#ffffff"))
	elif state == ACTIVE:
		draw_circle(center, 42.0, Color(1.0, 0.25, 0.10, 0.32), false, 4.0)
	elif state == SPENT:
		draw_line(center - Vector2(8, 8), center + Vector2(8, 8), Color("#665b69"), 3.0)


func _draw_dart(trap: Dictionary) -> void:
	var center: Vector2 = trap["center"]
	var state := int(trap["state"])
	draw_rect(Rect2(center - Vector2(8, 8), Vector2(16, 16)), Color("#562b72"), true)
	draw_circle(center, 4.0, Color("#ff8ef4"))
	if state == ACTIVE:
		var projectile: Vector2 = trap["projectile"]
		var velocity: Vector2 = trap["velocity"]
		var direction := velocity.normalized()
		draw_line(projectile - direction * 8.0, projectile + direction * 5.0, Color("#f8f4ff"), 3.0)
		draw_circle(projectile + direction * 5.0, 2.5, Color("#ff4f9a"))
	elif state == SPENT:
		draw_circle(center, 4.0, Color("#51445d"))


func _draw_laser(trap: Dictionary) -> void:
	var segment := _laser_segment(trap)
	var active := int(trap["state"]) == ACTIVE
	var color := Color("#ff315d") if active else Color(1.0, 0.25, 0.45, 0.28)
	draw_circle(segment[0], 5.0, Color("#511735"))
	draw_circle(segment[1], 5.0, Color("#511735"))
	draw_line(segment[0], segment[1], color, 5.0 if active else 2.0)
	if active:
		draw_line(segment[0], segment[1], Color.WHITE, 1.5)


func _draw_crusher(trap: Dictionary) -> void:
	var center: Vector2 = trap["center"]
	var state := int(trap["state"])
	var half := 12.0
	if state == HIDDEN:
		draw_rect(Rect2(center - Vector2(half, half), Vector2(24, 24)), Color(0.1, 0.1, 0.12, 0.28), false, 2.0)
	elif state == ARMING:
		draw_rect(Rect2(center - Vector2(half, half), Vector2(24, 24)), Color(0.05, 0.05, 0.08, 0.62), true)
		draw_line(center - Vector2(10, 10), center + Vector2(10, 10), Color("#ffd166"), 2.0)
		draw_line(center + Vector2(10, -10), center + Vector2(-10, 10), Color("#ffd166"), 2.0)
	elif state == ACTIVE:
		draw_rect(Rect2(center - Vector2(15, 15), Vector2(30, 30)), Color("#5b6070"), true)
		draw_rect(Rect2(center - Vector2(15, 15), Vector2(30, 30)), Color("#e8e8ef"), false, 3.0)
	else:
		draw_rect(Rect2(center - Vector2(12, 12), Vector2(24, 24)), Color("#252832"), true)


func _draw_saw(trap: Dictionary) -> void:
	var center := _saw_position(trap)
	var rotation := float(trap["phase"]) * 5.0
	for tooth in 8:
		var angle := rotation + tooth * TAU / 8.0
		var tip := center + Vector2.from_angle(angle) * 15.0
		var left := center + Vector2.from_angle(angle - 0.22) * 9.0
		var right := center + Vector2.from_angle(angle + 0.22) * 9.0
		draw_colored_polygon(PackedVector2Array([left, tip, right]), Color("#e7edf2"))
	draw_circle(center, 10.0, Color("#6b7280"))
	draw_circle(center, 3.5, Color("#ff4757"))


func _draw_teleport(trap: Dictionary) -> void:
	var center: Vector2 = trap["center"]
	var pulse := 1.0 + sin(float(trap["phase"]) * 5.0) * 0.15
	draw_circle(center, 12.0 * pulse, Color(0.15, 0.85, 1.0, 0.18), true)
	draw_arc(center, 11.0 * pulse, 0.0, TAU, 20, Color("#43e2ff"), 2.0)
	draw_arc(center, 6.0, float(trap["phase"]), float(trap["phase"]) + PI * 1.5, 12, Color.WHITE, 2.0)
	if int(trap["state"]) == ACTIVE:
		draw_circle(center, 16.0, Color(0.45, 0.95, 1.0, 0.35), false, 3.0)


func _draw_fire(trap: Dictionary) -> void:
	var center: Vector2 = trap["center"]
	var direction: Vector2 = trap["direction"]
	draw_circle(center, 8.0, Color("#592f20"))
	draw_line(center - direction * 5.0, center + direction * 8.0, Color("#ff9f43"), 4.0)
	var segment := _fire_segment(trap)
	if int(trap["state"]) == ACTIVE:
		var side := Vector2(-direction.y, direction.x)
		var flame := PackedVector2Array([
			segment[0] - side * 7.0, segment[1], segment[0] + side * 7.0,
		])
		draw_colored_polygon(flame, Color(1.0, 0.24, 0.05, 0.72))
		draw_line(segment[0], segment[1], Color("#ffd166"), 4.0)
	else:
		draw_line(segment[0], segment[0].lerp(segment[1], 0.35), Color(1.0, 0.5, 0.1, 0.25), 2.0)


func _draw_plate(center: Vector2, color: Color) -> void:
	var half := _tile_size * 0.34
	draw_rect(Rect2(center - Vector2(half, half), Vector2(half * 2.0, half * 2.0)), color, false, 2.0)
	draw_circle(center, 1.5, color)


func _draw_spike_teeth(center: Vector2, color: Color, height: float) -> void:
	var outer := _tile_size * 0.34
	var inner := _tile_size * (0.10 + 0.12 * height)
	var points: Array[PackedVector2Array] = [
		PackedVector2Array([center + Vector2(-outer, -outer), center + Vector2(-2, -outer), center + Vector2(-inner, -inner)]),
		PackedVector2Array([center + Vector2(outer, -outer), center + Vector2(2, -outer), center + Vector2(inner, -inner)]),
		PackedVector2Array([center + Vector2(-outer, outer), center + Vector2(-2, outer), center + Vector2(-inner, inner)]),
		PackedVector2Array([center + Vector2(outer, outer), center + Vector2(2, outer), center + Vector2(inner, inner)]),
	]
	for polygon in points:
		draw_colored_polygon(polygon, color)
