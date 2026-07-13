module app_list.uniform.post_color;

struct UniformColor
{
	UniformColorMode mode;
	UniformColorColor color;
	UniformColorTone tone;
}

struct UniformColorMode
{
	int output_mode = 1;
}

struct UniformColorColor
{
	float exposure = 0.0;
	float contrast = 1.0;
	float saturation;
	float temperature;
}


struct UniformColorTone
{
	float mid_low = 0.1;
	float mid_high = 1.0;
	float peak_low = 0.0;
	float peak_high = 1000f/80f;
}