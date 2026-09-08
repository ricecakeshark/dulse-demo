module app_list.compute.uniform.compute;

import dulse.core;
import dulse.math;

struct UniformCompute
{
	float width;
	float height;
	float delta = 0.0f;
	float level = 8.0f;
}

struct UniformVertexScene
{
	ColorF ambient_light;
}

struct UniformVertexView
{
	Matrix!(4, 4) mat_view;
}

struct UniformVertexModel
{
	Matrix!(4, 4) mat_model;
	Matrix!(4, 4) mat_model_normal;
}

struct UniformFragmentScene
{
	ColorF ambient_light;
}

struct UniformFragmentView
{
	Vec3 vec_view;
}

struct UniformFragmentModel
{
	//align(4):
	float specular_strength = 0.5f;
	float shininess = 32.0f;
	int entity_id;
}

struct UniformFragmentLight
{
	LightPoint[1] list;
	uint count;
}

struct LightPoint
{
	align(16) Vec3 pos = [0.0f, 0.0f, -3.0f];
	align(16) Vec3 color = [1.0f, 1.0f, 1.0f];
	float intensity = 1.0f;
}
