class_name FootstepForge
extends RefCounted

## Subtle, soft footstep bank for the six maze floor materials.
##
## Deliberately gentle: each step is a short, low, rounded "tap" — a soft body
## thump plus a brief low-passed puff of texture — never a harsh click or
## cartoonish slap. Four deterministic variants per surface keep running from
## repeating the exact same sample, with no bundled audio files.

const RATE := 44100
const VARIANT_COUNT := 4
const FADE_SECONDS := 0.010
const SURFACES := ["grass", "gravel", "stone", "metal", "ice", "ember",
	"sand", "mud", "bone", "ash", "crystal", "water"]
const TARGET_PEAK := 0.5   ## Normalisation ceiling — keeps steps quiet and even.

static var _cache: Dictionary = {}


## Return one cached variation for a surface. Unknown surfaces safely use stone.
static func get_step(surface: String, variant: int = 0) -> AudioStreamWAV:
	var safe_surface := _safe_surface(surface)
	var safe_variant := absi(variant) % VARIANT_COUNT
	var key := "%s:%d" % [safe_surface, safe_variant]
	if not _cache.has(key):
		_cache[key] = _make(safe_surface, safe_variant)
	return _cache[key]


## Warm and return the complete variation bank for a surface.
static func get_steps(surface: String) -> Array[AudioStreamWAV]:
	var result: Array[AudioStreamWAV] = []
	for variant in VARIANT_COUNT:
		result.append(get_step(surface, variant))
	return result


static func surface_names() -> PackedStringArray:
	return PackedStringArray(SURFACES)


static func supports(surface: String) -> bool:
	return SURFACES.has(surface)


static func _safe_surface(surface: String) -> String:
	return surface if supports(surface) else "stone"


## Per-surface tone. Everything is intentionally low and short:
##   body_*   a soft sine thump (the weight of the footfall)
##   puff_*   a brief low-passed noise breath (the texture of the floor)
## Hard floors get a touch more body and a slightly brighter (but still soft)
## puff; soft floors are duller and quieter.
static func _params(surface: String) -> Dictionary:
	match surface:
		"grass":
			return {"dur": 0.085, "gain": 0.80,
				"body_freq": 132.0, "body_gain": 0.22, "body_tau": 0.022,
				"puff_gain": 0.26, "puff_lp": 0.16, "puff_tau": 0.020}
		"gravel":
			return {"dur": 0.095, "gain": 0.88,
				"body_freq": 150.0, "body_gain": 0.24, "body_tau": 0.020,
				"puff_gain": 0.34, "puff_lp": 0.30, "puff_tau": 0.018}
		"metal":
			return {"dur": 0.090, "gain": 0.82,
				"body_freq": 188.0, "body_gain": 0.30, "body_tau": 0.026,
				"puff_gain": 0.18, "puff_lp": 0.40, "puff_tau": 0.012}
		"ice":
			return {"dur": 0.080, "gain": 0.80,
				"body_freq": 205.0, "body_gain": 0.20, "body_tau": 0.016,
				"puff_gain": 0.22, "puff_lp": 0.46, "puff_tau": 0.010}
		"ember":
			return {"dur": 0.100, "gain": 0.86,
				"body_freq": 110.0, "body_gain": 0.32, "body_tau": 0.030,
				"puff_gain": 0.20, "puff_lp": 0.20, "puff_tau": 0.022}
		"sand": # dry, dull, powdery scuff.
			return {"dur": 0.088, "gain": 0.80,
				"body_freq": 140.0, "body_gain": 0.20, "body_tau": 0.020,
				"puff_gain": 0.30, "puff_lp": 0.22, "puff_tau": 0.018}
		"mud": # wet, low, squelchy.
			return {"dur": 0.105, "gain": 0.84,
				"body_freq": 105.0, "body_gain": 0.26, "body_tau": 0.028,
				"puff_gain": 0.32, "puff_lp": 0.12, "puff_tau": 0.024}
		"bone": # hard, hollow, dry click.
			return {"dur": 0.082, "gain": 0.82,
				"body_freq": 220.0, "body_gain": 0.28, "body_tau": 0.018,
				"puff_gain": 0.16, "puff_lp": 0.50, "puff_tau": 0.010}
		"ash": # soft, muffled, powdery.
			return {"dur": 0.092, "gain": 0.80,
				"body_freq": 120.0, "body_gain": 0.22, "body_tau": 0.024,
				"puff_gain": 0.28, "puff_lp": 0.18, "puff_tau": 0.020}
		"crystal": # bright, glassy, light.
			return {"dur": 0.080, "gain": 0.80,
				"body_freq": 235.0, "body_gain": 0.22, "body_tau": 0.015,
				"puff_gain": 0.20, "puff_lp": 0.52, "puff_tau": 0.010}
		"water": # shallow wet splash.
			return {"dur": 0.100, "gain": 0.82,
				"body_freq": 125.0, "body_gain": 0.20, "body_tau": 0.024,
				"puff_gain": 0.34, "puff_lp": 0.14, "puff_tau": 0.022}
		_: # stone: a clean, soft, dry tap.
			return {"dur": 0.085, "gain": 0.85,
				"body_freq": 165.0, "body_gain": 0.30, "body_tau": 0.022,
				"puff_gain": 0.20, "puff_lp": 0.28, "puff_tau": 0.014}


static func _make(surface: String, variant: int) -> AudioStreamWAV:
	var p := _params(surface)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_softstep_%d" % [surface, variant])

	# Tiny per-take changes keep the bank organic without changing its material.
	var dur: float = p["dur"] * rng.randf_range(0.95, 1.06)
	var gain: float = p["gain"] * rng.randf_range(0.94, 1.03)
	var pitch: float = rng.randf_range(0.95, 1.05)
	var body_freq: float = p["body_freq"] * pitch
	var body_gain: float = p["body_gain"] * rng.randf_range(0.9, 1.08)
	var body_tau: float = p["body_tau"]
	var puff_gain: float = p["puff_gain"] * rng.randf_range(0.9, 1.08)
	var puff_lp: float = p["puff_lp"]
	var puff_tau: float = p["puff_tau"]
	var attack := 0.004   ## Rounded onset — no sharp click.

	var sample_count := int(RATE * dur)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)

	var puff_low := 0.0
	var peak := 0.001
	for i in sample_count:
		var t := float(i) / RATE
		# Soft sine body that slides down a little in pitch as it decays.
		var freq := body_freq * (1.0 - 0.18 * (t / dur))
		var body := sin(TAU * freq * t) * exp(-t / body_tau) * body_gain
		# Brief low-passed noise puff (floor texture), gentle.
		puff_low += (rng.randf_range(-1.0, 1.0) - puff_low) * puff_lp
		var puff := puff_low * exp(-t / puff_tau) * puff_gain

		var env := minf(t / attack, 1.0)
		var remaining := dur - t
		if remaining < FADE_SECONDS:
			env *= maxf(remaining / FADE_SECONDS, 0.0)

		var value := (body + puff) * env * gain
		samples[i] = value
		peak = maxf(peak, absf(value))

	# Normalise every step to the same quiet ceiling so no surface jumps out.
	var scale := TARGET_PEAK / peak
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var value := clampf(samples[i] * scale, -TARGET_PEAK, TARGET_PEAK)
		data.encode_s16(i * 2, int(value * 32767.0))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
