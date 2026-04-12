#version 450
// in
layout(location = 0) in vec2 uv;
// out
layout(location = 0) out vec4 draw_color;
// combine
layout(set = 2, binding = 0) uniform sampler2D glyph_sampler;
// uniform buffer
layout(std140, set = 3, binding = 0) uniform TextConfig
{
	vec4 color_inline;
	vec4 color_outline;
	vec4 color_grow;
	float width_edge;
	float ratio_outline;
	float ratio_grow;
	float softness;
} config;

void main()
{
	float distance = texture(glyph_sampler, uv).a;

	float to_edge = config.width_edge;
	float out_in = config.width_edge * (1.0f + config.ratio_outline);
	float none_grow = config.width_edge * config.ratio_grow;
	float softness = max(config.softness, 1.0e-6);
	
	float step_out_in = step(out_in, distance);
	float step_to_edge = step(to_edge, distance);
	float step_none_grow = smoothstep(none_grow - softness, none_grow + softness, distance);

	float str_inline = step_out_in;
	float str_outline = step_to_edge - step_out_in;
	float str_grow = step_none_grow - step_to_edge;

	draw_color = config.color_inline * str_inline + 
		config.color_outline * str_outline + 
		config.color_grow * str_grow;
	
	return;
}
