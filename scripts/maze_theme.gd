class_name MazeTheme
extends RefCounted

## Visual theme catalogue. Each difficulty tier maps to one theme; themes cycle
## once you pass the last one, so difficulty can scale forever while the look
## keeps rotating. `animated` themes get the energy_wall shader (glowing,
## moving) applied to their walls.

## "tint" is a representative accent colour (the friendly top of each theme's
## backdrop gradient, see game_background.gd PALETTES) used to colour the
## level-select chapter cards so players see which look each chapter wears.
##
## Twelve biomes: campaign chapters cycle through them (chapter % 12) and each
## chapter additionally gets a unique accent tint + decoration set + lighting
## colour, so even two chapters sharing a biome look distinct.
const THEMES := [
	{"id": "grove",    "name": "Verdant Grove",  "animated": false, "step": "grass",
		"tint": Color("#8fd6ad")},
	{"id": "cavern",   "name": "Cavern Depths",  "animated": false, "step": "gravel",
		"tint": Color("#5b82a6")},
	{"id": "fortress", "name": "Stone Fortress", "animated": false, "step": "stone",
		"tint": Color("#d8b27a")},
	{"id": "circuit",  "name": "Live Circuit",   "animated": true,  "step": "metal",
		"glow": Color("#43e2ff"), "glow_speed": 5.0, "tint": Color("#56b6ec")},
	{"id": "frost",    "name": "Frostbound",     "animated": false, "step": "ice",
		"tint": Color("#b4ddf2")},
	{"id": "ember",    "name": "Ember Core",     "animated": true,  "step": "ember",
		"glow": Color("#ff8a3c"), "glow_speed": 3.0, "tint": Color("#f2ab63")},
	{"id": "ruins",    "name": "Sunbaked Ruins", "animated": false, "step": "sand",
		"tint": Color("#d9c27a")},
	{"id": "swamp",    "name": "Mire Hollow",    "animated": false, "step": "mud",
		"tint": Color("#8aa15c")},
	{"id": "catacomb", "name": "The Catacombs",  "animated": false, "step": "bone",
		"tint": Color("#c9c2a8")},
	{"id": "volcanic", "name": "Molten Hollow",  "animated": true,  "step": "ash",
		"glow": Color("#ff5a2a"), "glow_speed": 4.0, "tint": Color("#c4632f")},
	{"id": "crystal",  "name": "Crystal Cavern", "animated": true,  "step": "crystal",
		"glow": Color("#b66bff"), "glow_speed": 2.5, "tint": Color("#b48cf0")},
	{"id": "sunken",   "name": "Sunken Vault",   "animated": false, "step": "water",
		"tint": Color("#6fcfc4")},
]


## Theme dictionary for a given tier (1-based). Cycles past the last theme.
static func for_tier(tier: int) -> Dictionary:
	return THEMES[(maxi(tier, 1) - 1) % THEMES.size()]


## Theme for a CLASSIC campaign level. Each chapter of 10 levels shares one theme;
## chapters cycle through the catalogue so the look keeps rotating forever.
static func for_campaign_level(level: int) -> Dictionary:
	var chapter := (maxi(level, 1) - 1) / 10
	return THEMES[chapter % THEMES.size()]


## A vivid per-chapter accent colour. Deterministic and spread by the golden
## ratio so consecutive chapters look clearly different; used to recolour the
## exit beacon and to lean the ambient + tile tint. Two chapters of the same
## biome therefore still read as distinct.
static func chapter_accent(chapter: int) -> Color:
	var hue := fposmod(float(maxi(chapter, 0)) * 0.61803, 1.0)
	return Color.from_hsv(hue, 0.55, 1.0)


## Multiply colour for the world CanvasModulate in a DARK map: leans toward the
## biome tint but stays bright (~0.6) so the maze is ALWAYS readable — lights add
## the highlights.
static func ambient_for(theme: Dictionary) -> Color:
	var tint: Color = theme.get("tint", Color("#8fd6ad"))
	var base := Color(0.56, 0.58, 0.68)
	return base.lerp(Color(tint.r, tint.g, tint.b) * 0.85, 0.30)


## Multiply colour for a DAYLIGHT map: nearly full brightness with a faint biome
## lean, so the map reads as lit by day (lights become subtle accents).
static func daylight_for(theme: Dictionary) -> Color:
	var tint: Color = theme.get("tint", Color("#8fd6ad"))
	return Color(0.96, 0.96, 0.99).lerp(Color(tint.r, tint.g, tint.b), 0.12)


## All theme ids, in order.
static func ids() -> Array:
	var out: Array = []
	for t in THEMES:
		out.append(t.id)
	return out
