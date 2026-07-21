#version 460
#extension GL_EXT_scalar_block_layout : enable

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D source_texture;
layout(set = 1, binding = 0, rgba16f) uniform writeonly image2D dest_texture;

layout(std430, set = 2, binding = 0) uniform Config
{
	int output_mode;
} config_mode;

layout(std430, set = 2, binding = 1) uniform Color
{
	float exposure;
	float contrast;
	float saturation;
	float temperature;

	//float lift;
} config_color;

layout(std430, set = 2, binding = 2) uniform Tone
{
	float mid_low;
	float mid_high;
	float peak_low;
	float peak_high;
} config_tone;

const float epsilon = 1.0e-6;

vec3 adjust_exposure(const in vec3);
vec3 adjust_contrast(const in vec3, const in float);
vec4 gamma_correct(const in vec4);
vec3 tonemap(const in vec3);
vec3 tonemap_invert(const in vec3);
vec3 tonemap_weight(const in vec3, const in float);
vec3 tonemap_HDR(const in vec3, const in float, const in float);
vec3 tonemap_3zone(const in vec3);
float tonemap_3zone_scalar(const in float);
float rcp(const in float);
float max3_user(const in float, const in float, const in float);
float max3_user(const in vec3);

void main()
{
	ivec2 screen_pos = ivec2(gl_GlobalInvocationID.xy);
	vec4 texel_color = texelFetch(source_texture, screen_pos, 0);
	vec4 output_color;

	output_color = vec4(
		tonemap_3zone(adjust_contrast(adjust_exposure(texel_color.rgb), 0.3)),
		texel_color.a
	);
	/*switch(config_mode.output_mode)
	{
		case 0:
			output_color = gamma_correct(texel_color);
			break;
		case 1:
			output_color = vec4(tonemap_3zone(texel_color.rgb), texel_color.a);
			break;
		case 2:
			output_color = vec4(1.0, 0.0, 1.0, 0.0);
			break;
	}*/

	imageStore(dest_texture, screen_pos, output_color);
	return;
}
// correct damma (only SDR) 
/*vec4 gamma_correct(const vec4 color)
{
	return vec4(pow(color.rgb, vec3(1.0 / config_color.gamma)), color.a);
}*/

vec3 adjust_exposure(const in vec3 color)
{
	return color * exp2(config_color.exposure);
}

vec3 adjust_contrast(const in vec3 color, const in float pivot)
{
	return color.rgb - vec3(pivot) * config_color.contrast + vec3(pivot);
}

// tone map
vec3 tonemap(const in vec3 color)
{
	return color.rgb * rcp(max3_user(color.r, color.g, color.b) + 1.0);
}

vec3 tonemap_invert(const in vec3 color)
{
	return color.rgb * rcp(1.0 - max3_user(color.r, color.g, color.b));
}
// tone map with weight
// AMD GPUOpen (https://gpuopen.com/learn/optimized-reversible-tonemapper-for-resolve/)
vec3 tonemap_weight(const in vec3 color, const in float weight)
{
	return color.rgb * (weight * rcp(max3_user(color.r, color.g, color.b) + 1.0));
}

vec3 tonemap_3zone(const in vec3 color)
{
	float maximum = max3_user(color);
	float mapped_elem = tonemap_3zone_scalar(maximum);
	if(maximum <= epsilon)
	{
		return vec3(mapped_elem);
	}
	return color * (mapped_elem / maximum);
}

float tonemap_3zone_scalar(const in float color_elem)
{
	if (color_elem < config_tone.peak_low)
	{
		return config_tone.peak_low;
	}

	if (color_elem < config_tone.mid_low)
	{
		// compress into peak_low and mid_low
		float t = clamp(
			(color_elem - config_tone.peak_low) / max(config_tone.mid_low - config_tone.peak_low, epsilon),
			0.0, 1.0
		);
		return mix(config_tone.peak_low, config_tone.mid_low, t * t * (2.0 - t));
	}
	else if (color_elem > config_tone.mid_high)
	{
		// compress into mid_high and peak_high
		//color_elem = color_elem * rcp(color_elem + config_tone.peak_high);
		float range = max(config_tone.peak_high - config_tone.mid_high, epsilon);
		float over = color_elem - config_tone.mid_high;
		return config_tone.mid_high + range * (1.0 - exp(-over / range));
	}
	// do nothing;
	return color_elem;
}
// reciprocal
float rcp(const in float x)
{
	return 1.0 / x;
}

float max3_user(const in float x, const in float y, const in float z)
{
	return max(x, max(y, z));
}

float max3_user(const in vec3 vec)
{
	return max(vec[0], max(vec[1], vec[2]));
}