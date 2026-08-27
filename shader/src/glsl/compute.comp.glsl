#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D input_texture;

layout(set = 1, binding = 0, rgba32f) uniform writeonly image2D output_image;

layout(set = 2, binding = 0) uniform Params
{
	float delta;
	float width;
	float height;
} params;

void main()
{
	vec4 color;
	vec4 out_color;
	const ivec2 image_size = imageSize(output_image);
	const uvec2 pos = gl_GlobalInvocationID.xy;

	if(pos.x >= image_size.x || pos.y >= image_size.y)
	{
		return;
	}

	const vec2 uv = vec2( (vec2(pos)+0.5) / vec2(image_size));
	color = texture(input_texture, uv);

	if( pos.x%12 >= 0 && pos.x%12 < 4 )
	{
		out_color = vec4(color.r, 0.2, 0.2, 1.0);
	}
	if( pos.x%12 >= 4 && pos.x%12 < 8 )
	{
		out_color = vec4(0.2, color.g, 0.2, 1.0);
	}
	if( pos.x%12 >= 8 && pos.x%12 < 12 )
	{
		out_color = vec4(0.2, 0.2, color.b, 1.0);
	}

	imageStore(output_image, ivec2(pos), out_color);
}