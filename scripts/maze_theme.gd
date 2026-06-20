class_name MazeTheme
extends RefCounted

## Visual theme catalogue. Each difficulty tier maps to one theme; themes cycle
## once you pass the last one, so difficulty can scale forever while the look
## keeps rotating. `animated` themes get the energy_wall shader (glowing,
## moving) applied to their walls.

const THEMES := [
	{"id": "grove",    "name": "Verdant Grove",  "animated": false, "step": "grass"},
	{"id": "cavern",   "name": "Cavern Depths",  "animated": false, "step": "stone"},
	{"id": "fortress", "name": "Stone Fortress", "animated": false, "step": "stone"},
	{"id": "circuit",  "name": "Live Circuit",   "animated": true,  "step": "metal",
		"glow": Color("#43e2ff"), "glow_speed": 5.0},
	{"id": "frost",    "name": "Frostbound",     "animated": false, "step": "ice"},
	{"id": "ember",    "name": "Ember Core",     "animated": true,  "step": "lava",
		"glow": Color("#ff8a3c"), "glow_speed": 3.0},
]


## Theme dictionary for a given tier (1-based). Cycles past the last theme.
static func for_tier(tier: int) -> Dictionary:
	return THEMES[(maxi(tier, 1) - 1) % THEMES.size()]


## All theme ids, in order.
static func ids() -> Array:
	var out: Array = []
	for t in THEMES:
		out.append(t.id)
	return out
