#version 460
#extension GL_EXT_scalar_block_layout : enable

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D edge_texture;

layout(set = 1, binding = 0, rgba16f) uniform writeonly image2D output_image;

// View
layout(std430, set = 2, binding = 0) uniform View
{
	vec4 outline_color;
} view;


void main()
{
	vec4 albedo_color;
	vec3 normal_world;
	vec3 world_pos;
	vec2 image_size = imageSize(output_image);
	ivec2 screen_pos = ivec2(gl_GlobalInvocationID.xy);
	if(screen_pos.x >= image_size.x || screen_pos.y >= image_size.y)
	{
		return;
	}
	vec2 uv = vec2((vec2(screen_pos)+0.5) / vec2(image_size));
	// read texture (g-buffer)
	albedo_color = texture(albedo_texture, uv);

	if(texelFetch(edge_texture, screen_pos, 0)[2] < -0.01 )
	{
		imageStore(output_image, ivec2(screen_pos), outline_color);
	}
}
