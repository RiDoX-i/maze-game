class_name PixelIcons
extends RefCounted

## Small procedural pixel-art UI icons (hearts), cached. White glint on filled
## hearts; dim grey for empty slots.

const HEART := [
	"0110110",
	"1111111",
	"1111111",
	"0111110",
	"0011100",
	"0001000",
]

const PAUSE := [
	"11011",
	"11011",
	"11011",
	"11011",
	"11011",
	"11011",
]

static var _cache: Dictionary = {}


## Two-bar pause glyph for the HUD pause button.
static func pause(scale: int = 4) -> ImageTexture:
	var key := "pause_%d" % scale
	if _cache.has(key):
		return _cache[key]
	var w := 5
	var h := 6
	var img := Image.create(w * scale, h * scale, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for ry in h:
		for rx in w:
			if PAUSE[ry][rx] == "1":
				img.fill_rect(Rect2i(rx * scale, ry * scale, scale, scale), Color("#f3eeff"))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func heart(filled: bool, scale: int = 4) -> ImageTexture:
	var key := "%s_%d" % ["f" if filled else "e", scale]
	if _cache.has(key):
		return _cache[key]

	var w := 7
	var h := 6
	var img := Image.create(w * scale, h * scale, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var fill := Color("#ef476f") if filled else Color("#454b61")
	for ry in h:
		for rx in w:
			if HEART[ry][rx] == "1":
				img.fill_rect(Rect2i(rx * scale, ry * scale, scale, scale), fill)
	if filled:  # glint
		img.fill_rect(Rect2i(1 * scale, 1 * scale, scale, scale), Color("#ffd7e0"))

	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
