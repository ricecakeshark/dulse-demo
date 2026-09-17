module app_list.test_shader;

import app_list.app_interface;
import dulse;
import dulse_sdl;
import dulse_gfx;

class ShaderTest : AppInterface
{
	Core core;
	TimerSubsystem timer;
	GfxGraphicsContext graphics_context;

	GpuCommandBuffer command_buffer;
	GpuSwapchainTexture swapchain_texture;
	GfxMesh object_mesh;
	GfxGeometry!(VertexPC, uint) object_geometry;
	GpuGraphicsPipeline graphics_pipeline;
	GpuVertexBuffer vertex_buffer;
	GpuIndexBuffer index_buffer;

	this(Core core)
	{
		this.core = core;
		this.graphics_context = core.subsystem.query!GraphicsSubsystem().context;
		return;
	}

	override void initialize()
	{
		graphics_context.create(command_buffer, swapchain_texture);
		core.subsystem.query(timer);
		// Shader
		scope GpuVertexShader vertex_shader;
		scope GpuFragmentShader fragment_shader;
		graphics_context.create(graphics_pipeline, vertex_shader, fragment_shader);
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
			primitive_type = GpuPrimitiveType.triangle_list;
			target_info = GpuGraphicsPipelineTargetInfo(
				[
					GpuColorTargetDescription(
						swapchain_texture.get_format()
					)
				]
			);
		}
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
		graphics_context.create(vertex_buffer, index_buffer);
		vertex_buffer.create(4, VertexPC.sizeof);
		index_buffer.create(6, GpuIndexElementSize._32bit);

		// upload
		scope GpuBufferTransferBuffer buffer_transfer_buffer;
		graphics_context.create(buffer_transfer_buffer);
		buffer_transfer_buffer.create(object_geometry.size)
			.map()
			.set(object_geometry.vertices, object_geometry.offset_vertex)
			.set(object_geometry.indices, object_geometry.offset_index)
			.unmap();
		command_buffer
			.copy((ref GpuCopyPass copy_pass) {
				copy_pass.upload(
					GpuTransferBufferLocation(buffer_transfer_buffer, object_geometry.offset_vertex),
					GpuBufferRegion(vertex_buffer, 0u)
				)
					.upload(
						GpuTransferBufferLocation(buffer_transfer_buffer, object_geometry
						.offset_index),
						GpuBufferRegion(index_buffer, 0u)
					);
			}).submit();
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

		GpuColorTargetInfo color_target_info;
		Matrix!(4, 4) view_mat, object_mat;

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
			command_buffer.render(
				(ref GpuRenderPass pass) {
				object_mat = multiply_rtol(
					transformer_rotate_x(0.0015 * timer.past),
					transformer_scale([10.0f, 10.0f, 10.0f]),
				);
				pass.bind(graphics_pipeline)
					.bind([vertex_buffer])
					.bind(index_buffer)
					.push_vertex(0, view_mat, object_mat,)
					.draw_indexed(ParamIndexedPrimitive(6, 1, 0, 0, 0));
			},
				[color_target_info],
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
