module app_list.compute;

import app_list.app_interface;
import kelp_core;
import kelp_sdl;
import kelp_gfx;
import bindbc.sdl;

class ComputeDemo : AppInterface
{
	Core core;
	TimerSubsystem timer;
	GfxGraphicsContext graphics_context;
	GfxComputeContext compute_context;
	GfxRenderContext render_context;

	GpuGraphicsPipeline render_pipeline;
	GpuComputePipeline compute_pipeline;
	GfxMesh object_mesh;
	GfxGeometry!(VertexPC, uint) object_geometry;

	GpuVertexBuffer vertex_buffer;
	GpuIndexBuffer index_buffer;

	GpuTexture compute_in_texture, compute_out_texture;
	GpuSampler sampler;

	this(Core core, GfxGraphicsContext graphics_context)
	{
		this.core = core;
		this.graphics_context = graphics_context;
		return;
	}

	override void initialize()
	{
		// Render Shader
		scope GpuVertexShader vertex_shader;
		scope GpuFragmentShader fragment_shader;
		vertex_shader = graphics_context.create_vertex_shader();
		fragment_shader = graphics_context.create_fragment_shader();
		vertex_shader.create(
			ShaderFile("vertex_color.vert", graphics_context.get_shader_format()),
			GpuShaderArguments(0, 2, 0, 0),
		);
		fragment_shader.create(
			ShaderFile("vertex_color.frag", graphics_context.get_shader_format()),
			GpuShaderArguments(0, 0, 0, 0),
		);
		// Render Pipeline
		scope GpuGraphicsPipelineCreateInfo render_pipeline_info;
		render_pipeline_info.vertex_shader = vertex_shader.handle;
		render_pipeline_info.fragment_shader = fragment_shader.handle;
		with (render_pipeline_info)
		{
			vertex_input_state = GpuVertexInputState(
				[
					vertex_buffer_description!(float[3], float[4])
				],
				vertex_attributes!(float[3], float[4])(0),
			);
			primitive_type = SDL_GPU_PRIMITIVETYPE_TRIANGLELIST;
			target_info = GpuGraphicsPipelineTargetInfo(
				[
				GpuColorTargetDescription(
					//graphics_context.get_swapchain_texture_format()
					GpuTextureFormat.r32g32b32a32_float
				)
			]
			);
		}
		render_pipeline = graphics_context.create_graphics_pipeline();
		render_pipeline.create(render_pipeline_info);

		// Compute Pipeline
		compute_pipeline = this.graphics_context.create_compute_pipeline();
		auto compute_pipeline_info = GpuComputePipelineCreateInfo(
			ShaderFile("compute.comp", GpuShaderFormat.spirv)
		);
		with (compute_pipeline_info)
		{
			//num_readonly_storage_buffers = 0;
			num_samplers = 1;
			num_readwrite_storage_textures = 1;
			num_uniform_buffers = 1;
			threadcount_x = 8;
			threadcount_y = 8;
			threadcount_z = 1;
		}
		compute_pipeline.create(
			compute_pipeline_info
		);

		// texture
		compute_in_texture = graphics_context.create_texture();
		compute_in_texture.create(GpuTextureCreateInfo(
				GpuTextureType._2d, GpuTextureFormat.r32g32b32a32_float,
				GpuTextureUsageFlags.sampler | GpuTextureUsageFlags.color_target | GpuTextureUsageFlags.compute_storage_read,
				960, 540, 1, 1,
		));

		compute_out_texture = graphics_context.create_texture();
		compute_out_texture.create(GpuTextureCreateInfo(
				GpuTextureType._2d, GpuTextureFormat.r32g32b32a32_float,
				GpuTextureUsageFlags.sampler | GpuTextureUsageFlags.compute_storage_write,
				960, 540, 1, 1,
		));
		// sampler
		sampler = graphics_context.create_sampler();
		sampler.create(GpuSamplerCreateInfo(
				GpuFilter.nearest,
				GpuFilter.nearest,
				GpuSamplerMipmapMode.nearest,
				GpuSamplerAddressMode.clamp_to_edge,
				GpuSamplerAddressMode.clamp_to_edge,
				GpuSamplerAddressMode.clamp_to_edge,
		));
		// Mesh

		object_mesh.initialize(VertexPC.sizeof * 4, uint.sizeof * 6);
		object_geometry.set(
			[
			VertexPC(Vec3(-0.5f, -0.5f, 0.0f), ColorF(1.0f, 0.0f, 0.0f)),
			VertexPC(Vec3(+0.5f, -0.5f, 0.0f,), ColorF(0.0f, 1.0f, 0.0f)),
			VertexPC(Vec3(+0.5f, +0.5f, 0.0f,), ColorF(0.0f, 0.0f, 1.0f)),
			VertexPC(Vec3(-0.5f, +0.5f, 0.0f,), ColorF(1.0f, 0.0f, 1.0f)),
		],
		[
			0u, 1, 2, 0, 2, 3
		],
		);
		object_mesh.set([object_geometry]);
		// Buffer
		vertex_buffer = graphics_context.create_vertex_buffer();
		vertex_buffer.create(4, VertexPC.sizeof);
		index_buffer = graphics_context.create_index_buffer();
		index_buffer.create(6, GpuIndexElementSize._32bit);

		// upload
		scope GpuBufferTransferBuffer buffer_transfer_buffer;
		buffer_transfer_buffer = new GpuBufferTransferBuffer(graphics_context.device);
		buffer_transfer_buffer.create(object_geometry.size)
			.map()
			.set(object_geometry.vertices, object_geometry.offset_vertex)
			.set(object_geometry.indices, object_geometry.offset_index)
			.unmap();

		scope GfxUploadContext upload_context;
		upload_context = graphics_context.create_upload_context();
		upload_context.begin()
			.upload(
				GpuTransferBufferLocation(buffer_transfer_buffer, object_geometry.offset_vertex),
				GpuBufferRegion(vertex_buffer, 0u)
			)
			.upload(
				GpuTransferBufferLocation(buffer_transfer_buffer, object_geometry.offset_index),
				GpuBufferRegion(index_buffer, 0u)
			)
			.end()
			.submit();

		compute_context = graphics_context.create_compute_context();
		core.subsystem.query(timer);
		
		command_buffer = new GpuCommandBuffer(graphics_context.device, graphics_context.window);
		swapchain_texture = new GpuSwapchainTexture(
			graphics_context.device,
			graphics_context.window,
		);
		render_pass = new GpuRenderPass();
		compute_pass = new GpuComputePass();
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

	GpuCommandBuffer command_buffer;
	GpuSwapchainTexture swapchain_texture;
	GpuRenderPass render_pass;
	GpuComputePass compute_pass;

	override void draw()
	{
		import std.math;

		GpuColorTargetInfo color_target_info;

		Matrix!(4, 4) view_mat, object_mat;
		float delta = 0.0f;
		delta += 0.1f;

		view_mat = multiply_ltor(
			transformer_look_at(Vec3(0f, 0f, -20f), Vec3(0f, 0f, 0f), Vec3(0f, 1f, 0f)),
			transformer_perspective(PI_2),
		);

		command_buffer.acquire_buffer();
		command_buffer.acquire_texture(swapchain_texture);
		if (swapchain_texture.handle !is null)
		{
			object_mat = multiply_rtol(
				transformer_rotate_x(0.0015 * timer.past),
				transformer_scale([20.0f, 20.0f, 20.0f]),
			);
			// color target
			color_target_info = GpuColorTargetInfo(
				compute_in_texture,
				GpuLoadOp.clear,
				GpuStoreOp.store
			);
			// render
			render_pass.begin(command_buffer, [color_target_info])
				.bind(render_pipeline)
				.bind([compute_in_texture], 0)
				.bind([vertex_buffer])
				.bind(index_buffer);
			command_buffer.push_vertex(view_mat, 0)
				.push_vertex(object_mat, 1);
			render_pass.draw_indexed(ParamIndexedPrimitive(6, 1, 0, 0, 0))
				.end();

			// compute
			compute_pass.begin(command_buffer, [
					GpuStorageTextureReadWriteBinding(compute_out_texture)
				])
				.bind(compute_pipeline)
				.bind([GpuTextureSamplerBinding(compute_in_texture, sampler)], 0);
			command_buffer.push_uniform(Vec3([delta, 960f, 540f]));
			compute_pass.dispatch(cast(uint) ceil(960.0 / 8), cast(uint) ceil(540.0 / 8), 1)
				.end();

			// blit
			command_buffer.blit_texture(
				GpuBlitInfo(
					GpuBlitRegion(compute_out_texture),
					GpuBlitRegion(swapchain_texture),
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
