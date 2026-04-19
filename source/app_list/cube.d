module app_list.cube;

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

	GpuCommandBuffer command_buffer;
	GpuSwapchainTexture swapchain_texture;
	GfxMesh object_mesh;
	GfxGeometry!(VertexPNU, uint) object_geometry;
	GpuGraphicsPipeline graphics_pipeline;
	GpuVertexBuffer vertex_buffer;
	GpuIndexBuffer index_buffer;
	GpuStorageBuffer storage_buffer;
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
		graphics_context.create(command_buffer, swapchain_texture);
		// Shader
		scope GpuVertexShader vertex_shader;
		scope GpuFragmentShader fragment_shader;
		graphics_context.create(graphics_pipeline, vertex_shader, fragment_shader);
		vertex_shader.create(
			ShaderFile("texture.vert", graphics_context.get_shader_format()),
			GpuShaderArguments(0, 3, 0, 0),
		);
		fragment_shader.create(
			ShaderFile("texture.frag", graphics_context.get_shader_format()),
			GpuShaderArguments(1, 4, 0, 0),
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
					graphics_context.get_swapchain_texture_format()
				)
			], GpuTextureFormat.d32_float,
			);
		}
		graphics_pipeline.create(pipeline_create_info);

		// Geometry
		FileHandler("cube.obj").load_obj(object_geometry);

		// Mesh
		object_mesh.initialize(
			VertexPNU.sizeof * object_geometry.count_vertex,
			uint.sizeof * object_geometry.count_index,
		);
		object_mesh.set([object_geometry]);
		// Buffer
		graphics_context.create(vertex_buffer, index_buffer,);
		vertex_buffer.create(object_geometry.count_vertex, VertexPNU.sizeof);
		index_buffer.create(object_geometry.count_index, GpuIndexElementSize._32bit);
		//storage_buffer.create(LightPoint.sizeof * 1u);

		// depth texture
		graphics_context.create(depth_texture);
		depth_texture.create(GpuTextureCreateInfo(
				GpuTextureType._2d,
				GpuTextureFormat.d32_float,
				GpuTextureUsageFlags.depth_stencil_target,
				graphics_context.client_width, graphics_context.client_height,
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
				GpuFilter.linear,
				GpuFilter.linear,
		));

		// upload
		scope GpuBufferTransferBuffer buffer_transfer_buffer;
		scope GpuTextureTransferBuffer texture_transfer_buffer;

		graphics_context.create(buffer_transfer_buffer, texture_transfer_buffer);
		buffer_transfer_buffer.create(object_geometry.size)
			.map()
			.set(object_geometry.vertices, object_geometry.offset_vertex)
			.set(object_geometry.indices, object_geometry.offset_index)
			.unmap();
		texture_transfer_buffer.create(object_image.size)
			.map()
			.set(object_image)
			.unmap();
		command_buffer.acquire_buffer()
			.with_copy_pass(
				(copy_pass) {
				copy_pass.upload(
					buffer_transfer_buffer,
					vertex_buffer,
					index_buffer,
				)
					.upload(
						GpuTextureTransferInfo(
						texture_transfer_buffer, object_image.width, object_image.height
					),
					GpuTextureRegion(object_texture)
				);
				return;
			}
			).submit();
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
				(render_pass) {
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

				render_pass.bind(graphics_pipeline)
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
