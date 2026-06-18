#version 460
#extension GL_EXT_scalar_block_layout : enable

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D depth_texture;
layout(set = 0, binding = 1) uniform sampler2D albedo_texture;
layout(set = 0, binding = 2) uniform sampler2D normal_texture;
layout(set = 0, binding = 3) uniform sampler2D material_texture;
layout(set = 0, binding = 4) uniform isampler2D entity_texture;

layout(set = 1, binding = 0, rgba16f) uniform writeonly image2D output_image;

// View
layout(std430, set = 2, binding = 0) uniform View
{
	layout(row_major) mat4 mat_view;
	layout(row_major) mat4 mat_proj;
	layout(row_major) mat4 mat_view_proj;
	layout(row_major) mat4 mat_inv_view_proj;
	vec3 pos;
	vec3 vec;
} view;

vec3 reconstruct_world_pos(vec2 uv, float depth);
bool is_edge(ivec2 screen_pos);
bool is_entity_edge(ivec2 screen_pos);
bool is_normal_edge(ivec2 screen_pos);
bool is_valid_normal(vec3 normal);

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
	normal_world = texture(normal_texture, uv).xyz;
	
	world_pos = reconstruct_world_pos(uv, texelFetch(depth_texture, screen_pos, 0).r);
	vec4 draw_color;
	if (is_edge(screen_pos))
	{
		draw_color = vec4(1.0, 0.0, 1.0, 0.0);
		imageStore(output_image, ivec2(screen_pos), draw_color);
	}
}

bool is_edge(ivec2 screen_pos)
{
	return is_entity_edge(screen_pos) || is_normal_edge(screen_pos);
}

bool is_entity_edge(ivec2 screen_pos)
{
	const ivec2 offsets[4] = ivec2[](
		ivec2(0, -1),
		ivec2(0, +1),
		ivec2(-1, 0),
		ivec2(+1, 0)
	);

	int entity_id = texelFetch(entity_texture, screen_pos, 0)[0];
	for(int count; count < 4; ++count)
	{
		if(entity_id != texelFetch(entity_texture, screen_pos + offsets[count], 0)[0])
		{
			return true;
		}
	}
	return false;
}

bool is_normal_edge(ivec2 screen_pos)
{
	const ivec2 offsets[4] = ivec2[](
		ivec2(0, -1),
		ivec2(0, +1),
		ivec2(-1, 0),
		ivec2(+1, 0)
	);
	vec3 normal = texelFetch(normal_texture, screen_pos, 0).xyz;
	if(!is_valid_normal(normal))
	{
		return false;
	}

	for(int count; count < 4; ++count)
	{
		vec3 other_normal = texelFetch(normal_texture, screen_pos + offsets[count], 0).xyz;
		if(!is_valid_normal(other_normal))
		{
			continue;
		}
		if(dot(normal, other_normal) < cos(30.0))
		{
			return true;
		}
	}
	return false;
}

bool is_valid_normal(vec3 normal)
{
	return dot(normal, normal) > 0.0001;
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
	vec4 world_pos = clip_pos * view.mat_inv_view_proj;
	world_pos.xyz /= world_pos.w;
	return world_pos.xyz;
}
