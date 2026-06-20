shader_type canvas_item;

// Animated glow for "energy" themed walls (electric circuit, lava ember).
// It pulses and flows light along the BRIGHT parts of the wall texture (the
// circuit traces / lava veins) while leaving the dark base rock untouched.

uniform vec4 glow_color : source_color = vec4(0.26, 0.88, 1.0, 1.0);
uniform float speed = 5.0;        // animation rate
uniform float threshold = 0.16;   // luminance above this is treated as a "vein"
uniform float intensity = 1.1;    // glow strength

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	// How much this pixel belongs to a glowing vein/trace.
	float mask = smoothstep(threshold, threshold + 0.18, lum);
	// Travelling pulse along the tile so the energy looks like it flows.
	float pulse = 0.45 + 0.55 * sin(TIME * speed + UV.x * 9.0 + UV.y * 13.0);
	vec3 col = tex.rgb + glow_color.rgb * mask * pulse * intensity;
	COLOR = vec4(col, tex.a);
}
