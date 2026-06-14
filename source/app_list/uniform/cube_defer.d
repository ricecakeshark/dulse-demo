module app_list.uniform.cube_defer;

import kelp_core.math;

struct UniformScene
{
	Vec4 light_ambient;
}

struct UniformView
{
	Matrix!(4, 4, float) mat_projection;
}

struct UniformViewComp
{
	Matrix!(4, 4, float) mat_view;
	Matrix!(4, 4, float) mat_projection;
	Vec3 vec_view;
}

struct UniformModelVert
{
	Matrix!(4, 4, float) matrix_model;
	Matrix!(4, 4, float) matrix_model_normal;

	this(Matrix!(4, 4, float) matrix_model)
	{
		this.matrix_model = matrix_model;
		this.matrix_model_normal = matrix_model.to_normal();
		return;
	}
}

struct UniformModelFrag
{
	float specular_strength;
	float shininess;
	int entity_id;
}

struct UniformLight
{
	LightPoint[1] light_point_list;
	uint count_light_point = 1;
}

struct LightPoint
{
	Vec4 pos = [0.0f, 0.0f, -3.0f, 0f];
	Vec4 color = [1.0f, 1.0f, 1.0f, 0f];
	float intensity = 1.0f;
}
