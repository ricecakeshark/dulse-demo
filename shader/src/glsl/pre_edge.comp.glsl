#version 460
#extension GL_EXT_scalar_block_layout : enable

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D depth_texture;
layout(set = 0, binding = 1) uniform sampler2D normal_texture;
layout(set = 0, binding = 2) uniform isampler2D entity_texture;

layout(set = 1, binding = 0, rgba8) uniform writeonly image2D edge_image;

bool is_edge_entity(const in ivec2 screen_pos);
float strength_normal(const in ivec2 screen_pos);
bool is_edge_normal(const in float total_diff);
float slope_depth(const in ivec2 screen_pos);
bool is_edge_depth(const in float slope);
bool is_valid_normal(const in vec3 normal);
bool is_in_texture(const in ivec2 normal);

void main()
{
	vec2 image_size = imageSize(edge_image);
	ivec2 screen_pos = ivec2(gl_GlobalInvocationID.xy);
	if(!is_in_texture(screen_pos))
	{
		return;
	}
	
	vec4 draw_color;
	draw_color = vec4(0.0, 0.0, 0.0, 1.0);
	draw_color.r = is_edge_entity(screen_pos) ? 1.0 : 0.0;
	draw_color.g = is_edge_normal(strength_normal(screen_pos)) ? 1.0 : 0.0;
	draw_color.b = is_edge_depth(slope_depth(screen_pos)) ? 1.0 : 0.0;
	imageStore(edge_image, screen_pos, draw_color);
}

bool is_edge_entity(const in ivec2 screen_pos)
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
		ivec2 neighbor_pos = screen_pos + offsets[count];
		if(!is_in_texture(neighbor_pos))
		{
			continue;
		}
		if(entity_id != texelFetch(entity_texture, neighbor_pos, 0)[0])
		{
			return true;
		}
	}
	return false;
}

float strength_normal(const in ivec2 screen_pos)
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
		if(!is_in_texture(screen_pos + offsets[count]))
		{
			continue;
		}
		vec3 other_normal = texelFetch(normal_texture, screen_pos + offsets[count], 0).xyz;
		if(!is_valid_normal(other_normal))
		{
			continue;
		}
		total_diff += (1.0 - dot(center_normal, other_normal));
	}
	return total_diff;
}

bool is_edge_normal(const in float total_diff)
{
	return (total_diff > 1.0 - cos(radians(30.0)));
}

bool is_valid_normal(const in vec3 normal)
{
	return dot(normal, normal) > 0.0001;
}
// calc slope of texel (-1.0 ~ +1.0)
float slope_depth(const in ivec2 screen_pos)
{
	ivec2 offset[4] = ivec2[](
		ivec2(0,-1),
		ivec2(-1,0),
		ivec2(0,+1),
		ivec2(+1,0)
	);
	float slope = 0.0;
	float center_depth = texelFetch(depth_texture, screen_pos, 0)[0];

	for(int count = 0; count < 4; ++ count)
	{
		ivec2 offset_pos = screen_pos + offset[count];
		if(!is_in_texture(offset_pos))
		{
			continue;
		}
		slope += texelFetch(depth_texture, offset_pos, 0)[0] - center_depth;
	}
	return slope;
}

bool is_edge_depth(const in float slope)
{
	if(abs(slope) > 0.005)
	{
		return true;
	}
	return false;
}

bool is_in_texture(const in ivec2 pos)
{
	if(
		pos.x < 0
		|| pos.x >= imageSize(edge_image).x
		|| pos.y < 0
		|| pos.y >= imageSize(edge_image).y
	){
		return false;
	}
	return true;
}
