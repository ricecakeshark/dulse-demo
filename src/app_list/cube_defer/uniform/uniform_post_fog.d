module app_list.cube_defer.uniform.uniform_post_fog;

import dulse;

struct UniformPostFog
{
	float fog_start;
	float fog_end;
	align(16) ColorF fog_color;
}
