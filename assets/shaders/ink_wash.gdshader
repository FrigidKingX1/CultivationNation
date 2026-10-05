shader_type canvas_item;
// P14 ink-wash post grade: edge lines, paper grain, brush-bleed palette.
// Runs on the world viewport texture (TextureRect in Main.tscn). Original.
// NOTE: samples TEXTURE/UV (the assigned viewport texture) — NOT
// screen_texture/SCREEN_UV, which would capture the empty main viewport
// behind the rect instead of the world (proven by grey output 2026-10-04).
uniform vec4 paper_color : source_color = vec4(0.93, 0.89, 0.80, 1.0);
uniform vec4 ink_color : source_color = vec4(0.08, 0.08, 0.10, 1.0);
uniform float edge_strength : hint_range(0.0, 3.0) = 1.2;
uniform float grain_amount : hint_range(0.0, 1.0) = 0.12;
uniform float bleed_amount : hint_range(0.0, 1.0) = 0.25;
uniform float vignette_amount : hint_range(0.0, 1.0) = 0.35;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float luminance(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec3 c = texture(TEXTURE, UV).rgb;
	// Sobel edges on luminance: ink lines where the world has edges.
	float tl = luminance(texture(TEXTURE, UV + vec2(-px.x, -px.y)).rgb);
	float t = luminance(texture(TEXTURE, UV + vec2(0.0, -px.y)).rgb);
	float tr = luminance(texture(TEXTURE, UV + vec2(px.x, -px.y)).rgb);
	float l = luminance(texture(TEXTURE, UV + vec2(-px.x, 0.0)).rgb);
	float r = luminance(texture(TEXTURE, UV + vec2(px.x, 0.0)).rgb);
	float bl = luminance(texture(TEXTURE, UV + vec2(-px.x, px.y)).rgb);
	float b = luminance(texture(TEXTURE, UV + vec2(0.0, px.y)).rgb);
	float br = luminance(texture(TEXTURE, UV + vec2(px.x, px.y)).rgb);
	float gx = -tl - 2.0 * l - bl + tr + 2.0 * r + br;
	float gy = -tl - 2.0 * t - tr + bl + 2.0 * b + br;
	float edge = clamp(sqrt(gx * gx + gy * gy) * edge_strength, 0.0, 1.0);
	// Brush-bleed: lift darks toward paper, warm the mids.
	float lum = luminance(c);
	vec3 graded = mix(c, paper_color.rgb, bleed_amount * (1.0 - lum) * 0.6);
	graded = mix(graded, graded * vec3(1.04, 1.0, 0.94), 0.5);
	// Paper grain: fine hash noise, stronger in bright washes.
	float g = hash12(UV * vec2(1920.0, 1080.0));
	graded += (g - 0.5) * grain_amount * (0.4 + 0.6 * lum);
	// Ink the edges, then vignette toward paper-dark.
	vec3 outc = mix(graded, ink_color.rgb, edge * 0.85);
	vec2 vd = UV - vec2(0.5);
	float vig = smoothstep(0.85, 0.35, length(vd) * (1.0 + vignette_amount));
	outc *= mix(1.0 - vignette_amount * 0.45, 1.0, vig);
	COLOR = vec4(outc, 1.0);
}
