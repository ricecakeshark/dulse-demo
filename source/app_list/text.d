module app_list.text;

import app_list.app_interface;

import kelp_core, kelp_sdl, kelp_gfx;
import bindbc.sdl;

import std.math;
import std.format;

immutable max_vertex_count = 4000;
immutable max_index_count = 6000;

class TextApp : AppInterface
{
	Core core;
	TimerSubsystem timer;

	GfxGraphicsContext graphics;
	GpuCommandBuffer command_buffer;
	GpuSwapchainTexture swapchain_texture;
	GfxTextContext text_context;

	GpuBufferTransferBuffer buffer_transfer_buffer;
	GpuTextureTransferBuffer texture_transfer_buffer;

	GpuGraphicsPipeline pipeline;

	alias TextureGeometry = GfxGeometry!(VertexPT, uint);
	GpuVertexBuffer vertex_buffer;
	GpuIndexBuffer index_buffer;
	GfxMesh text_mesh;
	GpuRefTexture[] text_texture;
	GpuSampler sampler;

	Matrix!(4, 4) transformer_projection, transformer_model;

	this(Core core, GfxGraphicsContext graphics)
	{
		this.core = core;
		this.graphics = graphics;
		return;
	}

	void initialize()
	{
		core.subsystem.query(timer);
		graphics.create(command_buffer, swapchain_texture);
		// pipeline, vertex shader, fragment shader
		scope GpuVertexShader vertex_shader;
		scope GpuFragmentShader fragment_shader;
		graphics.create(pipeline, vertex_shader, fragment_shader);
		vertex_shader.create(
			ShaderFile("text.vert", graphics.device.get_shader_format()), //ShaderFile("const_position.vert", graphics.device.get_shader_format()),
			GpuShaderArguments(0, 2, 0, 0),
		);
		fragment_shader.create(
			ShaderFile("text.frag", graphics.device.get_shader_format()),
			GpuShaderArguments(1, 1, 0, 0),
		);
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
					graphics.get_swapchain_texture_format(),
					GpuColorTargetBlendState(
						GpuBlendFactor.src_alpha,
						GpuBlendFactor.one_minus_src_alpha,
						GpuBlendOp.add,
						GpuBlendFactor.src_alpha,
						GpuBlendFactor.dst_alpha,
						GpuBlendOp.add,
						cast(GpuColorComponentFlags) 0xF,
						true,
				)
				)
			]
			);
			rasterizer_state.cull_mode = GpuCullMode.none;
		}
		pipeline.create(pipeline_create_info);

		// geometry
		text_mesh.initialize(
			VertexPT.sizeof * max_vertex_count,
			uint.sizeof * max_index_count,
		);
		// vertex buffer
		graphics.create(vertex_buffer, index_buffer);
		vertex_buffer.create(max_vertex_count, VertexPT.sizeof);
		index_buffer.create(max_index_count, GpuIndexElementSize._32bit);

		// sampler
		graphics.create(sampler);
		sampler.create(
			GpuSamplerCreateInfo(
				GpuFilter.linear,
				GpuFilter.linear,
		)
		);
		// text
		graphics.create(text_context);
		text_context.load_font("HackGen-Regular.ttf", 50.0f)
			.set_SDF(true)
			.set(TextAlign.center)
			.create_engine()
			.create_text("TEXT");

		// upload
		graphics.create(
			buffer_transfer_buffer,
			texture_transfer_buffer,
		);
		buffer_transfer_buffer.create_by_size(
			VertexPT.sizeof * max_vertex_count + uint.sizeof * max_index_count
		);
		return;
	}

	void finalize()
	{
		return;
	}

	void process()
	{
		return;
	}

	void draw()
	{
		GpuColorTargetInfo color_target_info;
		uint vertex_offset;
		uint index_offset;
		vertex_offset = 0;
		index_offset = 0;
		int tw, th;

		// text
		string test_str = format("ABCDE 12345\n縁取り文字\n%s ms", timer.past);
		text_context.set(test_str)
			.get_text_size(tw, th)
			.get_draw_data!(TextureGeometry)(text_mesh, text_texture);

		// matrix
		transformer_projection = multiply_ltor(
			transformer_look_at(Vec3(0f, 0f, -80f), Vec3(0f, 0f, 0f), Vec3(0f, 1f, 0f)),
			transformer_perspective(PI_2,),
		);
		transformer_model = multiply_ltor(
			transformer_translate([-tw / 2.0f, th / 2.0f, 0.0f]),
			transformer_scale([0.5f, 0.5f, 0.5f]),
			transformer_rotate_y(cast(float)(timer.past * 0.001f)),
		);
		// transfer
		buffer_transfer_buffer.map()
			.set(text_mesh.vertices!(TextureGeometry), text_mesh.offset_vertex,)
			.set(text_mesh.indices!(TextureGeometry), text_mesh.offset_index,)
			.unmap();

		// upload
		command_buffer.acquire_buffer()
			.with_copy_pass((ref GpuCopyPass pass) {
				pass.upload(
					buffer_transfer_buffer,
					vertex_buffer,
					index_buffer,
				);
				return;
			})
			.submit();

		command_buffer.acquire_buffer()
			.acquire_texture(swapchain_texture);
		if (swapchain_texture.handle !is null)
		{
			color_target_info = GpuColorTargetInfo(
				swapchain_texture,
				GpuLoadOp.clear, GpuStoreOp.store,
			);
			color_target_info.clear_color = ColorF(0.4f, 0.6f, 0.8f, 1.0f);
			command_buffer.with_render_pass(
				[color_target_info],
				(ref GpuRenderPass pass) {
				// swapchain texture

				pass.bind(pipeline)
					.bind([vertex_buffer])
					.bind(index_buffer);
				pass.push_vertex(transformer_projection, 0)
					.push_vertex(transformer_model, 1)
					.push_fragment(
						UniformFragmentConfig(
						ColorF(1.0f, 1.0f, 1.0f, 1.0f),
						ColorF(0.0f, 0.0f, 0.0f, 1.0f),
						ColorF(0.5f, 0.5f, 0.5f, 1.0f),
						0.50f, 0.1f, 0.4f, 0.2f,
					),
					0,
				);
				foreach (count; 0 .. text_mesh.count!(TextureGeometry))
				{
					TextureGeometry temp_geometry = text_mesh.geometries!(TextureGeometry)[count];
					pass.bind([
						GpuTextureSamplerBinding(text_texture[count].handle, sampler.handle)
					])
						.draw_indexed(ParamIndexedPrimitive(
							cast(uint) temp_geometry.count_index,
							1u, index_offset, vertex_offset, 0u
						));
					vertex_offset += temp_geometry.count_vertex;
					index_offset += temp_geometry.count_index;
				}
				return;
			}
			);

		}
		command_buffer.submit();
		/+foreach (texture; text_texture)
		{
			SDL_ReleaseGPUTexture(graphics.device.handle, texture.handle);
		}+/

		return;
	}
}

struct UniformBuffer
{
	UniformVertexView vert_view;
	UniformVertexModel vert_model;
}

struct UniformVertexView
{
	Matrix!(4, 4) view_matrix;
}

struct UniformVertexModel
{
	Matrix!(4, 4) model_matrix;
}

struct UniformFragmentConfig
{
	ColorF color_line;
	ColorF color_outline;
	ColorF color_grow;
	float width_edge;
	float width_outline;
	float width_grow;
	float softness;
}
