module app_list.uniform.post_blur_fog;

import kelp_core;

struct UniformPostBlurFog
{
	float fog_start;
	float fog_end;
	float blur_start;
	float blur_end;
	ColorF fog_color;
}
