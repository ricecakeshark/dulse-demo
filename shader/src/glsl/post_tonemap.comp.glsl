#version 460
#extension GL_EXT_scalar_block_layout : enable

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D source_texture;
layout(set = 1, binding = 0, rgba16f) uniform writeonly image2D dest_texture;

layout(std430, set = 2, binding = 0) uniform Config
{
	vec4 outline_entity;
} color;

void main()
{
	ivec2 screen_pos = ivec2(gl_GlobalInvocationID.xy);
	vec4 texel_color = texelFetch(source_texture, screen_pos, 0);
	// exposure
	color *= exp2(config.exposure)

	imageStore(dest_texture, screen_pos, );
	return;
}