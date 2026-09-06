module app_list.guage.guage;

import app_list.app_interface;
import app_list.guage.uniform.guage;
import dulse;
import dulse_sdl;
import dulse_gfx;

class GuageDemo : AppInterface
{
	Core core;
	TimerSubsystem timer;
	LoggerSubsystem logger;
	GfxGraphicsContext graphics_context;

	GpuCommandBuffer command_buffer;
	GpuSwapchainTexture swapchain_texture;

	GpuComputePipeline guage_pipeline;
	GpuTexture guage_dst_texture;

	this(Core core)
	{
		this.core = core;
		this.graphics_context = core.subsystem.query!GfxGraphicsSubsystem().context;
		return;
	}

	override void initialize()
	{
		core.subsystem.query(timer, logger);
		graphics_context.create(command_buffer, swapchain_texture);

		// Compute Pipeline
		graphics_context.create(guage_pipeline);
		auto compute_pipeline_info = GpuComputePipelineCreateInfo(
			ShaderFile("guage.comp", GpuShaderFormat.spirv)
		);
		with (compute_pipeline_info)
		{
			//num_readonly_storage_buffers = 0;
			num_samplers = 0;
			num_readwrite_storage_textures = 1;
			num_uniform_buffers = 2;
			threadcount_x = 8;
			threadcount_y = 8;
			threadcount_z = 1;
		}
		guage_pipeline.create(
			compute_pipeline_info
		);
		graphics_context.create(guage_dst_texture);
		guage_dst_texture.create(
			GpuTextureCreateInfo(
				GpuTextureType._2d, GpuTextureFormat.r16g16b16a16_float,
				GpuTextureUsageFlags.compute_storage_write | GpuTextureUsageFlags.sampler,
				300, 300, 1, 1,
		)
		);
		return;
	}

	override void finalize()
	{
		graphics_context.resource_store.release_all();
		return;
	}

	override void process()
	{
		return;
	}

	override void draw()
	{
		import std.math;

		scope GpuColorTargetInfo color_target_info;

		command_buffer.acquire_buffer()
			.acquire_texture(swapchain_texture);
		if (swapchain_texture !is null)
		{
			color_target_info = GpuColorTargetInfo(
				swapchain_texture,
				0, 0,
				ColorF(0.2f, 0.2f, 0.2f, 1.0f,),
				GpuLoadOp.clear, GpuStoreOp.store,
			);
			command_buffer.compute(
				(compute_pass) {
				compute_pass.bind(guage_pipeline)
					.push(
						0, UniformGuageConst(),
						UniformGuageParam(0.4 + cos(timer.past * 0.001) * 0.3, -sin(
						timer.past * 0.001) * 0.1),
					)
					.dispatch(400 / 8, 400 / 8, 1);
				return;
			},
				[GpuStorageTextureReadWriteBinding(guage_dst_texture)],
				[],
			);
			// blit
			command_buffer.blit_texture(
				GpuBlitInfo(
					GpuBlitRegion(guage_dst_texture),
					GpuBlitRegion(swapchain_texture, 100, 100, 300, 300),
					GpuLoadOp.dont_care,
			)
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
