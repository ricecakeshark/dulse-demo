#version 460
#extension GL_EXT_scalar_block_layout : enable
// input
layout(location = 0) in vec3 in_pos;
layout(location = 1) in vec2 in_uv;
// out
layout(location = 0) out vec2 out_uv;
// uniform Scene
// uniform Per-View: (Projective, Viewport) 
layout(std430, set = 1, binding = 0) uniform View
{
	layout(row_major) mat4x4 matrix_view_proj;
} view;
// uniform Per-Object: (Model, View, Projection)
layout(std430, set = 1, binding = 1) uniform Object
{
	layout(row_major) mat4x4 matrix_model;
	layout(row_major) mat4x4 matrix_normal;
} model;

void main()
{
	// uv
	out_uv = in_uv;
	// position
	gl_Position = vec4(in_pos, 1.0f) * model.matrix_model * view.matrix_view_proj;
	return;
}
