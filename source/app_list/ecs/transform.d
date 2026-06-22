module app_list.ecs.transform;

import app_list.ecs;

import kelp_core.object;
import kelp_core.math;

struct TransformComponent
{
	Vec3 pos;
	Vec3 rotate;
	Vec3 scale;

	Matrix!(4, 4, float) model_matrix(float scale = 1.0f)
	{
		return multiply_rtol(
			transformer_translate(this.pos),
			transformer_rotate_y(this.rotate.y),
			transformer_rotate_x(this.rotate.x),
			transformer_scale(this.scale * scale),
		);
	}
}

class TransformSystem : IObjectSystem
{
	void initialize(ObjectManager manager)
	{
		foreach (entity; manager.entity.list)
		{
			with (manager.component.get!TransformComponent(entity))
			{
				pos = Vec3(0f);
				rotate = Vec3(0f);
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
			TimerResource timer;
			timer = manager.resource.refer!TimerResource();
			with (manager.component.get!TransformComponent(entity))
			{
				rotate.x += cast(float) 0.5 * 0.001 * timer.delta_time;
				rotate.y += cast(float) 1.5 * 0.001 * timer.delta_time;
				rad = (0.001f * timer.past_time) + (
					2.0f / manager.entity.count * PI) * index;
				pos = Vec3(cos(rad) * 1.5f, 0f, sin(rad) * 1.5f);
			}

		}
		return;
	}
}
