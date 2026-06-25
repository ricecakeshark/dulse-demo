#version 460
#extension GL_EXT_scalar_block_layout : enable

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D depth_texture;
layout(set = 0, binding = 1) uniform sampler2D albedo_texture;
layout(set = 0, binding = 2) uniform sampler2D color_texture;

layout(set = 1, binding = 0, rgba16f) uniform writeonly image2D output_image;

void main()
{
	ivec2 screen_pos = ivec2(gl_GlobalInvocationID.xy);
	ivec2 image_size = imageSize(output_image);
	if(screen_pos.x >= image_size.x || screen_pos.y >= image_size.y)
	{
		return;
	}
	//vec2 uv = vec2((vec2(screen_pos) + 0.5) / vec2(image_size));
	// read texture
	vec4 draw_color = texelFetch(color_texture, screen_pos, 0);
	// write
	imageStore(output_image, screen_pos, draw_color);
	return;
}

