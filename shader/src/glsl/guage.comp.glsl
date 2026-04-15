#version 460
#extension GL_EXT_scalar_block_layout : enable

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 1, binding = 0, rgba32f) uniform writeonly image2D output_image;

layout(std430, set = 2, binding = 0) uniform GuageConst
{
	vec2 rel_pos;
	float inner_width;
	float outer_width;
	vec4 color_fg;
	vec4 color_bg;
	vec4 color_increase;
	vec4 color_decrease;
} guage_const;

layout(std430, set = 2, binding = 1) uniform GuageParam
{
	float guage_ratio;
	float delta_ratio;
} guage_param;


void main()
{
	vec4 draw_color;
	vec2 pos = vec2(gl_GlobalInvocationID.xy) - guage_const.rel_pos;
	float dist = sqrt(pos.x * pos.x + pos.y * pos.y);

	if( dist < guage_const.outer_width && dist > guage_const.inner_width )
	{
		float xy_rad = atan(-pos.x, pos.y) + radians(180);
		float actual_rad = guage_param.guage_ratio * radians(360);
		float delta_rad = abs(guage_param.delta_ratio) * radians(360);
		if( xy_rad > actual_rad )
		{
			draw_color = guage_const.color_bg;
		}
		else if (xy_rad < actual_rad - delta_rad)
		{
			draw_color = guage_const.color_fg;
		}
		else
		{
			if(guage_param.delta_ratio > 0)
			{
				draw_color = guage_const.color_increase;
			}
			else
			{
				draw_color = guage_const.color_decrease;
			}
		}
		imageStore(output_image, ivec2(gl_GlobalInvocationID.xy), draw_color);
	}
	
	return;
}