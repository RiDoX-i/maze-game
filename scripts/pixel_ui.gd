class_name PixelUI
extends RefCounted

## Procedural chunky pixel-art UI skin. Generates 9-patch button / panel
## textures (no art assets) and a shared [Theme] so every Button in the game gets
## the same crisp, beveled, pixelated look. Apply once per scene with
## [method apply] on the root Control.

# Palette (matches the existing purple menu identity).
const OUTLINE := Color("#0d0a1a")
const BASE := Color("#3a2c66")
const LIGHT := Color("#6c5cef")
const DARK := Color("#221a3d")
const BASE_H := Color("#4a3a85")
const LIGHT_H := Color("#8a78ff")
const DARK_H := Color("#2c2150")
const PANEL_BASE := Color("#1d1738")
const PANEL_LIGHT := Color("#4a3a85")
const PANEL_DARK := Color("#0e0a1f")

const TEX := 32   ## Source texture size in px.
const BEVEL := 8   ## Beveled/outlined border kept in the 9-patch margin.

static var _theme: Theme
static var _tex_cache: Dictionary = {}


## Set the shared pixel theme on a scene and force crisp (nearest) filtering on
## all its UI. Call from the root Control's _ready().
static func apply(root: Control) -> void:
	root.theme = theme()
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Shared Button theme (cached). Buttons inherit it from the scene root.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	_theme.set_stylebox("normal", "Button", button_style("normal"))
	_theme.set_stylebox("hover", "Button", button_style("hover"))
	_theme.set_stylebox("pressed", "Button", button_style("pressed"))
	_theme.set_stylebox("focus", "Button", button_style("hover"))
	_theme.set_stylebox("disabled", "Button", button_style("disabled"))
	return _theme


## A 9-patch button stylebox for the given visual state.
static func button_style(state: String) -> StyleBoxTexture:
	var base := BASE
	var light := LIGHT
	var dark := DARK
	var pressed := false
	match state:
		"hover":
			base = BASE_H; light = LIGHT_H; dark = DARK_H
		"pressed":
			base = DARK; light = DARK_H; dark = LIGHT; pressed = true
		"disabled":
			base = Color("#2a2740"); light = Color("#3a3656"); dark = Color("#1a1830")
	return _make_box(base, light, dark, pressed, 20, 12)


## A 9-patch panel stylebox for overlays (pause / records / name entry).
static func panel_style() -> StyleBoxTexture:
	return _make_box(PANEL_BASE, PANEL_LIGHT, PANEL_DARK, false, 22, 22)


# --- Internals -------------------------------------------------------------

static func _make_box(base: Color, light: Color, dark: Color, pressed: bool,
		pad_x: int, pad_y: int) -> StyleBoxTexture:
	var key := "%s_%s_%s_%s" % [base, light, dark, pressed]
	var tex: ImageTexture
	if _tex_cache.has(key):
		tex = _tex_cache[key]
	else:
		tex = _bevel_texture(base, light, dark, pressed)
		_tex_cache[key] = tex

	var box := StyleBoxTexture.new()
	box.texture = tex
	box.texture_margin_left = BEVEL
	box.texture_margin_right = BEVEL
	box.texture_margin_top = BEVEL
	box.texture_margin_bottom = BEVEL
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	box.content_margin_top = pad_y
	box.content_margin_bottom = pad_y
	return box


static func _bevel_texture(base: Color, light: Color, dark: Color, pressed: bool) -> ImageTexture:
	var img := Image.create(TEX, TEX, false, Image.FORMAT_RGBA8)
	for y in TEX:
		for x in TEX:
			var lx := x
			var ty := y
			var rx := TEX - 1 - x
			var by := TEX - 1 - y
			var edge: int = mini(mini(lx, rx), mini(ty, by))
			var col := base
			if edge == 0:
				col = OUTLINE
			elif edge < BEVEL:
				# Top/left catch the light, bottom/right fall into shadow.
				var top_left: int = mini(lx, ty)
				var bot_right: int = mini(rx, by)
				col = light if top_left <= bot_right else dark
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
