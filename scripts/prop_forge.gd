class_name PropForge
extends RefCounted

## Procedural pixel-art DECORATIONS scattered through the mazes (skeletons, treasure
## "fortunes", shrines/statues "art places", torches, mushrooms, crystals, …).
##
## Same chunky "fat-pixel" language as [CharacterVisual]: every prop is a list of
## [lx, ly, w, h, Color] rects in logical pixels, with the ORIGIN at the prop's
## ground-contact point (so props grow upward into -y and sit on the floor). No
## texture assets — [DecorationLayer] draws these with draw_rect.
##
## Each biome has its own prop roster so decorations suit the theme, and some
## props emit light (torch/campfire/lantern/mushrooms/crystal/lavarock) — the
## layer gives those a PointLight2D so they actually glow.

# --- Palette ---------------------------------------------------------------
const BONE := Color("#ded7c2")
const BONE_D := Color("#a89f87")
const WOOD := Color("#6b4a2b")
const WOOD_L := Color("#7a5630")
const WOOD_D := Color("#4e3520")
const GOLD := Color("#ffd23f")
const GOLD_L := Color("#fff0a0")
const GOLD_D := Color("#d9a425")
const STONE := Color("#8d8a82")
const STONE_L := Color("#aaa79e")
const STONE_D := Color("#5f5c55")
const GROUND_D := Color("#37332c")
const FLAME_O := Color("#ff8a2c")
const FLAME_Y := Color("#ffe06a")
const FLAME_R := Color("#ff4d2a")
const METAL := Color("#9aa3ad")
const METAL_L := Color("#bcc4cc")
const METAL_D := Color("#5d646c")
const MOSS := Color("#4f9a4a")
const MOSS_D := Color("#2f6e2f")
const CRYSTAL := Color("#c79bff")
const CRYSTAL_L := Color("#e6ccff")
const CRYSTAL_D := Color("#7a5fb0")
const CLOTH := Color("#b5384a")
const CLOTH_L := Color("#d9556a")

## Props every biome can show.
const UNIVERSAL := ["skeleton", "skull", "bones", "chest", "gold", "torch", "lantern"]

## Extra props per biome id (appended to UNIVERSAL).
const BIOME_EXTRAS := {
	"grove":    ["mushrooms", "campfire", "vines", "shrine", "gravestone"],
	"cavern":   ["mushrooms", "campfire", "crystal", "cobweb"],
	"fortress": ["statue", "banner", "pillar", "urn", "shrine"],
	"circuit":  ["crystal", "banner", "pillar"],
	"frost":    ["crystal", "iceshard", "pillar"],
	"ember":    ["lavarock", "campfire", "statue"],
	"ruins":    ["statue", "pillar", "urn", "gravestone", "shrine", "cobweb"],
	"swamp":    ["mushrooms", "vines", "gravestone", "campfire"],
	"catacomb": ["gravestone", "statue", "pillar", "cobweb", "urn", "shrine"],
	"volcanic": ["lavarock", "banner", "statue"],
	"crystal":  ["crystal", "iceshard", "shrine"],
	"sunken":   ["pillar", "crystal", "vines", "urn"],
}

## Props that emit light -> the layer attaches a PointLight2D in this colour.
const LIGHT_COLORS := {
	"torch": Color("#ff9a3c"),
	"campfire": Color("#ff8a2c"),
	"lantern": Color("#ffd86a"),
	"mushrooms": Color("#6affc0"),
	"crystal": Color("#c79bff"),
	"lavarock": Color("#ff6a2a"),
}

## Props that animate (flame flicker / glow pulse) — the layer ticks their frame.
const ANIMATED := ["torch", "campfire", "lavarock"]


## Prop ids available in a biome (UNIVERSAL + its extras).
static func roster_for(theme_id: String) -> Array:
	var out: Array = UNIVERSAL.duplicate()
	out.append_array(BIOME_EXTRAS.get(theme_id, []))
	return out


## Every prop id that exists (for tests / iteration).
static func all_ids() -> Array:
	var seen := {}
	for id in UNIVERSAL:
		seen[id] = true
	for biome in BIOME_EXTRAS:
		for id in BIOME_EXTRAS[biome]:
			seen[id] = true
	return seen.keys()


static func is_light(id: String) -> bool:
	return LIGHT_COLORS.has(id)


static func light_color(id: String) -> Color:
	return LIGHT_COLORS.get(id, Color.WHITE)


static func is_animated(id: String) -> bool:
	return ANIMATED.has(id)


## Sprite for a prop as a list of [lx, ly, w, h, Color] rects (origin = ground
## point). [param frame] only matters for animated props (flame/glow flicker).
static func rects(id: String, frame: int = 0) -> Array:
	match id:
		"skeleton":
			return [
				[-6, -3, 3, 3, BONE], [-5, -2, 1, 1, GROUND_D],   # skull + socket
				[-3, -1, 6, 1, BONE], [-3, 0, 6, 1, BONE_D],      # spine
				[-2, -2, 1, 1, BONE], [0, -2, 1, 1, BONE], [2, -2, 1, 1, BONE],  # ribs
				[3, -1, 3, 1, BONE], [5, -2, 1, 1, BONE_D],       # leg + foot
			]
		"skull":
			return [
				[-2, -4, 4, 3, BONE], [-2, -4, 4, 1, Color("#efe8d4")],
				[-1, -3, 1, 1, GROUND_D], [1, -3, 1, 1, GROUND_D],   # eyes
				[-1, -1, 3, 1, BONE], [-1, 0, 3, 1, BONE_D],         # jaw + teeth gap
			]
		"bones":
			return [
				[-4, -1, 3, 1, BONE], [-4, 0, 4, 1, BONE_D],
				[1, -2, 3, 1, BONE], [3, -1, 1, 1, BONE_D],
				[-2, -2, 1, 1, BONE], [-3, -1, 1, 1, Color("#efe8d4")],
			]
		"gravestone":
			return [
				[-3, -7, 6, 7, STONE], [-3, -7, 6, 1, STONE_L], [2, -7, 1, 7, STONE_D],
				[-1, -6, 2, 4, STONE_D], [-2, -5, 4, 1, STONE_D],   # engraved cross
				[-4, 0, 8, 1, GROUND_D],
			]
		"chest":
			return [
				[-4, -6, 8, 2, WOOD], [-4, -6, 8, 1, WOOD_L],        # lid
				[-4, -4, 8, 4, WOOD], [-4, 0, 8, 1, WOOD_D], [3, -4, 1, 4, WOOD_D],
				[-4, -4, 8, 1, GOLD_D],                              # gold band
				[-1, -5, 2, 2, GOLD], [0, -5, 1, 1, GOLD_L],         # lock
				[-3, -3, 2, 1, GOLD], [1, -3, 2, 1, GOLD],           # gold peeking
			]
		"gold":
			return [
				[-3, -1, 6, 1, GOLD_D], [-2, -2, 4, 1, GOLD], [-1, -3, 2, 1, GOLD_L],
				[2, -1, 1, 1, GOLD], [-3, -1, 1, 1, GOLD], [0, -2, 1, 1, GOLD_L],
			]
		"torch":
			var t: Array = [
				[0, -6, 1, 6, WOOD_D], [-1, -7, 3, 1, METAL_D],     # pole + bowl
			]
			if frame == 0:
				t.append_array([[-1, -10, 3, 3, FLAME_O], [0, -12, 1, 2, FLAME_Y], [0, -9, 1, 1, FLAME_R]])
			else:
				t.append_array([[-1, -9, 3, 3, FLAME_O], [-1, -11, 1, 2, FLAME_Y], [1, -10, 1, 1, FLAME_Y]])
			return t
		"campfire":
			var f: Array = [
				[-4, -1, 8, 2, WOOD], [-4, 0, 8, 1, WOOD_D], [-3, -1, 1, 1, WOOD_L],
				[-5, 0, 1, 1, STONE], [4, 0, 1, 1, STONE],          # ring stones
			]
			if frame == 0:
				f.append_array([[-2, -5, 4, 4, FLAME_O], [-1, -7, 2, 2, FLAME_Y], [0, -4, 1, 1, FLAME_R],
					[-3, -3, 1, 2, FLAME_O], [2, -3, 1, 2, FLAME_O]])
			else:
				f.append_array([[-2, -4, 4, 4, FLAME_O], [-1, -6, 2, 2, FLAME_Y], [-1, -3, 1, 1, FLAME_R],
					[-3, -2, 1, 1, FLAME_O], [2, -3, 1, 2, FLAME_O]])
			return f
		"shrine":
			return [
				[-5, 0, 10, 1, STONE_D], [-4, -1, 8, 1, STONE],     # steps
				[-3, -5, 6, 4, STONE], [-3, -5, 6, 1, STONE_L], [2, -5, 1, 4, STONE_D],  # altar
				[-1, -8, 2, 3, GOLD], [0, -9, 1, 1, GOLD_L],        # gold idol
			]
		"statue":
			return [
				[-3, 0, 6, 1, STONE_D], [-2, -1, 4, 1, STONE],      # pedestal
				[-2, -7, 4, 6, STONE], [-2, -7, 4, 1, STONE_L], [1, -7, 1, 6, STONE_D],  # body
				[-1, -9, 2, 2, STONE], [-1, -9, 2, 1, STONE_L],     # head
				[-3, -6, 1, 3, STONE_D], [2, -6, 1, 3, STONE_D],    # arms
			]
		"banner":
			return [
				[3, -12, 1, 13, WOOD_D],                            # pole
				[-3, -11, 6, 8, CLOTH], [-3, -11, 6, 1, CLOTH_L], [-3, -11, 1, 8, CLOTH_L],
				[-3, -3, 1, 1, CLOTH], [1, -3, 1, 1, CLOTH],        # tattered hem
				[-1, -8, 2, 2, GOLD],                               # emblem
			]
		"mushrooms":
			return [
				[-2, -3, 1, 3, Color("#e8e0c8")], [1, -4, 1, 4, Color("#e8e0c8")],  # stems
				[-3, -5, 3, 2, CLOTH], [0, -6, 3, 2, Color("#d24b6b")],             # caps
				[-2, -5, 1, 1, Color("#fff0f5")], [1, -6, 1, 1, Color("#fff0f5")],  # glow spots
			]
		"crystal":
			return [
				[-2, -6, 2, 6, CRYSTAL], [-2, -6, 1, 6, CRYSTAL_L], [0, -4, 2, 4, CRYSTAL_D],
				[1, -8, 1, 5, CRYSTAL], [-3, -3, 1, 3, CRYSTAL_D], [0, -9, 1, 2, CRYSTAL_L],
			]
		"pillar":
			return [
				[-2, -8, 4, 8, STONE], [-2, -8, 4, 1, STONE_L], [1, -8, 1, 8, STONE_D],
				[0, -9, 2, 1, STONE], [-1, -5, 1, 3, STONE_D],      # broken top + crack
				[-3, -1, 6, 1, STONE_D], [-3, 0, 6, 1, GROUND_D],   # base
			]
		"urn":
			return [
				[-1, -6, 2, 1, WOOD_D],                             # neck
				[-2, -5, 4, 4, Color("#9c5b3a")], [-2, -5, 4, 1, Color("#b56b46")],
				[1, -5, 1, 4, Color("#7a4630")], [-1, -4, 1, 2, Color("#c98a5a")],  # shade + highlight
				[-2, -1, 4, 1, Color("#5e351f")],                   # base
			]
		"cobweb":
			return [
				[-5, -8, 3, 1, Color("#9a9a9a")], [-5, -8, 1, 3, Color("#9a9a9a")],
				[-5, -8, 1, 1, Color("#cfcfcf")], [-4, -7, 1, 1, Color("#cfcfcf")],
				[-3, -6, 1, 1, Color("#bcbcbc")], [-2, -5, 1, 1, Color("#bcbcbc")],
				[-3, -8, 1, 1, Color("#bcbcbc")], [-5, -6, 1, 1, Color("#bcbcbc")],
			]
		"lantern":
			return [
				[0, -8, 1, 8, METAL_D],                             # post
				[-2, -12, 4, 1, METAL_D],                           # top
				[-2, -11, 4, 4, METAL], [-2, -11, 4, 1, METAL_L], [1, -11, 1, 4, METAL_D],
				[-1, -10, 2, 2, FLAME_Y],                           # glass glow
			]
		"vines":
			return [
				[-3, -9, 1, 9, MOSS_D], [0, -9, 1, 7, MOSS], [3, -9, 1, 8, MOSS_D],
				[-3, -4, 1, 1, MOSS], [0, -3, 1, 1, MOSS], [3, -5, 1, 1, MOSS], [-3, -7, 1, 1, MOSS],
			]
		"lavarock":
			var lr: Array = [
				[-3, -3, 6, 3, Color("#2a1a18")], [-3, -3, 6, 1, Color("#3a2420")], [-3, 0, 6, 1, Color("#14100f")],
			]
			if frame == 0:
				lr.append_array([[-2, -2, 1, 1, FLAME_O], [0, -3, 1, 2, FLAME_Y], [2, -1, 1, 1, FLAME_O], [-1, -1, 2, 1, FLAME_R]])
			else:
				lr.append_array([[-2, -2, 1, 1, FLAME_R], [0, -2, 1, 1, FLAME_Y], [2, -2, 1, 1, FLAME_O], [-1, -1, 2, 1, FLAME_O]])
			return lr
		"iceshard":
			return [
				[-1, -7, 2, 7, Color("#bfe6ff")], [-1, -7, 1, 7, Color("#e6f4ff")],
				[0, -5, 2, 5, Color("#8bb8e0")], [1, -9, 1, 4, Color("#bfe6ff")], [-2, -3, 1, 3, Color("#9fc8ec")],
			]
		_:
			return [[-2, -2, 4, 2, STONE], [-2, 0, 4, 1, STONE_D]]
