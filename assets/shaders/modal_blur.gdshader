shader_type canvas_item;
// P17 blurred modal backdrop: mipmap-level blur of the live scene plus tint.
// Applied to title/help overlays. NOTE: samples the main-viewport backbuffer
// (screen_texture), which INCLUDES the world display — verify by screenshot
// that it shows the world and not grey (the P14 ViewportTexture failure
// mode does not apply here, but only pixels prove it). Original.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_level : hint_range(0.0, 5.0) = 2.5;
uniform vec4 tint_color : source_color = vec4(0.05, 0.05, 0.08, 0.65);

void fragment() {
	vec4 blurred_screen = textureLod(screen_texture, SCREEN_UV, blur_level);
	COLOR = mix(blurred_screen, vec4(tint_color.rgb, 1.0), tint_color.a);
}
