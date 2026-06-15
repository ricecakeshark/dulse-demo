#version 460
#extension GL_EXT_scalar_block_layout : enable

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D albedo_texture;
layout(set = 0, binding = 1) uniform sampler2D normal_texture;
layout(set = 0, binding = 2) uniform sampler2D color_texture;
layout(set = 0, binding = 3) uniform sampler2D model_texture;
layout(set = 0, binding = 4) uniform sampler2D depth_texture;

layout(set = 1, binding = 0, rgba32f) uniform writeonly image2D output_image;

layout(std430, set = 2, binding = 0) uniform Config
{
	int mode;
} config;

void main()
{
	ivec2 screen_pos = ivec2(gl_GlobalInvocationID.xy);
	ivec2 image_size = imageSize(output_image);
	if(screen_pos.x >= image_size.x || screen_pos.y >= image_size.y)
	{
		return;
	}
	vec2 uv = vec2((vec2(screen_pos) + 0.5) / vec2(image_size));
	// read texture (g-buffer)
	vec4 albedo_color = texture(albedo_texture, uv);
	vec3 normal_world = texture(normal_texture, uv).xyz;
	vec4 light_color = texture(color_texture, uv);
	float specular_strength = texelFetch(model_texture, screen_pos, 0).r;
	float shininess = texelFetch(model_texture, screen_pos, 0).g;
	int entity_id = int(texelFetch(model_texture, screen_pos, 0).b);

	//vec4 draw_color = vec4(albedo_color.xyz + light_color.xyz, albedo_color.a);
	vec4 draw_color;
	switch(config.mode)
	{
		case 0:
			draw_color = light_color;
			break;
		case 1:
			draw_color = albedo_color;
			break;
		case 2:
			draw_color = vec4(normal_world, 1.0);
			break;
		case 3:
			draw_color = light_color;
			break;
		case 4:
			draw_color = vec4(texelFetch(depth_texture, screen_pos, 0).r);
			break;
		default:
			draw_color = vec4(1.0, 0.0, 1.0, 0.0);
			break;
	}
	 
	// write
	imageStore(output_image, screen_pos, draw_color);
	return;
}

