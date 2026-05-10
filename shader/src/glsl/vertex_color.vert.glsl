#version 460
// input
layout(location = 0) in vec3 in_pos;
layout(location = 1) in vec3 in_normal;
layout(location = 2) in vec4 in_color;
// output
layout(location = 0) out vec4 out_color;
layout(location = 1) out vec3 world_normal;
layout(location = 2) out vec3 world_pos;
// uniform Per-View: (Projective, Viewport) 
layout(set = 1, binding = 0) uniform Scene
{
	vec4 ambient_light;
} scene;

layout(set = 1, binding = 1) uniform View
{
	layout(row_major) mat4x4 view_matrix;
} view;
// uniform Per-Object: (Model, View, Projection)
layout(set = 1, binding = 2) uniform Model
{
	layout(row_major) mat4x4 matrix_model;
	layout(row_major) mat4x4 matrix_normal;
} model;

void main(void)
{
	// color
	out_color = in_color;
	// normal
	//mat3 normal_matrix = transpose(inverse(mat3(model.matrix_model)));
	//world_normal = normalize(in_normal * normal_matrix);
	world_normal = normalize(in_normal * mat3(model.matrix_normal));
	// position
	world_pos = (vec4(in_pos, 1.0f) * model.matrix_model).xyz;
	gl_Position = vec4(in_pos, 1.0f) * (model.matrix_model * view.view_matrix);
	return;
}
