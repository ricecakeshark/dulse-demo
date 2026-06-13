module app_list.uniform.cube_defer;

import kelp_core.math;

struct UniformScene
{
	Vec4 light_ambient;
}

struct UniformView
{
	Matrix!(4, 4, float) mat_projection;
	Vec3 vec_view;
}

struct UniformModel
{
	Matrix!(4, 4, float) matrix_model;
	float specular_strength;
	float shininess;
}

struct UniformLight
{
	LightPoint[1] light_point_list;
	uint count_light_point = 1;
}

struct LightPoint
{
	align(16) Vec3 pos = [0.0f, 0.0f, -3.0f];
	align(16) Vec3 color = [1.0f, 1.0f, 1.0f];
	float intensity = 1.0f;
}
