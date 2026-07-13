module app_list.uniform.post_color;

struct UniformColorMode
{
	int output_mode = 1;
}

struct UniformTone
{
	float mid_low = 0.1;
	float mid_high = 1.0;
	float peak_low = 0.0;
	float peak_high = 1000f/80f;
}

struct UniformColor
{
	float exposure = 0.0;
	float gamma = 2.2;
	float lift = 0.0;
}
