#version 450
// uniform Per-View: (Projective, Viewport) 
layout(set = 1, binding = 0) uniform View
{
	layout(row_major) mat4x4 view_matrix;
} view;
// uniform Per-Object: (Model, View, Projection)
layout(set = 1, binding = 1) uniform Model
{
	layout(row_major) mat4x4 model_matrix;
} model;

// input
layout(location = 0) in vec3 in_pos;
layout(location = 1) in vec3 in_normal;
layout(location = 2) in vec4 in_color;
layout(location = 3) in vec3 in_tangent;

layout(location = 0) out VS_Out
{
	vec4 color;
} vs_out;

void main(void)
{
	vs_out.color = color;
	gl_Position = vec4(in_pos, 1.0f) * (model.model_matrix * view.view_matrix);
	return;
}
