module app_list.particle.uniform.scene;

import dulse.math.linalg.matrix;

struct UniformScene
{
	uint elapsed_time;
}

struct UniformView
{
	Matrix!(4,4) mat_view_proj;
}