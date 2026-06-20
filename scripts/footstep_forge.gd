class_name FootstepForge
extends RefCounted

## Synthesizes short, believable footstep sounds procedurally (no audio assets),
## one per ground surface. Real footsteps are broadband *impacts*, not musical
## notes, so each step is built from three physically-motivated layers:
##
##   1. a sharp filtered NOISE TRANSIENT  -> the foot making contact ("click")
##   2. a few short DAMPED PARTIALS       -> the material's resonant colour
##   3. a textured NOISE TAIL             -> the scuff / crunch / sizzle after
##
## Every layer is amplitude-bounded and the mix is clamped, so output can never
## clip or blow up. Deterministic and cached per surface.

const RATE := 44100
const FADE := 0.008  ## Final fade-out (s) so the buffer never ends on a click.

static var _cache: Dictionary = {}


## Footstep stream for a surface: "grass", "stone", "metal", "ice", "lava".
static func get_step(surface: String) -> AudioStreamWAV:
	if not _cache.has(surface):
		_cache[surface] = _make(surface)
	return _cache[surface]


## Per-surface synthesis parameters. Keys:
##   dur, gain, attack                     -- overall length / level / onset
##   burst_gain, burst_tau                 -- contact transient level / decay
##   burst_lp (0..1), burst_hp (0..1)      -- transient tone (low-pass / high-pass)
##   tail_gain, tail_tau, tail_lp, tail_hp -- texture tail (0 gain disables)
##   partials: Array of [freq_hz, decay_tau_s, gain]  -- damped resonant colour
static func _params(surface: String) -> Dictionary:
	match surface:
		"grass":  # soft brushy "fffp", no real pitch
			return {
				"dur": 0.20, "gain": 0.80, "attack": 0.006,
				"burst_gain": 0.45, "burst_tau": 0.012, "burst_lp": 0.70, "burst_hp": 0.25,
				"tail_gain": 0.50, "tail_tau": 0.040, "tail_lp": 0.90, "tail_hp": 0.30,
				"partials": [[200.0, 0.015, 0.06]],
			}
		"metal":  # bright "clank" with an inharmonic ring
			return {
				"dur": 0.26, "gain": 0.70, "attack": 0.0016,
				"burst_gain": 0.40, "burst_tau": 0.0025, "burst_lp": 0.85, "burst_hp": 0.20,
				"tail_gain": 0.08, "tail_tau": 0.020, "tail_lp": 0.90, "tail_hp": 0.30,
				"partials": [[540.0, 0.09, 0.22], [1190.0, 0.06, 0.16],
					[2150.0, 0.04, 0.10], [3300.0, 0.025, 0.06]],
			}
		"ice":    # crisp glassy "tick" with a crackle tail
			return {
				"dur": 0.14, "gain": 0.80, "attack": 0.0012,
				"burst_gain": 0.50, "burst_tau": 0.0016, "burst_lp": 0.95, "burst_hp": 0.40,
				"tail_gain": 0.30, "tail_tau": 0.013, "tail_lp": 0.95, "tail_hp": 0.45,
				"partials": [[2600.0, 0.02, 0.12], [4100.0, 0.012, 0.07]],
			}
		"lava":   # low muffled "thmp" with a soft sizzle
			return {
				"dur": 0.27, "gain": 0.85, "attack": 0.004,
				"burst_gain": 0.50, "burst_tau": 0.006, "burst_lp": 0.20, "burst_hp": 0.0,
				"tail_gain": 0.24, "tail_tau": 0.070, "tail_lp": 0.25, "tail_hp": 0.0,
				"partials": [[70.0, 0.05, 0.40], [130.0, 0.03, 0.18]],
			}
		_:        # "stone" -- soft, dry "tok"
			return {
				"dur": 0.17, "gain": 0.85, "attack": 0.0022,
				"burst_gain": 0.60, "burst_tau": 0.0035, "burst_lp": 0.35, "burst_hp": 0.0,
				"tail_gain": 0.18, "tail_tau": 0.020, "tail_lp": 0.50, "tail_hp": 0.0,
				"partials": [[150.0, 0.03, 0.32], [300.0, 0.013, 0.14]],
			}


static func _make(surface: String) -> AudioStreamWAV:
	var p := _params(surface)
	var dur: float = p["dur"]
	var gain: float = p["gain"]
	var attack: float = p["attack"]
	var burst_gain: float = p["burst_gain"]
	var burst_tau: float = p["burst_tau"]
	var burst_lp: float = p["burst_lp"]
	var burst_hp: float = p["burst_hp"]
	var tail_gain: float = p["tail_gain"]
	var tail_tau: float = p["tail_tau"]
	var tail_lp: float = p["tail_lp"]
	var tail_hp: float = p["tail_hp"]
	var partials: Array = p["partials"]

	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(surface)

	# One-pole filter states (separate chains for the transient and the tail).
	var b_lp := 0.0
	var b_hp := 0.0
	var t_lp := 0.0
	var t_hp := 0.0

	for i in n:
		var t := float(i) / RATE
		var w := rng.randf_range(-1.0, 1.0)

		# 1. Contact transient: white noise shaped to the surface's brightness.
		b_lp += (w - b_lp) * burst_lp
		var burst := b_lp
		if burst_hp > 0.0:
			b_hp += (burst - b_hp) * burst_hp
			burst -= b_hp
		burst *= burst_gain * exp(-t / burst_tau)

		# 2. Damped partials: the material's resonant "colour".
		var tone := 0.0
		for pt in partials:
			tone += sin(TAU * pt[0] * t) * exp(-t / pt[1]) * pt[2]

		# 3. Texture tail: a longer, softer filtered-noise scuff/crunch/sizzle.
		var tail := 0.0
		if tail_gain > 0.0:
			t_lp += (w - t_lp) * tail_lp
			tail = t_lp
			if tail_hp > 0.0:
				t_hp += (tail - t_hp) * tail_hp
				tail -= t_hp
			tail *= tail_gain * exp(-t / tail_tau)

		# Envelope: smooth onset (no click) + a short fade into the buffer end.
		var env := minf(t / attack, 1.0)
		var rem := dur - t
		if rem < FADE:
			env *= maxf(rem / FADE, 0.0)

		var v := clampf((burst + tone + tail) * env * gain, -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32767.0))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
