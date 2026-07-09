#version 450
// input
layout(location = 0) in vec3 in_pos;
layout(location = 1) in vec3 in_normal;
layout(location = 2) in vec2 in_uv;
// out
layout(location = 0) out vec2 out_uv;
layout(location = 1) out vec3 out_normal;
layout(location = 2) out vec3 out_pos;
// uniform Scene
layout(std140, set = 1, binding = 0) uniform Scene
{
	vec4 ambient_light;
} scene;
// uniform Per-View: (Projective, Viewport) 
layout(std140, set = 1, binding = 1) uniform View
{
	layout(row_major) mat4x4 matrix_view_proj;
} view;
// uniform Per-Object: (Model, View, Projection)
layout(std140, set = 1, binding = 2) uniform Object
{
	layout(row_major) mat4x4 matrix_model;
	layout(row_major) mat4x4 matrix_normal;
} model;

void main()
{
	// uv
	out_uv = in_uv;
	// normal
	//mat3 normal_matrix = transpose(inverse(mat3(model.matrix_model)));
	//out_normal = normalize(in_normal * normal_matrix);
	out_normal = normalize(in_normal * mat3(model.matrix_normal));
	
	// position
	vec4 world_pos = vec4(in_pos, 1.0f) * model.matrix_model;
	out_pos = world_pos.xyz;
	gl_Position = vec4(in_pos, 1.0f) * model.matrix_model * view.matrix_view_proj;
	return;
}
