#version 460
#extension GL_EXT_scalar_block_layout : enable

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D albedo_texture;
layout(set = 0, binding = 1) uniform sampler2D normal_texture;
layout(set = 0, binding = 2) uniform sampler2D color_texture;
layout(set = 0, binding = 3) uniform sampler2D model_texture;
layout(set = 0, binding = 4) uniform sampler2D depth_texture;

layout(set = 1, binding = 0, rgba32f) uniform writeonly image2D output_image;

// View
layout(std430, set = 2, binding = 0) uniform View
{
	layout(row_major) mat4 mat_view;
	layout(row_major) mat4 mat_proj;
	layout(row_major) mat4 mat_view_proj;
	layout(row_major) mat4 mat_inv_view_proj;
	vec3 vec;
} view;


vec3 reconstruct_world_pos(vec2 uv, float depth);

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
	vec3 world_pos = reconstruct_world_pos(uv, texelFetch(depth_texture, screen_pos, 0).r);
	float specular_strength = texelFetch(model_texture, screen_pos, 0).r;
	float shininess = texelFetch(model_texture, screen_pos, 0).g;
	int entity_id = int(texelFetch(model_texture, screen_pos, 0).b);

	//vec4 draw_color = vec4(albedo_color.xyz + light_color.xyz, albedo_color.a);
	vec4 draw_color = light_color;
	// write
	imageStore(output_image, screen_pos, draw_color);
	return;
}



vec3 reconstruct_world_pos(vec2 uv, float depth)
{
	vec4 clip_pos;
	clip_pos = vec4(
		uv.x * 2.0 - 1.0,
		uv.y * 2.0 - 1.0,
		depth,
		1.0
	);

	vec4 world_pos = inverse(view.mat_view * view.mat_proj) * clip_pos;
	world_pos.xyz /= world_pos.w;
	return world_pos.xyz;
}
