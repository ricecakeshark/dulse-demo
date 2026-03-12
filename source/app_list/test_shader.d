module app_list.test_shader;

import app_list.app_interface;

import app_list.app_interface;
import kelp_core;
import kelp_sdl;
import kelp_gfx;
import bindbc.sdl;

class ShaderTest : AppInterface
{
	Core core;
	TimerSubsystem timer;
	GfxGraphicsContext graphics_context;

	GfxRenderContext render_context;
	GfxMesh object_mesh;
	GfxGeometry!(VertexPC, uint) object_geometry;
	GpuGraphicsPipeline graphics_pipeline;
	GpuVertexBuffer vertex_buffer;
	GpuIndexBuffer index_buffer;

	this(Core core, GfxGraphicsContext graphics_context)
	{
		this.core = core;
		this.graphics_context = graphics_context;
		return;
	}

	override void initialize()
	{
		// Shader
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
		// Pipeline
		scope GpuGraphicsPipelineCreateInfo pipeline_create_info;
		pipeline_create_info.vertex_shader = vertex_shader.handle;
		pipeline_create_info.fragment_shader = fragment_shader.handle;
		with (pipeline_create_info)
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
					graphics_context.get_swapchain_texture_format()
				)
			]
			);
		}
		graphics_pipeline = graphics_context.create_graphics_pipeline();
		graphics_pipeline.create(pipeline_create_info);

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

		render_context = graphics_context.create_render_context();
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
		Matrix!(4, 4) view_mat, object_mat;

		view_mat = multiply_ltor(
			transformer_look_at(Vec3(0f, 0f, -20f), Vec3(0f, 0f, 0f), Vec3(0f, 1f, 0f)),
			transformer_perspective(PI_2),
		);

		render_context.acquire_buffer()
			.acquire_texture()
			.if_acquired(() {
				color_target_info = GpuColorTargetInfo(
					render_context.swapchain_texture,
					GpuLoadOp.clear, GpuStoreOp.store,
				);
				render_context.begin([color_target_info])
					.bind(graphics_pipeline)
					.bind([vertex_buffer])
					.bind(index_buffer);

				object_mat = multiply_rtol(
					transformer_rotate_x(0.0015 * timer.past),
					transformer_scale([10.0f, 10.0f, 10.0f]),
				);
				render_context.push_vertex(view_mat, 0)
					.push_vertex(object_mat, 1)
					.draw_indexed(ParamIndexedPrimitive(6, 1, 0, 0, 0));
				render_context.end();
				return;
			}).submit();
		return;
	}

	override int opCmp(Object other) const
	{
		return 0;
	}
}
