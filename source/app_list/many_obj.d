module app_list.many_obj;

import app_list.app_interface;
import kelp_core;
import kelp_sdl;
import kelp_gfx;
import bindbc.sdl;

class ManyObject : AppInterface
{
	Core core;
	TimerSubsystem timer;
	GfxGraphicsContext graphics_context;

	GpuSwapchainTexture swapchain_texture;
	GpuCommandBuffer command_buffer;

	GfxMesh object_mesh;
	alias ObjectGeometry = GfxGeometry!(VertexPT, uint);
	GpuGraphicsPipeline graphics_pipeline;
	GpuVertexBuffer vertex_buffer;
	GpuIndexBuffer index_buffer;
	GpuTexture object_texture;
	GpuSampler object_sampler;
	Surface object_image;

	float[3][100] entity_list;

	this(Core core, GfxGraphicsContext graphics_context)
	{
		this.core = core;
		this.graphics_context = graphics_context;
		return;
	}

	override void initialize()
	{
		foreach (ref entity; entity_list)
		{
			import std.random;

			entity[0] = uniform(0.5f, 1.3f);
			entity[1] = uniform(0.5f, 1.3f);
			entity[2] = uniform(0.5f, 1.3f);
		}
		// Shader

		scope GpuVertexShader vertex_shader;
		scope GpuFragmentShader fragment_shader;
		graphics_context.create(graphics_pipeline, vertex_shader, fragment_shader);
		vertex_shader.create(
			ShaderFile("texture.vert", graphics_context.get_shader_format()),
			GpuShaderArguments(0, 2, 0, 0),
		);
		fragment_shader.create(
			ShaderFile("texture.frag", graphics_context.get_shader_format()),
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
					vertex_buffer_description!(float[3], float[2])
				],
				vertex_attributes!(float[3], float[2])(0),
			);
			primitive_type = SDL_GPU_PRIMITIVETYPE_TRIANGLELIST;
			target_info = GpuGraphicsPipelineTargetInfo(
				[
				GpuColorTargetDescription(
					graphics_context.get_swapchain_texture_format(),
					GpuColorTargetBlendState(
						GpuBlendFactor.src_alpha,
						GpuBlendFactor.one_minus_src_alpha,
						GpuBlendOp.add,
						GpuBlendFactor.src_alpha,
						GpuBlendFactor.one_minus_src_alpha,
						GpuBlendOp.add,
						cast(GpuColorComponentFlags) SDL_GPUColorComponentFlags.init,
						true,
				)
				)
			]
			);
		}
		graphics_pipeline.create(pipeline_create_info);

		// Mesh, Geometry
		ObjectGeometry object_geometry;
		object_mesh.initialize(VertexPT.sizeof * 4, uint.sizeof * 6);
		object_geometry = ObjectGeometry([
			VertexPT(Vec3(-0.5f, -0.5f, 0.0f), Vec2(0.0f, 0.0f,),),
			VertexPT(Vec3(+0.5f, -0.5f, 0.0f,), Vec2(1.0f, 0.0f,),),
			VertexPT(Vec3(0.5f, +0.5f, 0.0f,), Vec2(1.0f, 1.0f,),),
			VertexPT(Vec3(-0.5f, +0.5f, 0.0f,), Vec2(0.0f, 1.0f,),),
		],
		[0, 1, 2, 0, 2, 3],
		);
		object_mesh.set([object_geometry,]);

		// Buffer
		graphics_context.create(vertex_buffer, index_buffer);
		vertex_buffer.create(
			object_geometry.count_vertex,
			object_geometry.stride_vertex
		);
		index_buffer.create(
			object_geometry.count_index,
			GpuIndexElementSize._32bit
		);

		// texture, sampler
		object_image = new Surface();
		object_image.load("./image/dot4.png");
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
		scope GpuBufferTransferBuffer buffer_transfer_buffer;
		buffer_transfer_buffer = new GpuBufferTransferBuffer(graphics_context.device);
		buffer_transfer_buffer.create(object_geometry.size)
			.map()
			.set(object_geometry.vertices, object_geometry.offset_vertex)
			.set(object_geometry.indices, object_geometry.offset_index)
			.unmap();

		scope GpuTextureTransferBuffer texture_transfer_buffer;
		texture_transfer_buffer = new GpuTextureTransferBuffer(graphics_context.device);
		texture_transfer_buffer.create(object_image.size)
			.map()
			.set(object_image)
			.unmap();

		scope GfxUploadContext upload_context;
		graphics_context.create(upload_context);
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
		core.subsystem.query(timer);
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
		Matrix!(4, 4) view_mat, pos_mat;

		view_mat = multiply_ltor(
			transformer_look_at(Vec3(0f, 0f, -20f), Vec3(0f, 0f, 0f), Vec3(0f, 1f, 0f)),
			transformer_perspective(PI_2),
		);

		command_buffer.acquire_buffer()
			.acquire_texture(swapchain_texture);
		if (swapchain_texture !is null)
		{
			color_target_info = GpuColorTargetInfo(
				swapchain_texture,
				GpuLoadOp.clear, GpuStoreOp.store,
			);
			command_buffer.with_render_pass(
				[color_target_info],
				(ref GpuRenderPass pass) {
				pass.bind(graphics_pipeline)
					.bind([
						GpuTextureSamplerBinding(object_texture, object_sampler)
					], 0)
					.bind([vertex_buffer])
					.bind(index_buffer);
				foreach (entity; entity_list)
				{
					pos_mat = multiply_ltor(
						transformer_scale([10.0f, 10.0f, 10.0f]),
						transformer_rotate_z(timer.past * 0.002f * entity[0]),
						transformer_translate([
							cos((0.0012f * timer.past) * entity[0]) * 10.0f,
							sin((0.0013f * timer.past) * entity[1]) * 10.0f,
							cos((0.0015f * timer.past) * entity[0]) * 10.0f
						]),
					);
					pass.push_vertex(view_mat, 0)
						.push_vertex(pos_mat, 1)
						.push_fragment(
							Vector!(4)(
							cos((0.001f * timer.past) * entity[1])
							.fabs() * 0.9f,
							cos((0.001f * timer.past) * entity[2])
							.fabs() * 0.9f,
							1.0f, 1.0f),
							0,
						)
						.draw_indexed(ParamIndexedPrimitive(6, 1, 0, 0, 0));
				}
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
