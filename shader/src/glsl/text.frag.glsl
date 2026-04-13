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
	vec4 color_glow;
	float width_edge;
	float ratio_outline;
	float ratio_glow;
	float softness;
} config;

void main()
{
	float distance = texture(glyph_sampler, uv).a;

	float to_edge = config.width_edge;
	float out_in = config.width_edge * (1.0f - config.ratio_outline);
	float none_glow = config.width_edge * (1.0f - (config.ratio_outline + config.ratio_glow));
	float softness = max(config.softness, 1.0e-6);
	
	float step_out_in = step(out_in, distance);
	float step_to_edge = step(to_edge, distance);
	float step_none_glow = smoothstep(none_glow - softness, none_glow + softness, distance);

	float str_inline = step_out_in;
	float str_outline = step_to_edge - step_out_in;
	float str_glow = step_none_glow - step_to_edge;

	draw_color = config.color_inline * str_inline + 
		config.color_outline * str_outline + 
		config.color_glow * str_glow;
	
	return;
}
