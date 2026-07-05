module app_list.ecs.transform;

import app_list.ecs;

import kelp_core.object;
import kelp_core.math;

struct TransformComponent
{
	Vec3 pos;
	Quaternion!float rotate_quat;
	Vec3 scale;

	Matrix!(4, 4, float) model_matrix(float scale = 1.0f)
	{
		return matrix_scale!3(this.scale * scale)
			.multiply(rotate_quat.to_matrix)
			.extend!(Matrix!(4, 4))
			.multiply(transformer_translate(pos));
	}
}

class TransformSystem : IObjectSystem
{
	immutable inverse_usecs = 0.001f * 0.001f;

	void initialize(ObjectManager manager)
	{
		foreach (entity; manager.entity.list)
		{
			with (manager.component.get!TransformComponent(entity))
			{
				pos = Vec3(0f);
				rotate_quat = Quaternion!float(Vec3(1.0f, 0.0f, 0.0f), 0f);
				scale = Vec3(0.6f);
			}
		}
		return;
	}

	void finalize(ObjectManager manager)
	{
		return;
	}

	void process(ObjectManager manager)
	{
		import std.math;

		foreach (index, entity; manager.entity.list)
		{
			float rad;
			scope TimerResource timer;

			timer = manager.resource.refer!TimerResource();
			with (manager.component.get!TransformComponent(entity))
			{
				rotate_quat =
					Quaternion!float(Vec3(1.0f, 1.0f, 0.0f), 0.5 * timer.past_time * inverse_usecs)
					* Quaternion!float(
						Vec3(0.0f, 1.0f, 1.0f), 0.8 * timer.past_time * inverse_usecs);
				rad = (inverse_usecs * timer.past_time) + (
					2.0f / manager.entity.count * PI) * index;
				pos = Vec3(cos(rad), 0f, sin(rad)) * 1.8f;
			}

		}
		return;
	}
}
