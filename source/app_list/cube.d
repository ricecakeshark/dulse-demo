module app_list.cube;

import app_list.app_interface;

import kelp_core;
import kelp_sdl;
import kelp_gfx;

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
	GpuGraphicsPipeline texture_pipeline, solid_pipeline;
	GpuVertexBuffer vertex_buffer;
	GpuIndexBuffer index_buffer;
	GpuStorageBuffer storage_buffer;
	GpuTexture depth_texture;

	Surface object_image;
	GpuTexture object_texture;
	GpuSampler object_sampler;
	ObjectManager object_manager;
	Entity[4] entity_list;

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
		// Entity
		object_manager = new ObjectManager;
		object_manager.create(entity_list)
			.append_component!TransformComponent();
		foreach (entity; entity_list)
		{
			object_manager.attach!TransformComponent(entity);
		}
		object_manager.register!TransformSystem()
			.append_resource(TimerResource(0))
			.initialize();

		// Shader
		scope GpuVertexShader texture_vert_shader;
		scope GpuFragmentShader texture_frag_shader;
		scope GpuVertexShader solid_vert_shader;
		scope GpuFragmentShader solid_frag_shader;
		graphics_context.create(texture_pipeline, texture_vert_shader, texture_frag_shader);
		texture_vert_shader.create(
			ShaderFile("texture.vert", graphics_context.get_shader_format()),
			GpuShaderArguments(0, 3, 0, 0),
		);
		texture_frag_shader.create(
			ShaderFile("texture.frag", graphics_context.get_shader_format()),
			GpuShaderArguments(1, 4, 0, 0),
		);
		graphics_context.create(solid_pipeline, solid_vert_shader, solid_frag_shader);
		solid_vert_shader.create(
			ShaderFile("vertex_color.vert", graphics_context.get_shader_format()),
			GpuShaderArguments(0, 3, 0, 0),
		);
		solid_frag_shader.create(
			ShaderFile("vertex_color.frag", graphics_context.get_shader_format()),
			GpuShaderArguments(1, 4, 0, 0),
		);
		// Pipeline
		// texture_pipeline
		scope GpuGraphicsPipelineCreateInfo pipeline_create_info;
		pipeline_create_info.vertex_shader = texture_vert_shader.handle;
		pipeline_create_info.fragment_shader = texture_frag_shader.handle;
		with (pipeline_create_info)
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
			target_info = GpuGraphicsPipelineTargetInfo(
				[
				GpuColorTargetDescription(
					graphics_context.get_swapchain_texture_format()
				)
			], GpuTextureFormat.d32_float_s8_uint,
			);
		}
		texture_pipeline.create(pipeline_create_info);
		// solid pipeline
		pipeline_create_info.vertex_shader = solid_vert_shader.handle;
		pipeline_create_info.fragment_shader = solid_frag_shader.handle;
		with (pipeline_create_info)
		{
			depth_stencil_state = GpuDepthStencilState(
				GpuCompareOp.greater,
				GpuStencilOpState.init,
				GpuStencilOpState.init,
				0u, 0u,
				true, false, false,
			);
		}
		solid_pipeline.create(pipeline_create_info);

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

		// depth texture
		graphics_context.create(depth_texture);
		depth_texture.create(GpuTextureCreateInfo(
				GpuTextureType._2d,
				GpuTextureFormat.d32_float_s8_uint,
				GpuTextureUsageFlags.depth_stencil_target,
				graphics_context.client_width, graphics_context.client_height,
				1, 1, GpuSampleCount.x1,
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
		with (object_manager.resource_store.refer!TimerResource())
		{
			past_time = timer.past;
			delta_time = timer.delta;
		}

		object_manager.process();
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
		// View
		vertex_view.mat_view = multiply_ltor(
			transformer_look_at(Vec3(0f, 0f, -2.5f), Vec3(0f, 0f, 0f), Vec3(0f, 1f, 0f)),
			transformer_perspective(PI_2),
		);
		// Light
		fragment_scene.ambient_light = ColorF(1.0f, 1.0f, 1.0f, 0.1f);
		fragment_view.vec_view = Vec3(0f, 0f, -2.5f);
		with (fragment_light.list[0])
		{
			pos = Vec3(0f, +0.5f, -3f);
			color = Vec3(0.7f, 0.7f, 0.7f);
			intensity = 1.0;
		}

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
				GpuStoreOp.store,
			);
			command_buffer.with_render_pass(
				[color_target_info],
				depth_target_info,
				(render_pass) {
				// scene, view
				render_pass.push_vertex(vertex_view, 1)
					.push_fragment(fragment_scene, 0)
					.push_fragment(fragment_view, 1u);
				// texture render
				foreach (entity; entity_list)
				{
					vertex_model.mat_model = object_manager.component.get!TransformComponent(entity)
						.model_matrix();
					vertex_model.mat_model_normal = vertex_model.mat_model.to_normal();

					render_pass.bind(texture_pipeline)
						.bind([
							GpuTextureSamplerBinding(object_texture, object_sampler)
						], 0)
						.bind([vertex_buffer])
						.bind(index_buffer)
						.push_vertex(vertex_model, 2)
						.push_fragment(fragment_model, 2u)
						.push_fragment(fragment_light, 3u)
						.draw_indexed(ParamIndexedPrimitive(cast(uint) object_geometry.count_index, 1, 0, 0, 0));
				}
				// solid render
				foreach (entity; entity_list)
				{
					vertex_model.mat_model = object_manager.component.get!TransformComponent(entity)
						.model_matrix(1.01f);
					vertex_model.mat_model_normal = vertex_model.mat_model.to_normal();
					render_pass.bind(solid_pipeline)
						.bind([vertex_buffer])
						.bind(index_buffer)
						.push_vertex(vertex_model, 2)
						.push_fragment(fragment_model, 2u)
						.push_fragment(fragment_light, 3u)
						.draw_indexed(ParamIndexedPrimitive(cast(uint) object_geometry.count_index, 1, 0, 0, 0));
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
	float specular_strength = 0.5f;
	float shininess = 32.0f;
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

struct TransformComponent
{
	Vec3 pos;
	Vec3 rotate;
	Vec3 scale;

	Matrix!(4, 4, float) model_matrix(float scale = 1.0f)
	{
		return multiply_rtol(
			transformer_translate(this.pos),
			transformer_rotate_y(this.rotate.y),
			transformer_rotate_x(this.rotate.x),
			transformer_scale(this.scale * scale),
		);
	}
}

class TransformSystem : IObjectSystem
{
	void initialize(ObjectManager manager)
	{
		foreach (entity; manager.entity.list)
		{
			with (manager.component.get!TransformComponent(entity))
			{
				pos = Vec3(0f);
				rotate = Vec3(0f);
				scale = Vec3(0.6f);
			}
		}
		return;
	}

	void finalize(ObjectManager manager)
	{
		return;
	}

	void process(ObjectManager manager)
	{
		import std.math;

		foreach (index, entity; manager.entity.list)
		{
			float rad;
			TimerResource timer;
			timer = manager.resource.refer!TimerResource();
			with (manager.component.get!TransformComponent(entity))
			{
				rotate.x += cast(float) 0.5 * 0.001 * timer.delta_time;
				rotate.y += cast(float) 1.5 * 0.001 * timer.delta_time;
				rad = (0.001f * timer.past_time) + (
					2.0f / manager.entity.count * PI) * index;
				pos = Vec3(cos(rad) * 1.2f, 0f, sin(rad) * 1.2f);
			}

		}
		return;
	}
}

struct TimerResource
{
	long past_time;
	long delta_time;
}
