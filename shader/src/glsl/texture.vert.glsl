#version 450
// input
layout(location = 0) in vec3 in_position;
layout(location = 1) in vec2 in_uv;
// out
layout(location = 0) out vec2 out_uv;
// uniform Per-View: (Projective, Viewport) 
layout(std140, set = 1, binding = 0) uniform View
{
	layout(row_major) mat4x4 view_matrix;
} view;
// uniform Per-Object: (Model, View, Projection)
layout(std140, set = 1, binding = 1) uniform Model
{
	layout(row_major) mat4x4 model_matrix;
} model;

void main()
{
	gl_Position = vec4(in_position, 1.0f) * (model.model_matrix * view.view_matrix);
	//gl_Position = (view.view_matrix * model.model_matrix) * vec4(in_position, 1.0f);
	out_uv = in_uv;
	return;
}
