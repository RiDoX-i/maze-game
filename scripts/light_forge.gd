class_name LightForge
extends RefCounted

## Procedural chunky radial light texture shared by every PointLight2D in the
## game. The falloff is POSTERIZED into a few discrete rings and the source
## texture is small, so lights read as blocky pixel glows that match the art —
## not soft photographic blur. One texture is cached and reused (tinted per light
## via PointLight2D.color), so dozens of lights cost almost nothing.

const SIZE := 64
const STEPS := 5   ## Number of discrete brightness rings.

static var _tex: ImageTexture


## The shared posterized radial light texture (white; tint via the light's color).
static func radial() -> Texture2D:
	if _tex != null:
		return _tex
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var c := (SIZE - 1) * 0.5
	for y in SIZE:
		for x in SIZE:
			var d := Vector2(x - c, y - c).length() / c   # 0 centre .. 1 edge
			var b := clampf(1.0 - d, 0.0, 1.0)
			b = b * b                                       # soft, bright core
			var stepped := floorf(b * STEPS) / float(STEPS) # posterize -> rings
			img.set_pixel(x, y, Color(stepped, stepped, stepped, stepped))
	_tex = ImageTexture.create_from_image(img)
	return _tex


## Build a ready-to-use PointLight2D with the shared texture, tinted and scaled to
## roughly [param radius_px]. Shadows are off (no casters) for cheap mobile lighting.
static func make_light(color: Color, radius_px: float, energy: float = 1.0) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = radial()
	light.color = color
	light.energy = energy
	light.texture_scale = (radius_px * 2.0) / float(SIZE)
	light.shadow_enabled = false
	return light
