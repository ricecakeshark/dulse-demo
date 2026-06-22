#version 460
#extension GL_EXT_scalar_block_layout : enable

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D depth_texture;
layout(set = 0, binding = 1) uniform sampler2D normal_texture;
layout(set = 0, binding = 2) uniform isampler2D entity_texture;

layout(set = 1, binding = 0, rgba8) uniform writeonly image2D edge_image;

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
bool is_edge_entity(ivec2 screen_pos);
float strength_normal(ivec2 screen_pos);
bool is_edge_normal(float total_diff);
float slope_depth(ivec2 screen_pos);
bool is_edge_depth(float slope);
bool is_valid_normal(vec3 normal);

void main()
{
	vec4 albedo_color;
	vec3 normal_world;
	vec3 world_pos;
	vec2 image_size = imageSize(edge_image);
	ivec2 screen_pos = ivec2(gl_GlobalInvocationID.xy);
	if(screen_pos.x >= image_size.x || screen_pos.y >= image_size.y)
	{
		return;
	}
	vec2 uv = vec2((vec2(screen_pos)+0.5) / vec2(image_size));
	
	world_pos = reconstruct_world_pos(uv, texelFetch(depth_texture, screen_pos, 0).r);
	vec4 draw_color;
	draw_color = vec4(0.0, 0.0, 0.0, 1.0);
	draw_color.r = is_edge_entity(screen_pos) ? 1.0 : 0.0;
	draw_color.g = is_edge_normal(strength_normal(screen_pos)) ? 1.0 : 0.0;
	draw_color.b = is_edge_depth(slope_depth(screen_pos)) ? 1.0 : 0.0;
	imageStore(edge_image, screen_pos, draw_color);
}

bool is_edge(ivec2 screen_pos)
{
	return is_edge_entity(screen_pos) || is_edge_normal(strength_normal(screen_pos));
}

bool is_edge_entity(ivec2 screen_pos)
{
	const ivec2 offsets[4] = ivec2[](
		ivec2(0, -1),
		ivec2(0, +1),
		ivec2(-1, 0),
		ivec2(+1, 0)
	);

	int entity_id = texelFetch(entity_texture, screen_pos, 0)[0];
	for(int count = 0; count < 4; ++count)
	{
		if(entity_id != texelFetch(entity_texture, screen_pos + offsets[count], 0)[0])
		{
			return true;
		}
	}
	return false;
}

float strength_normal(ivec2 screen_pos)
{
	const ivec2 offsets[4] = ivec2[](
		ivec2(0, -1),
		ivec2(0, +1),
		ivec2(-1, 0),
		ivec2(+1, 0)
	);
	vec3 center_normal = texelFetch(normal_texture, screen_pos, 0).xyz;
	if(!is_valid_normal(center_normal))
	{
		return 0.0;
	}

	float total_diff = 0.0;

	for(int count = 0; count < 4; ++count)
	{
		vec3 other_normal = texelFetch(normal_texture, screen_pos + offsets[count], 0).xyz;
		if(!is_valid_normal(other_normal))
		{
			continue;
		}
		total_diff += (1.0 - dot(center_normal, other_normal));
	}
	return total_diff;
}

bool is_edge_normal(float total_diff)
{
	return (total_diff > 1.0 - cos(radians(30.0)));
}

bool is_valid_normal(vec3 normal)
{
	return dot(normal, normal) > 0.0001;
}
// calc slope of texel (-1.0 ~ +1.0)
float slope_depth(ivec2 screen_pos)
{
	ivec2 offset[4] = ivec2[](
		ivec2(0,-1),
		ivec2(-1,0),
		ivec2(0,+1),
		ivec2(+1,0)
	);
	float slope = 0.0;
	float center_depth = texelFetch(depth_texture, screen_pos, 0)[0];
	/*
	slope += (screen_pos.x - 1 >= 0) ?
		(center_depth - texelFetch(depth_texture, screen_pos + ivec2(-1, 0), 0)[0]) : 0.0 ;
	slope += (screen_pos.y - 1 >= 0) ?
		(center_depth - texelFetch(depth_texture, screen_pos + ivec2(0, -1), 0)[0]) : 0.0 ;
	slope += (screen_pos.x + 1 < textureSize(depth_texture, 0).x) ?
		(texelFetch(depth_texture, screen_pos + ivec2(+1, 0), 0)[0] - center_depth) : 0.0 ;
	slope += (screen_pos.y + 1 < textureSize(depth_texture, 0).y) ?
		(texelFetch(depth_texture, screen_pos + ivec2(0, +1), 0)[0] - center_depth) : 0.0 ;
	slope /= 4.0;
	*/


	for(int count; count < 4; ++ count)
	{
		ivec2 offset_pos = screen_pos + offset[count];
		if( offset_pos.x < 0
		 || offset_pos.x > textureSize(depth_texture, 0).x
		 || offset_pos.y < 0
		 || offset_pos.y > textureSize(depth_texture, 0).y
		)
		{
			continue;
		}
		slope += texelFetch(depth_texture, offset_pos, 0)[0] - center_depth;
	}
	return slope;
}

bool is_edge_depth(float slope)
{
	if(abs(slope) > 0.005)
	{
		return true;
	}
	return false;
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
