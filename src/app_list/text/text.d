module app_list.text.text;

import app_list.app_interface;
import app_list.text;

import dulse;
import dulse_sdl.graphics;
import dulse_sdl.text;
import dulse_gfx;

import std.math : PI_2;
import std.format : format;

immutable max_vertex_count = 4000;
immutable max_index_count = 6000;
immutable inverse_usecs = 0.001f * 0.001f;

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

	this(Core core)
	{
		this.core = core;
		this.graphics = core.subsystem.query!GfxGraphicsSubsystem().context;
		return;
	}

	void initialize()
	{
		core.subsystem.query(timer);
		graphics.create(command_buffer, swapchain_texture);
		// pipeline, vertex shader, fragment shader
		graphics.create_pipeline_text(pipeline);

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
		text_context.load_font("HackGen-Bold.ttf", 50.0f)
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
		scope GpuColorTargetInfo color_target_info;
		scope uint vertex_offset;
		scope uint index_offset;
		vertex_offset = 0;
		index_offset = 0;
		scope int tw, th;

		scope UniformVertexView ub_view;
		scope UniformVertexModel ub_model;
		scope UniformVertexModel ub_model_shadow;

		// text
		string test_str = format("ABCDE 12345\n縁取り文字\n%s ms", timer.past);
		text_context.set(test_str)
			.get_text_size(tw, th)
			.get_draw_data!(TextureGeometry)(text_mesh, text_texture);

		// view_matrix
		ub_view.view_matrix =
			transformer_look_at(Vec3(0f, 0f, -3f), Vec3(0f, 0f, 0f), Vec3(0f, 1f, 0f))
			* transformer_perspective(PI_2,);
		// model_matrix 2nd
		ub_model.model_matrix =
			transformer_translate([-tw / 2.0f, th / 2.0f, 0.0f])
			* transformer_scale([0.02f, 0.02f, 0.02f])
			* Quaternion!float(Vec3(0.0f, 1.0f, 0.0f), cast(float) timer.past * inverse_usecs)
			.to_matrix.resize!(4, 4);

		ub_model_shadow.model_matrix =
			transformer_translate([-tw / 2.0f, th / 2.0f, 0.0f])
			* transformer_scale([0.02f, 0.02f, 0.02f])
			* Quaternion!float(Vec3(0.0f, 1.0f, 0.0f), cast(float) timer.past * inverse_usecs)
			.to_matrix.resize!(4, 4)
			* transformer_translate([0f, 0.0f, +0.1f]);

		assert(!ub_view.view_matrix.contain_nan);
		assert(!ub_model.model_matrix.contain_nan);
		// transfer
		buffer_transfer_buffer.map()
			.set(text_mesh.vertices!(TextureGeometry), text_mesh.offset_vertex,)
			.set(text_mesh.indices!(TextureGeometry), text_mesh.offset_index,)
			.unmap();

		// upload
		command_buffer.acquire_buffer()
			.copy((pass) {
				pass.upload(
					buffer_transfer_buffer,
					vertex_buffer,
					index_buffer,
				);
				return;
			})
			.submit();
		// render
		command_buffer.acquire_buffer()
			.acquire_texture(swapchain_texture);
		if (swapchain_texture.handle !is null)
		{
			color_target_info = GpuColorTargetInfo(
				swapchain_texture,
				GpuLoadOp.clear, GpuStoreOp.store,
			);
			color_target_info.clear_color = ColorF(0.1f, 0.1f, 0.1f, 1.0f);
			command_buffer.render(
				(ref GpuRenderPass pass) {
				pass
					.bind(pipeline, [vertex_buffer], index_buffer,)
					.push_vert(0, ub_view, ub_model,)
					.push_frag(
						0,
						UniformFragmentConfig(
						ColorF(1.0f, 1.0f, 1.0f, 1.0f),
						ColorF(0.0f, 0.0f, 0.0f, 1.0f),
						ColorF(0.5f, 0.5f, 1.0f, 1.0f),
						0.50f, 0.1f, 0.4f, 0.2f,
					),
				);
				pass.render_text(
					text_mesh.geometries!TextureGeometry(),
					text_texture,
					sampler,
				);
				/+
				foreach (count; 0 .. text_mesh.count!(TextureGeometry))
				{
					scope TextureGeometry temp_geometry = text_mesh.geometries!(
						TextureGeometry)[count];
					pass
						.bind([
							GpuTextureSamplerBinding(text_texture[count].handle, sampler.handle)
						])
						.draw_indexed(ParamIndexedPrimitive(
							cast(uint) temp_geometry.count_index,
							1u, index_offset, vertex_offset, 0u
						));
					vertex_offset += temp_geometry.count_vertex;
					index_offset += temp_geometry.count_index;
				}
				+/
				pass
					.bind(pipeline, [vertex_buffer], index_buffer,)
					.push_vert(1, ub_model_shadow)
					.push_frag(
						0,
						UniformFragmentConfig(
						ColorF(0.0f, 0.0f, 0.0f, 1.0f),
						ColorF(0.0f, 0.0f, 0.0f, 1.0f),
						ColorF(0.5f, 0.5f, 0.5f, 1.0f),
						0.50f, 0.1f, 0.4f, 0.0f,
					));
				pass.render_text(
					text_mesh.geometries!TextureGeometry(),
					text_texture,
					sampler,
				);
				return;
			},
				[color_target_info],
			);
		}
		command_buffer.submit();
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
	Matrix!(4, 4) normal_matrix;
}

struct UniformFragmentConfig
{
	ColorF color_line;
	ColorF color_outline;
	ColorF color_glow;
	float width_edge;
	float width_outline;
	float width_glow;
	float softness;
}
