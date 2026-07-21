#version 460
#extension GL_EXT_scalar_block_layout : enable

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D edge_texture;

layout(set = 1, binding = 0, rgba16f) uniform writeonly image2D render_image;

// View
layout(std430, set = 2, binding = 0) uniform Color
{
	vec4 outline_entity;
	vec4 outline_normal;
	vec4 outline_depth;
} color;

void main()
{
	vec2 image_size = imageSize(render_image);
	ivec2 screen_pos = ivec2(gl_GlobalInvocationID.xy);
	if(screen_pos.x >= image_size.x || screen_pos.y >= image_size.y)
	{
		return;
	}
	// read texture (g-buffer)
	vec4 edge_color = texelFetch(edge_texture, screen_pos, 0);
	
	vec4 draw_color = vec4(0.0, 0.0, 0.0, 0.0);
	
	if(color.outline_entity.a > 0.01 && edge_color.r > 0.0)
	{
		draw_color = color.outline_depth;
	}
	else if(color.outline_normal.a > 0.01 && edge_color.g > radians(30.0))
	{
		draw_color = color.outline_normal;
	}
	else if(color.outline_depth.a > 0.01 && abs(edge_color.b) > 0.01)
	{
		draw_color = color.outline_entity;
	}

	if(draw_color != vec4(0.0, 0.0, 0.0, 0.0))
	{
		imageStore(render_image, screen_pos, draw_color);
	}
	return;
}