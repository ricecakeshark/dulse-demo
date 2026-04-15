module app_list.guage;

import app_list.app_interface;

import kelp_core;
import kelp_sdl;
import kelp_gfx;
import bindbc.sdl;

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

	this(Core core, GfxGraphicsContext graphics_context)
	{
		this.core = core;
		this.graphics_context = graphics_context;
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
				GpuTextureType._2d, GpuTextureFormat.r32g32b32a32_float,
				GpuTextureUsageFlags.compute_storage_write | GpuTextureUsageFlags.sampler,
				300, 300, 1, 1,
		)
		);
		/+
		command_buffer.acquire_buffer()
			.with_compute_pass([], [], (ref GpuComputePass pass) {
				pass.push_uniform(UniformGuageConst(), 0);
				return;
			}).submit();
+/
		return;
	}

	override void finalize()
	{
		graphics_context.release_all();
		return;
	}

	override void process()
	{
		return;
	}

	override void draw()
	{
		import std.math;

		GpuColorTargetInfo color_target_info;

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
			command_buffer.with_render_pass(
				[color_target_info],
				(ref GpuRenderPass pass) { return; });
			command_buffer.with_compute_pass(
				[GpuStorageTextureReadWriteBinding(guage_dst_texture)],
				[],
				(ref GpuComputePass pass) {
				pass.bind(guage_pipeline)
					.push_uniform(UniformGuageConst(), 0)
					.push_uniform(UniformGuageParam(0.4 + cos(timer.past * 0.001) * 0.3,-sin(timer.past * 0.001) * 0.1), 1)
					.dispatch(400 / 8, 400 / 8, 1);
				return;
			},);
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

struct UniformGuageConst
{
	align(16) Vec2 rel_pos = Vec2(200f, 200f);
	float inner_width = 30f;
	float outer_width = 100f;
	ColorF color_fg = ColorF(0.0f, 1.0f, 0.0f, 1.0f);
	ColorF color_bg = ColorF(0.1f, 0.1f, 0.1f, 1.0f);
	ColorF color_increase = ColorF(0.9f, 0.9f, 0.9f, 1.0f);
	ColorF color_decrease = ColorF(0.8f, 0.1f, 0.1f, 1.0f);
}

struct UniformGuageParam
{
	float guage_ratio = 0.4f;
	float delta_ratio = 0.0f;
}
