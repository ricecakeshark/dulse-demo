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
	SDLDeviceSubsystem device;
	TimerSubsystem timer;
	GfxGraphicsContext graphics_context;

	GfxRenderContext render_context;
	GfxGeometry!(VertexPCS, ushort) geometry;
	GpuGraphicsPipeline graphics_pipeline;
	GpuVertexBuffer vertex_buffer;
	GpuIndexBuffer index_buffer;
	GpuTexture texture;
	GpuSampler sampler;

	Surface image;

	this(Core core, GfxGraphicsContext graphics_context)
	{
		this.core = core;
		this.graphics_context = graphics_context;
		return;
	}

	void initialize()
	{
		// Shader
		scope GpuVertexShader vertex_shader;
		scope GpuFragmentShader fragment_shader;
		vertex_shader = graphics_context.create_vertex_shader();
		fragment_shader = graphics_context.create_fragment_shader();
		vertex_shader.create(
			ShaderFile("PositionColor.vert", graphics_context.get_shader_format()),
			GpuShaderArguments(0, 2, 0, 0),
		);
		fragment_shader.create(
			ShaderFile("SolidColor.frag", graphics_context.get_shader_format()),
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
				GpuVertexBufferDescription(
					0,
					float.sizeof * (3+4+1),
					GpuVertexInputRate.vertex,
					0
				)
			],
			[
				GpuVertexAttribute(
					0, 0, GpuVertexElementFormat.float3, 0
				),
				GpuVertexAttribute(
					1, 0, GpuVertexElementFormat.float4, float.sizeof * 3
				),
				GpuVertexAttribute(
					2, 0, GpuVertexElementFormat.float1, float.sizeof * 7
				)
			]
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

		// Geometry
		geometry.vertex = [
			VertexPCS(Vec3(-0.5f, -0.5f, 0.0f), ColorF(1.0f, 0.0f, 0.0f), 1.0f),
			VertexPCS(Vec3(+0.5f, -0.5f, 0.0f,), ColorF(0.0f, 1.0f, 0.0f), 1.0f),
			VertexPCS(Vec3(0.5f, +0.5f, 0.0f,), ColorF(0.0f, 0.0f, 1.0f), 1.0f),
			VertexPCS(Vec3(-0.5f, +0.5f, 0.0f,), ColorF(1.0f, 0.0f, 1.0f), 1.0f),
		];
		geometry.index = [0, 1, 2, 0, 2, 3];
		// Buffer
		vertex_buffer = graphics_context.create_vertex_buffer();
		vertex_buffer.create(geometry.size_vertex);
		index_buffer = graphics_context.create_index_buffer();
		index_buffer.create(geometry.size_index);

		// upload
		scope GpuBufferTransferBuffer buffer_transfer_buffer;
		buffer_transfer_buffer = new GpuBufferTransferBuffer(graphics_context.device);
		buffer_transfer_buffer.create(geometry.size)
			.map()
			.set(geometry.vertex, geometry.offset_vertex)
			.set(geometry.index, geometry.offset_index)
			.unmap();

		scope GfxUploadContext upload_context;
		upload_context = graphics_context.create_upload_context();
		upload_context.begin()
			.upload(
				GpuTransferBufferLocation(buffer_transfer_buffer, geometry.offset_vertex),
				GpuBufferRegion(vertex_buffer, 0u)
			)
			.upload(
				GpuTransferBufferLocation(buffer_transfer_buffer, geometry.offset_index),
				GpuBufferRegion(index_buffer, 0u)
			)
			.end()
			.submit();

		render_context = graphics_context.create_render_context();
		timer = core.subsystem.pool.query!(TimerSubsystem)();
		return;
	}

	void finalize()
	{
		graphics_context.release_all();
		return;
	}

	float x = 0.0f;
	float y = 0.0f;
	float z = 0.0f;

	void process()
	{

		return;
	}

	void draw()
	{
		import std.math;

		GpuColorTargetInfo color_target_info;
		Matrix!(4, 4) pos_mat;

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

				pos_mat = multiply_ltor(
					transformer_translate([0.0f, 0.0f, -80.0f]),
					transformer_scale([0.3f, 0.3f, 0.3f]),
					//transformer_rotate_z(cast(float)(timer.past * 0.001f * entity[0])),
				);
				render_context.push_vertex(pos_mat.transpose(), 0)
					.draw_indexed(ParamIndexedPrimitive(6, 1, 0, 0, 0));
				render_context.end();
				return;
			}).submit();
		return;
	}
}

struct VertexPCS
{
	Vec3 pos;
	ColorF color;
	float size;
}
