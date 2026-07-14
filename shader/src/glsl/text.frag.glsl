#version 460
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
	float _dist = texture(glyph_sampler, uv).a;

	float width_edge = config.width_edge;
	float width_outline = (1.0 - config.width_edge) * config.ratio_outline;
	float width_glow = (1.0 - config.width_edge) * config.ratio_glow;
	float softness = max(config.softness, 1.0e-6);
	
	float step_edge = step(1.0 - width_edge, _dist);
	float step_outline = step(1.0 - (width_edge + width_outline), _dist);
	float step_glow = smoothstep(1.0 - (width_edge + width_outline+width_glow) - softness, 1.0 - (width_edge + width_outline + width_glow) + softness, _dist);

	float str_inline = step_edge;
	float str_outline = step_outline - step_edge;
	float str_glow = step_glow - step_outline;

	draw_color = config.color_inline * str_inline + 
		config.color_outline * str_outline + 
		config.color_glow * str_glow;
	
	return;
}
