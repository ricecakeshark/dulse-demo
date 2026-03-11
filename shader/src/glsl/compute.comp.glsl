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
	vec2 image_size = imageSize(output_image);
	uvec2 pos = gl_GlobalInvocationID.xy;

	if(pos.x >= params.width|| pos.y >= params.height)
	{
		return;
	}

	vec2 uv = vec2((vec2(pos)+0.5)/vec2(image_size));
	color = texture(input_texture, uv);

	//float param_x = mod(pos.x, 16.0*8);
	//float param_y = mod(pos.y, 9.0*8);

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


	//color = vec4(param_x/(16.0*4),param_y/(9.0*4),0.2,1.0);
	
	//uint index = pos.y * params.width + pos.x;
	//vec4 color = input_data.pixels[index]; 
	imageStore(output_image, ivec2(pos), out_color);
}