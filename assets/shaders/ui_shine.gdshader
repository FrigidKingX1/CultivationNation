shader_type canvas_item;
// P17 shine sweep for ready/milestone controls. Procedural diagonal sheen
// band; transparent elsewhere. Applied on an overlay child (mouse-ignore)
// so it composites OVER the button's normal themed draw instead of
// replacing it. Original.

uniform float shine_speed : hint_range(0.1, 5.0) = 1.5;
uniform float shine_width : hint_range(0.01, 0.5) = 0.15;
uniform vec4 shine_color : source_color = vec4(1.0, 1.0, 1.0, 0.45);
uniform float cycle_delay : hint_range(0.5, 10.0) = 3.0;

void fragment() {
	float total_cycle = (1.0 / shine_speed) + cycle_delay;
	float cycle_time = mod(TIME, total_cycle);
	float progress = cycle_time * shine_speed;
	float sweep_line = UV.x + UV.y;
	float target_line = progress * 2.0;
	float dist = abs(sweep_line - target_line);
	float shine_factor = 1.0 - smoothstep(0.0, shine_width, dist);
	shine_factor = pow(shine_factor, 2.0);
	COLOR = vec4(shine_color.rgb, shine_factor * shine_color.a);
}
