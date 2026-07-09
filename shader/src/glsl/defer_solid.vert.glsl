#version 460
#extension GL_EXT_scalar_block_layout : enable

// input
layout(location = 0) in vec3 in_pos;
layout(location = 1) in vec3 in_normal;
layout(location = 2) in vec4 in_color;
// out
layout(location = 0) out vec4 out_color;
layout(location = 1) out vec3 out_normal;
layout(location = 2) out vec3 out_pos;
// uniform Scene
layout(std430, set = 1, binding = 0) uniform Scene
{
	vec4 light_ambient; // no use
} scene;
// uniform Per-View: (Projective, Viewport) 
layout(std430, set = 1, binding = 1) uniform View
{
	layout(row_major) mat4 mat_view_proj;
	layout(row_major) mat4 mat_inv_view_proj;
	vec3 vec_pos;
} view;
// uniform Per-Object: (Model, View, Projection)
layout(std430, set = 1, binding = 2) uniform Object
{
	layout(row_major) mat4x4 matrix_model;
	layout(row_major) mat4x4 matrix_normal;
} model;

void main()
{
	// color
	out_color = in_color;
	// normal
	out_normal = normalize(in_normal * mat3(model.matrix_normal));
	// position
	vec4 world_pos = vec4(in_pos, 1.0f) * model.matrix_model;
	out_pos = world_pos.xyz;
	gl_Position = vec4(in_pos, 1.0f) * model.matrix_model * view.mat_view_proj;
	return;
}
