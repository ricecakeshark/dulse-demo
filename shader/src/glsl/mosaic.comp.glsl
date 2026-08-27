#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D src_texture;

layout(set = 1, binding = 0, rgba32f) uniform writeonly image2D dst_texture;


layout(set = 2, binding = 0) uniform Params
{
	float width;
	float height;
	float delta;
	float level;
} params;

shared vec4 texel_color;

vec4 quantize(vec4 arg_color,float level)
{
	return vec4(floor(arg_color.rgb * (level - 1.0f) + 0.5f) / (level - 1.0), 1.0f);
}

void main()
{
	const uvec2 global_pos = gl_GlobalInvocationID.xy;
	const uvec2 local_pos = gl_LocalInvocationID.xy;
	const ivec2 image_size = imageSize(dst_texture);

	if(global_pos.x >= image_size.x || global_pos.y >= image_size.y)
	{
		return;
	}
	if(local_pos.x == 4 && local_pos.y == 4)
	{
		texel_color = texelFetch(src_texture, ivec2(global_pos), 0);
	}
	
	barrier();

	imageStore(dst_texture, ivec2(global_pos), quantize(texel_color, params.level));
}
