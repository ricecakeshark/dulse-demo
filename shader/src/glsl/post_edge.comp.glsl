#version 460
#extension GL_EXT_scalar_block_layout : enable

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D edge_texture;

layout(set = 1, binding = 0, rgba16f) uniform writeonly image2D render_image;

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
	vec2 image_size = imageSize(render_image);
	ivec2 screen_pos = ivec2(gl_GlobalInvocationID.xy);
	if(screen_pos.x >= image_size.x || screen_pos.y >= image_size.y)
	{
		return;
	}
	vec2 uv = vec2((vec2(screen_pos)+0.5) / vec2(image_size));
	// read texture (g-buffer)
	vec4 edge_color = texelFetch(edge_texture, screen_pos, 0);
	
	vec4 draw_color;
	if(edge_color.a > 0.0)
	{
		draw_color = edge_color;
		imageStore(render_image, ivec2(screen_pos), draw_color);
	}
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
	vec4 world_pos = clip_pos * view.mat_inv_view_proj;
	world_pos.xyz /= world_pos.w;
	return world_pos.xyz;
}
