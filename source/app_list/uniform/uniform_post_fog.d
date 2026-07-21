module app_list.uniform.uniform_post_fog;

import kelp_core;

struct UniformPostFog
{
	float fog_start;
	float fog_end;
	align(16) ColorF fog_color;
}
