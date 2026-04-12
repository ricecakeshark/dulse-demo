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
	GfxGeometry!(VertexPNU, uint) object_geometry;

	GpuVertexBuffer vertex_buffer;
	GpuIndexBuffer index_buffer;

	GpuTexture object_texture;
	GpuSampler object_sampler;
	GpuTexture depth_texture;
	GpuTexture compute_src_texture, compute_dst_texture;
	GpuSampler sampler;
	Surface object_image;

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
		graphics_context.create(render_pipeline, vertex_shader, fragment_shader);
		vertex_shader.create(
			ShaderFile("texture_2.vert", graphics_context.get_shader_format()),
			GpuShaderArguments(0, 3, 0, 0),
		);
		fragment_shader.create(
			ShaderFile("texture_2.frag", graphics_context.get_shader_format()),
			GpuShaderArguments(1, 4, 0, 0),
		);
		// Render Pipeline
		scope GpuGraphicsPipelineCreateInfo render_pipeline_info;
		render_pipeline_info.vertex_shader = vertex_shader.handle;
		render_pipeline_info.fragment_shader = fragment_shader.handle;
		with (render_pipeline_info)
		{
			vertex_input_state = GpuVertexInputState(
				[
					vertex_buffer_description!(float[3], float[3], float[2])
				],
				vertex_attributes!(float[3], float[3], float[2])(0),
			);
			primitive_type = SDL_GPU_PRIMITIVETYPE_TRIANGLELIST;
			rasterizer_state = GpuRasterizerState(
				GpuFillMode.fill,
				GpuCullMode.back,
				GpuFrontFace.counter_clockwise,
			);
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
					GpuTextureFormat.r32g32b32a32_float,
				)
			], GpuTextureFormat.d32_float,
			);
		}
		render_pipeline.create(render_pipeline_info);

		// Compute Pipeline
		graphics_context.create(compute_pipeline);
		auto compute_pipeline_info = GpuComputePipelineCreateInfo(
			ShaderFile("mosaic.comp", GpuShaderFormat.spirv)
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
		));
		graphics_context.create(depth_texture);
		depth_texture.create(GpuTextureCreateInfo(
				GpuTextureType._2d,
				GpuTextureFormat.d32_float,
				GpuTextureUsageFlags.depth_stencil_target,
				graphics_context.client_width, graphics_context.client_height,
				1, 1, GpuSampleCount.x1,
		));

		graphics_context.create(compute_src_texture, compute_dst_texture, sampler);
		compute_src_texture.create(GpuTextureCreateInfo(
				GpuTextureType._2d, GpuTextureFormat.r32g32b32a32_float,
				GpuTextureUsageFlags.sampler | GpuTextureUsageFlags.color_target | GpuTextureUsageFlags.compute_storage_read,
				graphics_context.client_width, graphics_context.client_height, 1, 1,
		));
		compute_dst_texture.create(GpuTextureCreateInfo(
				GpuTextureType._2d, GpuTextureFormat.r32g32b32a32_float,
				GpuTextureUsageFlags.sampler | GpuTextureUsageFlags.compute_storage_write,
				graphics_context.client_width, graphics_context.client_height, 1, 1,
		));
		sampler.create(GpuSamplerCreateInfo(
				GpuFilter.linear, GpuFilter.linear,
		));

		// Geometry
		FileHandler("cube.obj").load_obj(object_geometry);

		// Mesh
		object_mesh.initialize(
			VertexPNU.sizeof * object_geometry.count_vertex,
			uint.sizeof * object_geometry.count_index,
		);
		object_mesh.set([object_geometry]);

		// Buffer
		graphics_context.create(vertex_buffer, index_buffer);
		vertex_buffer.create(object_geometry.count_vertex, object_geometry.stride_vertex);
		index_buffer.create(object_geometry.count_index, GpuIndexElementSize._32bit);

		// upload
		scope GfxUploadContext upload_context;
		scope GpuBufferTransferBuffer buffer_transfer_buffer;
		scope GpuTextureTransferBuffer tb_texture;
		graphics_context.create(upload_context, buffer_transfer_buffer, tb_texture);
		buffer_transfer_buffer.create(object_geometry.size)
			.map()
			.set(object_geometry.vertices, object_geometry.offset_vertex)
			.set(object_geometry.indices, object_geometry.offset_index)
			.unmap();
		tb_texture.create(object_image.size)
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
				GpuTextureTransferInfo(tb_texture, 0),
				GpuTextureRegion(object_texture)
			)
			.end()
			.submit();

		graphics_context.create(compute_context);
		core.subsystem.query(timer, logger);

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

	LoggerSubsystem logger;
	GpuCommandBuffer command_buffer;
	GpuSwapchainTexture swapchain_texture;

	override void draw()
	{

		import std.math;

		GpuColorTargetInfo color_target_info;
		GpuDepthStencilTargetInfo depth_target_info;
		UniformVertexScene vertex_scene;
		UniformVertexView vertex_view;
		UniformVertexModel vertex_model;
		UniformFragmentScene fragment_scene;
		UniformFragmentView fragment_view;
		UniformFragmentModel fragment_model;
		UniformFragmentLight fragment_light;

		vertex_view.mat_view = multiply_ltor(
			transformer_look_at(Vec3(0f, 0f, -2.5f), Vec3(0f, 0f, 0f), Vec3(0f, 1f, 0f)),
			transformer_perspective(PI_2),
		);
		fragment_scene.ambient_light = ColorF(1.0f, 1.0f, 1.0f, 0.1f);
		fragment_view.vec_view = Vec3(0f, 0f, -2.5f);
		with (fragment_light.list[0])
		{
			pos = Vec3(0f, +0.5f, -3f);
			color = Vec3(0.7f, 0.7f, 0.7f);
			intensity = 1.0;
		}

		//fragment_light.pos = [sin(0.002f*timer.past)*10f,0f,cos(0.002f*timer.past)*10f];

		command_buffer.acquire_buffer()
			.acquire_texture(swapchain_texture);
		if (swapchain_texture.handle !is null)
		{
			color_target_info = GpuColorTargetInfo(
				compute_src_texture,
				GpuLoadOp.clear, GpuStoreOp.store,
			);
			depth_target_info = GpuDepthStencilTargetInfo(
				depth_texture.handle,
				1.0f,
				GpuLoadOp.clear,
				GpuStoreOp.dont_care,
			);
			// render
			command_buffer.with_render_pass(
				[color_target_info],
				depth_target_info,
				(ref GpuRenderPass pass) {
				vertex_model.mat_model = multiply_rtol(
					transformer_rotate_y(0.0015 * timer.past),
					transformer_rotate_x(0.0005 * timer.past),
					transformer_scale([1.0f, 1.0f, 1.0f]),
				);
				vertex_model.mat_model_normal = cast(Matrix!(4, 4, float))(cast(Matrix!(3, 3, float))(
					vertex_model.mat_model)).inverse()
					.transpose();
				with (fragment_model)
				{
					specular_strength = 1.0;
					shininess = 32.0f;
				}
				pass.bind(render_pipeline)
					.bind([
						GpuTextureSamplerBinding(object_texture, object_sampler)
					], 0)
					.bind([vertex_buffer])
					.bind(index_buffer)
					.push_vertex(vertex_view, 1)
					.push_vertex(vertex_model, 2)
					.push_fragment(fragment_scene, 0)
					.push_fragment(fragment_view, 1u)
					.push_fragment(fragment_model, 2u)
					.push_fragment(fragment_light, 3u)
					.draw_indexed(ParamIndexedPrimitive(cast(uint) object_geometry.count_index, 1, 0, 0, 0));
			},);
			// compute
			command_buffer.with_compute_pass(
				[GpuStorageTextureReadWriteBinding(compute_dst_texture)],
				[],
				(ref GpuComputePass pass) {
				pass.bind(compute_pipeline)
					.bind(
						[GpuTextureSamplerBinding(compute_src_texture, sampler)], 0
					)
					.push_uniform(ComputeUniform(960f, 540f))
					.dispatch(960 / 8, 540 / 8, 1);
				return;
			}
			);
			// blit
			command_buffer.blit_texture(
				GpuBlitInfo(
					GpuBlitRegion(compute_dst_texture),
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

struct UniformVertexScene
{
	ColorF ambient_light;
}

struct UniformVertexView
{
	Matrix!(4, 4) mat_view;
}

struct UniformVertexModel
{
	Matrix!(4, 4) mat_model;
	Matrix!(4, 4) mat_model_normal;
}

struct UniformFragmentScene
{
	ColorF ambient_light;
}

struct UniformFragmentView
{
	Vec3 vec_view;
}

struct UniformFragmentModel
{
	//align(4):
	float specular_strength = 0.0;
	float shininess = 64.0;
}

struct UniformFragmentLight
{
	LightPoint[1] list;
	uint count;
}

struct LightPoint
{
	align(16) Vec3 pos = [0.0f, 0.0f, -3.0f];
	align(16) Vec3 color = [1.0f, 1.0f, 1.0f];
	float intensity = 1.0f;
}

struct ComputeUniform
{
	float width;
	float height;
	float delta = 0.0f;
	float level = 8.0f;
}
