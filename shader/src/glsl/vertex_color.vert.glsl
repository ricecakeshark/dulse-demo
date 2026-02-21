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
layout(location = 0) in vec3 position;
layout(location = 1) in vec4 color;

layout(location = 0) out VS_Out
{
	vec4 color;
} vs_out;

void main(void)
{
	vs_out.color = color;
	gl_Position = vec4(position, 1.0f) * (model.model_matrix * view.view_matrix);
	return;
}
