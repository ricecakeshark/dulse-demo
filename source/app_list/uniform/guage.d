module app_list.uniform.guage;

import kelp_core.core;
import kelp_core.math;

struct UniformGuageConst
{
	align(16) Vec2 rel_pos = Vec2(200f, 200f);
	float inner_width = 30f;
	float outer_width = 100f;
	ColorF color_fg = ColorF(0.0f, 1.0f, 0.0f, 1.0f);
	ColorF color_bg = ColorF(0.1f, 0.1f, 0.1f, 1.0f);
	ColorF color_increase = ColorF(0.9f, 0.9f, 0.9f, 1.0f);
	ColorF color_decrease = ColorF(0.8f, 0.1f, 0.1f, 1.0f);
}

struct UniformGuageParam
{
	float guage_ratio = 0.4f;
	float delta_ratio = 0.0f;
}
