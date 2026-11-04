module app_list.compute.compute;

import app_list.app_interface;
import app_list.compute.uniform.compute;

import dulse;
import dulse_sdl;
import dulse_gfx;
import dulse_preset;

class ComputeDemo : AppInterface
{
	Core core;
	TimerSubsystem timer;
	GraphicsContext gc;
	CommandBuffer command_buffer;

	SwapchainTexture swapchain_texture;
	GfxGraphicsPipeline render_pipeline;
	GfxComputePipeline compute_pipeline;
	GfxMesh object_mesh;
	GfxGeometry!(VertexPNU, uint) object_geometry;

	VertexBuffer vertex_buffer;
	IndexBuffer index_buffer;

	Texture object_texture;
	GpuSampler object_sampler;
	Texture depth_texture;
	TextureAlternate alt_texture;
	GpuSampler sampler;
	Surface object_image;

	this(Core core)
	{
		this.core = core;
		this.gc = core.subsystem.query!GraphicsSubsystem()[0].context;
		return;
	}

	override void initialize()
	{
		core.subsystem.query(timer, logger);
		gc.create(command_buffer, swapchain_texture);
		// Render Shader
		scope GpuVertexShader vertex_shader;
		scope GpuFragmentShader fragment_shader;
		gc.create(render_pipeline, vertex_shader, fragment_shader);
		vertex_shader.create(
			ShaderFile("texture.vert", gc.get_shader_format()),
			GpuShaderArguments(0, 3, 0, 0),
		);
		fragment_shader.create(
			ShaderFile("texture.frag", gc.get_shader_format()),
			GpuShaderArguments(1, 4, 0, 0),
		);
		// Render Pipeline
		scope GraphicsPipelineCreateInfo render_pipeline_info;
		render_pipeline_info.vertex_shader = vertex_shader;
		render_pipeline_info.fragment_shader = fragment_shader;
		with (render_pipeline_info)
		{
			vertex_input_state = GpuVertexInputState(
				[
					vertex_buffer_description!(float[3], float[3], float[2])
				],
				vertex_attributes!(float[3], float[3], float[2])(0),
			);
			primitive_type = GpuPrimitiveType.triangle_list;
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
			target_info = GraphicsPipelineTargetInfo(
				[
				GpuColorTargetDescription(
					GpuTextureFormat.r16g16b16a16_float,
				)
			], GpuTextureFormat.d32_float,
			);
		}
		render_pipeline
			.bind(render_pipeline_info)
			.create();

		// Compute Pipeline
		gc.create(compute_pipeline);
		auto compute_pipeline_info = GfxComputePipelineCreateInfo(
			ShaderFile("mosaic.comp", GpuShaderFormat.spirv)
		);
		with (compute_pipeline_info)
		{
			num_readonly_storage_buffers = 0;
			num_samplers = 1;
			num_readwrite_storage_textures = 1;
			num_uniform_buffers = 1;
			threadcount_x = 8;
			threadcount_y = 8;
			threadcount_z = 1;
		}
		compute_pipeline
			.bind(compute_pipeline_info)
			.create();

		// texture, sampler
		object_image = new Surface();
		object_image.load("./image/test_texture.png");
		gc.create(object_texture, object_sampler);
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
		gc.create(depth_texture, alt_texture);

		depth_texture.create(GpuTextureCreateInfo(
				GpuTextureType._2d,
				GpuTextureFormat.d32_float,
				GpuTextureUsageFlags.depth_stencil_target,
				gc.client_width, gc.client_height,
				1, 1, GpuSampleCount.x1,
		));
		alt_texture.create(GpuTextureCreateInfo(
				GpuTextureType._2d, GpuTextureFormat.r16g16b16a16_float,
				GpuTextureUsageFlags.sampler | GpuTextureUsageFlags.compute_storage_write | GpuTextureUsageFlags
				.color_target,
				gc.client_width, gc.client_height, 1, 1,
		));

		gc.create(sampler);
		sampler.create(GpuSamplerCreateInfo(
				GpuFilter.linear, GpuFilter.linear,
		));

		sampler.set_to(
			depth_texture, alt_texture.src, alt_texture.dest,
			object_texture,
		);

		// Geometry
		FileHandler("./model/cube.obj").load_obj(object_geometry);

		// Mesh
		object_mesh.initialize(
			VertexPNU.sizeof * object_geometry.count_vertex,
			uint.sizeof * object_geometry.count_index,
		);
		object_mesh.set([object_geometry]);

		// Buffer
		gc.create(vertex_buffer, index_buffer);
		vertex_buffer.create(object_geometry.count_vertex, object_geometry.stride_vertex);
		index_buffer.create(object_geometry.count_index, GpuIndexElementSize._32bit);

		// upload
		scope GpuBufferTransferBuffer buffer_transfer_buffer;
		scope GpuTextureTransferBuffer tb_texture;
		gc.create(buffer_transfer_buffer, tb_texture);
		buffer_transfer_buffer.prepare(object_geometry);
		tb_texture.prepare(object_image);

		command_buffer
			.acquire_buffer()
			.copy(
				sequence(
					buffer_transfer_buffer,
					vertex_buffer, index_buffer,
			),
			sequence(
				tb_texture,
				object_texture,
			),
		)
			.submit();
		return;
	}

	override void finalize()
	{
		gc.resource_store.release_all();
		return;
	}

	override void process()
	{

		return;
	}

	LoggerSubsystem logger;

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

		vertex_view.mat_view =
			transformer_look_at(Vec3(0f, 0f, -2.5f), Vec3(0f, 0f, 0f), Vec3(0f, 1f, 0f))
			* transformer_perspective(PI_2);

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
				alt_texture.src,
				GpuLoadOp.clear, GpuStoreOp.store,
			);
			depth_target_info = GpuDepthStencilTargetInfo(
				depth_texture.handle,
				1.0f,
				GpuLoadOp.clear,
				GpuStoreOp.dont_care,
			);

			// render
			command_buffer.render(
				(render_pass) {
				vertex_model.mat_model =
					matrix_scaling!true(Vec3(1.0, 1.0, 1.0))
					* Quaternion!float(Vec3(1.0f, 1.0f, 0.0f), 1.0 * timer.past * 0.001 * 0.001).to_matrix.resize!(4, 4);

				vertex_model.mat_model_normal = cast(Matrix!(4, 4, float))(
					cast(Matrix!(3, 3, float))(
					vertex_model.mat_model)
				).invert()
					.transpose();
				with (fragment_model)
				{
					specular_strength = 1.0;
					shininess = 32.0f;
				}
				render_pass
					.bind(
						render_pipeline,
						object_texture.binding,
						vertex_buffer, index_buffer,
					)
					.push_vertex(1, vertex_view, vertex_model)
					.push_fragment(0, fragment_scene, fragment_view, fragment_model, fragment_light,)
					.draw_indexed(ParamIndexedPrimitive(cast(uint) object_geometry.count_index, 1, 0, 0, 0));
			},
				color_target_info,
				depth_target_info,
			);

			// compute
			command_buffer.compute(
				(compute_pass) {
				compute_pass
					.bind(
						compute_pipeline,
						alt_texture.src.binding,
					)
					.push(UniformCompute(960f, 540f))
					.dispatch(
						compute_pipeline.dispatch_size(gc.client_size),);
				return;
			},
				alt_texture.dest,
			); // blit
			command_buffer.blit_texture(
				GpuBlitInfo(
					GpuBlitRegion(alt_texture.dest),
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
