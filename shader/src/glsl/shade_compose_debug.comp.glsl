#version 460
#extension GL_EXT_scalar_block_layout : enable

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D depth_texture;
layout(set = 0, binding = 1) uniform sampler2D albedo_texture;
layout(set = 0, binding = 2) uniform sampler2D normal_texture;
layout(set = 0, binding = 3) uniform sampler2D color_texture;
layout(set = 0, binding = 4) uniform sampler2D model_texture;
layout(set = 0, binding = 5) uniform isampler2D entity_texture;
layout(set = 0, binding = 6) uniform sampler2D edge_texture;

layout(set = 1, binding = 0, rgba16f) uniform writeonly image2D output_image;

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
	vec4 albedo_color;
	vec3 normal_world;
	vec4 light_color;
	vec4 draw_color;
	float depth;
	switch(config.mode)
	{
		case 0:
			light_color = texture(color_texture, uv);
			draw_color = light_color;
			break;
		// albedo
		case 1:
			albedo_color = texture(albedo_texture, uv);
			draw_color = albedo_color;
			break;
		// normal
		case 2:
			normal_world = texelFetch(normal_texture, screen_pos, 0).xyz;
			draw_color = vec4(normal_world, 1.0);
			break;
		// light
		case 3:
			light_color = texture(color_texture, uv);
			draw_color = light_color;
			break;
		// depth
		case 4:
			depth = texelFetch(depth_texture, screen_pos, 0).x;
			draw_color = vec4(vec3(depth), 1.0);
			break;
		// edge
		case 5:
			draw_color = vec4(texelFetch(edge_texture, screen_pos, 0).xyz, 1.0);
			break;
		default:
			draw_color = vec4(1.0, 0.0, 1.0, 0.0);
			break;
	}
	// write
	imageStore(output_image, screen_pos, draw_color);
	return;
}

