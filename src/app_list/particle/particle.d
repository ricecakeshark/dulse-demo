module app_list.particle.particle;

import app_list.app_interface;
import app_list.particle;

import dulse;
import dulse_sdl;
import dulse_gfx;

import std.math : PI_2;

class ParticleDemo : AppInterface
{
	Core core;
	TimerSubsystem timer;
	LoggerSubsystem logger;
	GraphicsContext gc;

	CommandBuffer cb;
	SwapchainTexture swapchain_texture;

	ComputePipeline pipeline_particle_process;
	GraphicsPipeline pipeline_particle;
	Texture depth_texture;
	ObjectManager object_manager;

	UniformScene uniform_scene;
	UniformView uniform_view = UniformView(
		transformer_look_at(Vec3(0f, 0f, -3.0f), Vec3(0f, 0f, 0f), Vec3(0f, 1f, 0f))
			* transformer_perspective(PI_2)
	);

	GpuBufferTransferBuffer bt_buffer;
	StorageBuffer particle_buffer;

	this(Core core)
	{
		this.core = core;
		this.gc = core.subsystem.query!GraphicsSubsystem()[0].context;
		return;
	}

	override void initialize()
	{
		core.subsystem.query(timer, logger);
		gc.create(cb, swapchain_texture,);
		// config
		swapchain_texture.set(
			GpuSwapchainComposition.HDR_extended_linear,
			GpuPresentMode.immediate,
		);
		// Entity

		core.subsystem.query!ObjectSubsystem()[0].create(object_manager);
		/+foreach (entity; entity_list)
		{
			object_manager.attach!TransformComponent(entity);
		}+/
		object_manager
			.append_resource(TimerResource(0))
			.initialize();

		// Pipeline
		create_pipeline_particle(
			gc, pipeline_particle,
		);
		gc.create_pipeline_particle_process(
			pipeline_particle_process,
		);

		// texture, sampler
		// depth texture
		gc.create(depth_texture);
		depth_texture.create(GpuTextureCreateInfo(
				GpuTextureType._2d,
				GpuTextureFormat.d32_float,
				GpuTextureUsageFlags.depth_stencil_target | GpuTextureUsageFlags.sampler,
				gc.client_width, gc.client_height,
				1, 1, GpuSampleCount.x1,
		));

		gc.create(
			bt_buffer, particle_buffer,
		);
		particle_buffer.create(
			Particle.sizeof * 10,
			GpuBufferUsageFlags.compute_storage_write,
		);
		bt_buffer.create(Particle.sizeof * 10);

		cb.acquire_buffer()
			.copy(
				sequence(bt_buffer, particle_buffer,),
			)
			.submit();

		return;
	}

	override void finalize()
	{
		gc.resource_store.release_all();
		return;
	}

	override void process()
	{
		with (object_manager.resource.query!TimerResource())
		{
			elapsed_time = cast(uint) timer.past;
		}
		return;
	}

	override void draw()
	{
		// process particle
		cb
			.acquire_buffer()
			.acquire_texture(swapchain_texture);
		if (swapchain_texture.handle !is null)
		{
			// process particle
			cb.compute(
				(pass) {
				pass
					.bind(
						pipeline_particle_process,
					)
					.dispatch(1, 1, 1);
				return;
			},
				particle_buffer,
			);

			// render particle
			cb.render(
				(render_pass) {
				// prepare pipeline_defer
				render_pass
					.push_vertex(0, uniform_scene, uniform_view,)
					.bind(
						pipeline_particle,
					)
					.draw(ParamPrimitive(20, 1, 0, 0,));
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
		cb.submit();
		return;
	}

	override int opCmp(Object other) const
	{
		return 0;
	}
}

struct Particle
{
	Vec4 pos;
}
