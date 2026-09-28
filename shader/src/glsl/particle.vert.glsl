#version 460
#extension GL_EXT_scalar_block_layout : enable

// input
// no need
// output
//layout(location = 0) out vec3 out_pos;
// uniform
layout(std430, set = 1, binding = 0) uniform Scene
{
	int elapsed_time;
} scene;

layout(std430, set = 1, binding = 1) uniform View
{
	mat4 mat_view_proj;
} view;
// def
vec3 particle_pos(in uint id);
uint hash(uint arg);
float hash_float(in uint arg);

void main()
{
	gl_Position = (
		vec4(particle_pos(uint(gl_VertexIndex)), 1.0) * view.mat_view_proj
	);
	gl_PointSize = 20.0;
		
	return;
}

vec3 particle_pos(in uint id)
{
	return vec3(
		hash_float(id * 3u + 0u),
		hash_float(id * 3u + 1u),
		hash_float(id * 3u + 2u)
	);
}
// hash easily and carelessly
uint hash(uint arg)
{
	/*arg ^= arg >> 16;
	arg *= 0x12345678u;
	arg ^= arg >> 15;
	arg += 0x90123456u;
	arg ^= arg >> 16;*/

	arg ^= arg >> 16;
    arg *= 0x7feb352du;
    arg ^= arg >> 15;
    arg *= 0x846ca68bu;
    arg ^= arg >> 16;
	return arg;
}

float hash_float(in uint arg)
{
	return float(hash(arg) >> 8) / float(1 << 24);
}