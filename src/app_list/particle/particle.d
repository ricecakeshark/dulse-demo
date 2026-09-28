module app_list.particle.particle;

import app_list.app_interface;
import app_list.particle;

import dulse;
import dulse_sdl;
import dulse_gfx;

import std.math : PI_2;

class Particle : AppInterface
{
	Core core;
	TimerSubsystem timer;
	LoggerSubsystem logger;
	GfxGraphicsContext graphics_context;

	GpuGraphicsPipeline pipeline_particle;
	GpuTexture depth_texture;
	ObjectManager object_manager;

	UniformScene uniform_scene;
	UniformView uniform_view = UniformView(
		transformer_look_at(Vec3(0f, 0f, -3.0f), Vec3(0f, 0f, 0f), Vec3(0f, 1f, 0f))
			* transformer_perspective(PI_2)
	);

	this(Core core)
	{
		this.core = core;
		this.graphics_context = core.subsystem.query!GraphicsSubsystem().context;
		return;
	}

	override void initialize()
	{
		core.subsystem.query(timer, logger);
		graphics_context.create(command_buffer, swapchain_texture,);
		// config
		/+swapchain_texture.set(
			GpuSwapchainComposition.HDR_extended_linear,
			GpuPresentMode.immediate,
		);+/
		// Entity

		core.subsystem.query!ObjectSubsystem().create(object_manager);
		/+foreach (entity; entity_list)
		{
			object_manager.attach!TransformComponent(entity);
		}+/
		object_manager
			.append_resource(TimerResource(0))
			.initialize();

		// Pipeline
		create_pipeline_particle(graphics_context, pipeline_particle);

		// texture, sampler
		// depth texture
		graphics_context.create(depth_texture);
		depth_texture.create(GpuTextureCreateInfo(
				GpuTextureType._2d,
				GpuTextureFormat.d32_float,
				GpuTextureUsageFlags.depth_stencil_target | GpuTextureUsageFlags.sampler,
				graphics_context.client_width, graphics_context.client_height,
				1, 1, GpuSampleCount.x1,
		));
		return;
	}

	override void finalize()
	{
		graphics_context.resource_store.release_all();
		return;
	}

	override void process()
	{
		with (object_manager.resource_store.refer!TimerResource())
		{
			elapsed_time = cast(uint) timer.past;
		}
		return;
	}

	GpuCommandBuffer command_buffer;
	GpuSwapchainTexture swapchain_texture;

	override void draw()
	{
		// render
		command_buffer
			.acquire_buffer()
			.acquire_texture(swapchain_texture);
		if (swapchain_texture.handle !is null)
		{
			// g-buffer
			command_buffer.render(
				(render_pass) {
				// prepare pipeline_defer
				render_pass
					.push_vertex(0, uniform_scene, uniform_view,)
					.bind(
						pipeline_particle,
					)
					.draw(ParamPrimitive(100, 1, 0, 0,));
			},
				[
					GpuColorTargetInfo(
						swapchain_texture, GpuLoadOp.clear, GpuStoreOp.store,
					),
				],
				GpuDepthStencilTargetInfo(
					depth_texture.handle,
					1.0f,
					GpuLoadOp.clear, GpuStoreOp.dont_care,
			),
			);
		}
		command_buffer.submit();
		return;
	}

	override int opCmp(Object other) const
	{
		return 0;
	}
}
