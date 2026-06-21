class_name TileForge
extends RefCounted

## Procedural pixel-art tile generator. Builds small, tileable 32px textures
## (16 logical "fat pixels" at 2x) for each maze theme — deterministic, editable
## (export to PNG via tools/export_tiles), no external art required.
##
## Design rules for readability ("don't hurt the eye"):
##   * FLOOR is calm and low-contrast; WALLS are detailed.
##   * Floor and wall always differ in BOTH hue and brightness, so corridors
##     read clearly against walls.
##   * Walls get a light/dark bevel for a chunky 3D block look.
##   * Several wall VARIANTS per theme are produced and scattered per-cell so the
##     maze never looks like one tile stamped over and over.

const LOGICAL := 16    ## Logical pixels per side.
const SCALE := 2       ## Upscale -> 32px texture.
const SIZE := LOGICAL * SCALE
const WALL_VARIANTS := 4


## Returns {"floor": ImageTexture, "walls": Array[ImageTexture]}.
static func textures(theme_id: String) -> Dictionary:
	var imgs := images(theme_id)
	var wall_texs: Array = []
	for w in imgs.walls:
		wall_texs.append(ImageTexture.create_from_image(w))
	return {"floor": ImageTexture.create_from_image(imgs.floor), "walls": wall_texs}


## Returns {"floor": Image, "walls": Array[Image]} (used by the exporter).
static func images(theme_id: String) -> Dictionary:
	var floor_img := _floor(theme_id)
	var walls: Array = []
	for v in WALL_VARIANTS:
		walls.append(_wall(theme_id, v))
	return {"floor": floor_img, "walls": walls}


# --- Low-level helpers -----------------------------------------------------

static func _new_img() -> Image:
	return Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)

static func _c(hex: String) -> Color:
	return Color(hex)

static func _blk(img: Image, lx: int, ly: int, col: Color) -> void:
	if lx < 0 or ly < 0 or lx >= LOGICAL or ly >= LOGICAL:
		return
	for dx in SCALE:
		for dy in SCALE:
			img.set_pixel(lx * SCALE + dx, ly * SCALE + dy, col)

static func _noise(img: Image, base: Color, shades: Array, rng: RandomNumberGenerator, chance: float) -> void:
	for ly in LOGICAL:
		for lx in LOGICAL:
			var col := base
			if not shades.is_empty() and rng.randf() < chance:
				col = shades[rng.randi() % shades.size()]
			_blk(img, lx, ly, col)

## Chunky 3D block edge: lit top/left, shaded bottom/right.
static func _bevel(img: Image, light: Color, dark: Color) -> void:
	for i in LOGICAL:
		_blk(img, i, 0, light)
		_blk(img, 0, i, light)
	for i in LOGICAL:
		_blk(img, i, LOGICAL - 1, dark)
		_blk(img, LOGICAL - 1, i, dark)

## Ambient occlusion: deepen the interior toward the bottom-right edges so a run
## of walls reads as stacked 3D cubes (lit from the top-left). Applied to EVERY
## biome on top of the per-tile bevel for a richer, chunkier block look.
static func _ao(img: Image) -> void:
	var depth := SCALE * 3
	for y in SIZE:
		for x in SIZE:
			var edge: int = mini(SIZE - 1 - x, SIZE - 1 - y)
			if edge >= depth:
				continue
			var f := lerpf(0.74, 1.0, float(edge) / float(depth))
			var col := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(col.r * f, col.g * f, col.b * f, col.a))

## Jagged near-vertical bright line (lava vein / rock crack).
static func _vein(img: Image, base_x: int, rng: RandomNumberGenerator, cols: Array) -> void:
	var x := base_x
	for ly in range(1, LOGICAL - 1):
		_blk(img, x, ly, cols[rng.randi() % cols.size()])
		if rng.randf() < 0.45:
			x += (1 if rng.randf() < 0.5 else -1)
		x = clampi(x, 2, LOGICAL - 3)


# --- Floors (calm, distinct from walls) ------------------------------------

static func _floor(theme_id: String) -> Image:
	var img := _new_img()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(theme_id + "_floor")
	match theme_id:
		"grove":  # warm dirt path -> contrasts the green walls
			_noise(img, _c("#6b5436"), [_c("#5c4830"), _c("#7a6242"), _c("#5f4a31")], rng, 0.55)
			for _i in 5:
				_blk(img, rng.randi() % LOGICAL, rng.randi() % LOGICAL, _c("#8a7050"))
		"cavern":  # cool dark slate
			_noise(img, _c("#353844"), [_c("#2c2f39"), _c("#3f4350"), _c("#292b34")], rng, 0.55)
		"fortress":  # cool gray flagstone with grout
			_noise(img, _c("#5a5e6b"), [_c("#4e515d"), _c("#666a78")], rng, 0.45)
			for i in LOGICAL:
				_blk(img, i, 0, _c("#3a3d47"))
				_blk(img, 0, i, _c("#3a3d47"))
				_blk(img, i, 8, _c("#3a3d47"))
				_blk(img, 8, i, _c("#3a3d47"))
		"circuit":  # near-black with faint seams
			_noise(img, _c("#0c0f18"), [_c("#090b12"), _c("#12161f")], rng, 0.4)
			for i in LOGICAL:
				_blk(img, i, 0, _c("#1a2030"))
				_blk(img, 0, i, _c("#1a2030"))
		"frost":  # deep teal ice (dark, so pale walls pop)
			_noise(img, _c("#2b4a66"), [_c("#244056"), _c("#335778"), _c("#21384d")], rng, 0.5)
			for _i in 4:
				_blk(img, rng.randi() % LOGICAL, rng.randi() % LOGICAL, _c("#6fa0c8"))
		"ember":  # cool charcoal (so warm walls pop)
			_noise(img, _c("#1d1c22"), [_c("#16151a"), _c("#26242c")], rng, 0.5)
			for _i in 4:
				_blk(img, rng.randi() % LOGICAL, rng.randi() % LOGICAL, _c("#3a2a2a"))
		"ruins":  # warm sandstone dust
			_noise(img, _c("#cbb178"), [_c("#bda169"), _c("#d8c08a"), _c("#b6985e")], rng, 0.55)
			for _i in 5:
				_blk(img, rng.randi() % LOGICAL, rng.randi() % LOGICAL, _c("#a98f5c"))
		"swamp":  # murky bog floor
			_noise(img, _c("#3d4a2f"), [_c("#33402a"), _c("#465436"), _c("#2c3826")], rng, 0.55)
			for _i in 5:
				_blk(img, rng.randi() % LOGICAL, rng.randi() % LOGICAL, _c("#2b3a3f"))
		"catacomb":  # pale bone-dust flagstone with grout
			_noise(img, _c("#6a6660"), [_c("#5c5852"), _c("#787268")], rng, 0.45)
			for i in LOGICAL:
				_blk(img, i, 0, _c("#47433d"))
				_blk(img, 0, i, _c("#47433d"))
				_blk(img, i, 8, _c("#47433d"))
				_blk(img, 8, i, _c("#47433d"))
		"volcanic":  # dark obsidian (so lava walls pop)
			_noise(img, _c("#17151a"), [_c("#100f13"), _c("#201d26")], rng, 0.5)
			for _i in 4:
				_blk(img, rng.randi() % LOGICAL, rng.randi() % LOGICAL, _c("#5a2a1c"))
		"crystal":  # deep violet rock
			_noise(img, _c("#241a33"), [_c("#1d1429"), _c("#2e2240")], rng, 0.5)
			for _i in 4:
				_blk(img, rng.randi() % LOGICAL, rng.randi() % LOGICAL, _c("#6a4f9a"))
		"sunken":  # dark teal water-stone
			_noise(img, _c("#1f4744"), [_c("#1a3c3a"), _c("#27534f"), _c("#183a37")], rng, 0.5)
			for _i in 4:
				_blk(img, rng.randi() % LOGICAL, rng.randi() % LOGICAL, _c("#5fbfb4"))
		_:
			_noise(img, _c("#353844"), [_c("#2c2f39"), _c("#3f4350")], rng, 0.5)
	return img


# --- Walls (detailed, beveled, several variants) ---------------------------

static func _wall(theme_id: String, variant: int) -> Image:
	# Walls are drawn as chunky 3D blocks: a per-tile bevel (lit top-left, shaded
	# bottom-right) frames each cell so a run of walls reads as stacked blocks.
	var img := _new_img()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_wall_%d" % [theme_id, variant])
	match theme_id:
		"grove":
			_noise(img, _c("#2e7d3a"), [_c("#266b31"), _c("#359245"), _c("#225c2b")], rng, 0.6)
			for _i in 14:  # leaf glints
				_blk(img, rng.randi() % LOGICAL, rng.randi() % LOGICAL, _c("#5cc066"))
			_bevel(img, _c("#4aa852"), _c("#1c4f24"))
		"cavern":
			_noise(img, _c("#8a7a5f"), [_c("#79694f"), _c("#9c8c6f"), _c("#6f6047")], rng, 0.6)
			_vein(img, 7 + (variant % 3), rng, [_c("#5f5240"), _c("#534839")])
			_bevel(img, _c("#b0a07e"), _c("#5f5240"))
		"fortress":
			_bricks(img, _c("#caa882"), _c("#a64b38"), _c("#8a3b2c"), rng)
			_bevel(img, _c("#c25a44"), _c("#6e2c20"))
		"circuit":
			_noise(img, _c("#0d1a14"), [_c("#0e1d16"), _c("#08110d")], rng, 0.5)
			var trace := _c("#2fd6f0")
			for lx in LOGICAL:
				_blk(img, lx, 4, trace)
				_blk(img, lx, 11, trace)
			for ly in LOGICAL:
				_blk(img, 8, ly, trace)
			var nodes := [Vector2i(8, 4), Vector2i(8, 11), Vector2i(3 + variant % 4, 4), Vector2i(11 - variant % 3, 11)]
			for p in nodes:
				_blk(img, p.x, p.y, _c("#aef6ff"))
			_bevel(img, _c("#13241b"), _c("#050d08"))
		"frost":
			_noise(img, _c("#9fc8ec"), [_c("#8bb8e0"), _c("#b6dbff"), _c("#7fabd4")], rng, 0.55)
			for i in LOGICAL:  # crystalline facets
				if (i + variant) % 4 == 0:
					_blk(img, i, i, _c("#e6f4ff"))
					_blk(img, (i + 8) % LOGICAL, i, _c("#d2ebff"))
			_bevel(img, _c("#e6f4ff"), _c("#6f9ec8"))
		"ember":
			_noise(img, _c("#2a1712"), [_c("#341c15"), _c("#1f100c")], rng, 0.55)
			_vein(img, 4 + variant % 2, rng, [_c("#ff7a2e"), _c("#ffc24a"), _c("#ffe08a")])
			_vein(img, 11 - variant % 2, rng, [_c("#ff7a2e"), _c("#ffb24a")])
			_bevel(img, _c("#3e241c"), _c("#160a08"))
		"ruins":
			_bricks(img, _c("#9c7f50"), _c("#caa46e"), _c("#b08f5e"), rng)
			_bevel(img, _c("#e0c189"), _c("#7a5f3a"))
		"swamp":
			_noise(img, _c("#4a5b3a"), [_c("#3e4d32"), _c("#56683f"), _c("#354529")], rng, 0.6)
			for _i in 12:  # moss glints
				_blk(img, rng.randi() % LOGICAL, rng.randi() % LOGICAL, _c("#7fa05a"))
			_vein(img, 6 + variant % 3, rng, [_c("#2f3d28"), _c("#283520")])
			_bevel(img, _c("#6f8a55"), _c("#283318"))
		"catacomb":
			_noise(img, _c("#cfc7ad"), [_c("#bdb59c"), _c("#ddd6bd"), _c("#b1a98f")], rng, 0.55)
			for _i in 10:  # dark sockets/pits, like embedded bone
				_blk(img, 1 + rng.randi() % (LOGICAL - 2), 1 + rng.randi() % (LOGICAL - 2), _c("#5a5446"))
			_bevel(img, _c("#e6dfc6"), _c("#7d7560"))
		"volcanic":
			_noise(img, _c("#211a1f"), [_c("#171216"), _c("#2a2128")], rng, 0.55)
			_vein(img, 4 + variant % 2, rng, [_c("#ff5a2a"), _c("#ffae3c"), _c("#ffe08a")])
			_vein(img, 11 - variant % 2, rng, [_c("#ff5a2a"), _c("#ff8a3c")])
			_bevel(img, _c("#3a2630"), _c("#0c0a0d"))
		"crystal":
			_noise(img, _c("#3a2a5c"), [_c("#33264f"), _c("#46356e"), _c("#2c2046")], rng, 0.55)
			for i in LOGICAL:  # bright crystalline facets (glow flows along these)
				if (i + variant) % 4 == 0:
					_blk(img, i, i, _c("#e6ccff"))
					_blk(img, (i + 8) % LOGICAL, i, _c("#c79bff"))
			_bevel(img, _c("#7a5fb0"), _c("#1d1430"))
		"sunken":
			_noise(img, _c("#2f5a55"), [_c("#28504b"), _c("#386b64"), _c("#214640")], rng, 0.55)
			for _i in 10:  # algae glints
				_blk(img, rng.randi() % LOGICAL, rng.randi() % LOGICAL, _c("#6fcfc4"))
			_vein(img, 7 + variant % 3, rng, [_c("#173a36"), _c("#14322f")])
			_bevel(img, _c("#5a948c"), _c("#143331"))
		_:
			_noise(img, _c("#6b6256"), [_c("#5a5246"), _c("#7c7264")], rng, 0.6)
			_bevel(img, _c("#8a8074"), _c("#3f392f"))
	_ao(img)
	return img


static func _bricks(img: Image, mortar: Color, brick: Color, brick_dark: Color, rng: RandomNumberGenerator) -> void:
	for ly in LOGICAL:
		var row := ly / 4
		var offset := 0 if (row % 2 == 0) else 4
		for lx in LOGICAL:
			var bx := lx + offset
			var is_mortar := (ly % 4 == 0) or (bx % 8 == 0)
			if is_mortar:
				_blk(img, lx, ly, mortar)
			else:
				_blk(img, lx, ly, brick if rng.randf() < 0.82 else brick_dark)
