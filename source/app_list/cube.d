module app_list.cube;

import app_list.app_interface;

import app_list.app_interface;
import kelp_core;
import kelp_sdl;
import kelp_gfx;
import bindbc.sdl;

class CubeDemo : AppInterface
{
	Core core;
	TimerSubsystem timer;
	LoggerSubsystem logger;
	GfxGraphicsContext graphics_context;

	//GfxRenderContext render_context;
	GpuCommandBuffer command_buffer;
	GpuSwapchainTexture swapchain_texture;
	GfxMesh object_mesh;
	GfxGeometry!(VertexPNU, uint) object_geometry;
	GpuGraphicsPipeline graphics_pipeline;
	GpuVertexBuffer vertex_buffer;
	GpuIndexBuffer index_buffer;
	GpuTexture depth_texture;

	Surface object_image;
	GpuTexture object_texture;
	GpuSampler object_sampler;

	this(Core core, GfxGraphicsContext graphics_context)
	{
		this.core = core;
		this.graphics_context = graphics_context;
		return;
	}

	override void initialize()
	{
		core.subsystem.query(timer, logger);
		// Shader
		scope GpuVertexShader vertex_shader;
		scope GpuFragmentShader fragment_shader;
		graphics_context.create(graphics_pipeline, vertex_shader, fragment_shader);
		vertex_shader.create(
			ShaderFile("texture_2.vert", graphics_context.get_shader_format()),
			GpuShaderArguments(0, 2, 0, 0),
		);
		fragment_shader.create(
			ShaderFile("texture_2.frag", graphics_context.get_shader_format()),
			GpuShaderArguments(1, 1, 0, 0),
		);
		// Pipeline
		scope GpuGraphicsPipelineCreateInfo pipeline_create_info;
		pipeline_create_info.vertex_shader = vertex_shader.handle;
		pipeline_create_info.fragment_shader = fragment_shader.handle;
		with (pipeline_create_info)
		{

			vertex_input_state = GpuVertexInputState(
				[
					vertex_buffer_description!(float[3], float[3], float[2])
				],
				vertex_attributes!(float[3], float[3], float[2])(0),
			);
			primitive_type = SDL_GPU_PRIMITIVETYPE_TRIANGLELIST;
			depth_stencil_state = GpuDepthStencilState(
				GpuCompareOp.less,
				GpuStencilOpState.init,
				GpuStencilOpState.init,
				0u, 0u,
				true, true, false,
			);
			target_info = GpuGraphicsPipelineTargetInfo(
				[
				GpuColorTargetDescription(
					graphics_context.get_swapchain_texture_format()
				)
			], GpuTextureFormat.d32_float,
			);
		}
		graphics_pipeline.create(pipeline_create_info);

		// Geometry
		FileHandler("cube.obj").load_obj(object_geometry);
		import std.exception;
		enforce(object_geometry.size > 0);
		import std.conv;

		logger.log(to!string(object_geometry.vertices.length), LogLevel.info);
		logger.log(to!string(object_geometry.indices.length), LogLevel.info);

		/+object_geometry.set(
			[
			VertexPNU(Vec3(-0.5f, -0.5f, 0.0f), ColorF(1.0f, 0.0f, 0.0f)),
			VertexPNU(Vec3(+0.5f, -0.5f, 0.0f,), ColorF(0.0f, 1.0f, 0.0f)),
			VertexPNU(Vec3(+0.5f, +0.5f, 0.0f,), ColorF(0.0f, 0.0f, 1.0f)),
			VertexPNU(Vec3(-0.5f, +0.5f, 0.0f,), ColorF(1.0f, 0.0f, 1.0f)),
		],
		[
			0u, 1, 2, 0, 2, 3
		],
		);+/
		// Mesh
		object_mesh.initialize(
			VertexPNU.sizeof * object_geometry.count_vertex,
			uint.sizeof * object_geometry.count_index,
		);
		object_mesh.set([object_geometry]);
		// Buffer
		graphics_context.create(vertex_buffer, index_buffer);
		vertex_buffer.create(object_geometry.count_vertex, VertexPNU.sizeof);
		index_buffer.create(object_geometry.count_index, GpuIndexElementSize._32bit);

		// depth texture
		graphics_context.create(depth_texture);
		depth_texture.create(GpuTextureCreateInfo(
				GpuTextureType._2d,
				GpuTextureFormat.d32_float,
				GpuTextureUsageFlags.depth_stencil_target,
				960, 540,
				1, 1, GpuSampleCount.x1,
		));

		// texture, sampler
		object_image = new Surface();
		object_image.load("./image/test_texture.png");
		graphics_context.create(object_texture, object_sampler);
		object_texture.create(GpuTextureCreateInfo(
				GpuTextureType._2d, GpuTextureFormat.r8g8b8a8_unorm,
				GpuTextureUsageFlags.sampler,
				object_image.width, object_image.height,
				1, 1,
		));
		object_sampler.create(GpuSamplerCreateInfo(
				GpuFilter.nearest,
				GpuFilter.nearest,
				GpuSamplerMipmapMode.nearest,
				GpuSamplerAddressMode.clamp_to_edge,
				GpuSamplerAddressMode.clamp_to_edge,
				GpuSamplerAddressMode.clamp_to_edge,
		));

		// upload
		scope GfxUploadContext upload_context;
		scope GpuBufferTransferBuffer buffer_transfer_buffer;
		scope GpuTextureTransferBuffer texture_transfer_buffer;
		graphics_context.create(upload_context, buffer_transfer_buffer, texture_transfer_buffer);
		buffer_transfer_buffer.create(object_geometry.size)
			.map()
			.set(object_geometry.vertices, object_geometry.offset_vertex)
			.set(object_geometry.indices, object_geometry.offset_index)
			.unmap();
		texture_transfer_buffer.create(object_image.size)
			.map()
			.set(object_image)
			.unmap();
		upload_context.begin()
			.upload(
				GpuTransferBufferLocation(buffer_transfer_buffer, object_geometry.offset_vertex),
				GpuBufferRegion(vertex_buffer, 0u)
			)
			.upload(
				GpuTransferBufferLocation(buffer_transfer_buffer, object_geometry.offset_index),
				GpuBufferRegion(index_buffer, 0u)
			)
			.upload(
				GpuTextureTransferInfo(texture_transfer_buffer, 0),
				GpuTextureRegion(object_texture.handle, 0, 0, 0, 0, 0, object_image.width, object_image.height, 1)
			)
			.end()
			.submit();

		graphics_context.create(command_buffer, swapchain_texture);
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
		GpuDepthStencilTargetInfo depth_target_info;
		Matrix!(4, 4) view_mat, object_mat;

		view_mat = multiply_ltor(
			transformer_look_at(Vec3(0f, 0f, -2.5f), Vec3(0f, 0f, 0f), Vec3(0f, 1f, 0f)),
			transformer_perspective(PI_2),
		);
		Vec3 light_pos;
		//light_pos = [sin(0.002f*timer.past)*10f,0f,cos(0.002f*timer.past)*10f];
		light_pos = [+10f,0f,-10f];

		command_buffer.acquire_buffer()
			.acquire_texture(swapchain_texture);
		if (swapchain_texture !is null)
		{
			color_target_info = GpuColorTargetInfo(
				swapchain_texture,
				GpuLoadOp.clear, GpuStoreOp.store,
			);
			depth_target_info = GpuDepthStencilTargetInfo(
				depth_texture.handle,
				1.0f,
				GpuLoadOp.clear,
				GpuStoreOp.dont_care,
			);
			command_buffer.with_render_pass(
				[color_target_info],
				depth_target_info,
				(ref GpuRenderPass pass) {
				object_mat = multiply_rtol(
					transformer_rotate_y(0.0015 * timer.past),
					transformer_scale([1.0f, 1.0f, 1.0f]),
				);
				pass.bind(graphics_pipeline)
					.bind([
						GpuTextureSamplerBinding(object_texture, object_sampler)
					], 0)
					.bind([vertex_buffer])
					.bind(index_buffer)
					.push_vertex(view_mat, 0)
					.push_vertex(object_mat, 1)
					.push_fragment(light_pos, 0)
					.draw_indexed(ParamIndexedPrimitive(cast(uint) object_geometry.count_index, 1, 0, 0, 0));
			},);
		}
		command_buffer.submit();
		return;
	}

	override int opCmp(Object other) const
	{
		return 0;
	}
}
