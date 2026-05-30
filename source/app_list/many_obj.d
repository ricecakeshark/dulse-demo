module app_list.many_obj;

import app_list.app_interface;
import app_list.uniform;
import kelp_core;
import kelp_sdl;
import kelp_gfx;
import std.math;

class ManyObject : AppInterface
{
	Core core;
	TimerSubsystem timer;
	LoggerSubsystem logger;
	GfxGraphicsContext graphics_context;

	GpuCommandBuffer command_buffer;
	GpuSwapchainTexture swapchain_texture;
	GpuTexture depth_texture;

	GfxGeometry!(VertexPNU, uint) object_geometry;
	GfxMesh object_mesh;
	GpuGraphicsPipeline texture_pipeline,solid_pipeline;
	GpuVertexBuffer vertex_buffer;
	GpuIndexBuffer index_buffer;
	//GpuStorageBuffer storage_buffer;
	GpuTexture object_texture;
	GpuSampler object_sampler;
	Surface object_image;

	ObjectManager object_manager;
	Entity[20] entity_list;

	this(Core core)
	{
		this.core = core;
		this.graphics_context = core.subsystem.query!GfxGraphicsSubsystem().context;
		return;
	}

	override void initialize()
	{
		import std.stdio;

		core.subsystem.query(timer, logger);
		graphics_context.create(command_buffer, swapchain_texture);
		// object manager
		object_manager = new ObjectManager;
		object_manager.create(entity_list);
		object_manager.component.append!TransformComponent();
		object_manager.register!PositionSystem();
		object_manager.initialize();

		// Shader
		scope GpuVertexShader texture_vert_shader;
		scope GpuFragmentShader texture_frag_shader;
		graphics_context.create(texture_pipeline, texture_vert_shader, texture_frag_shader);
		texture_vert_shader.create(
			ShaderFile("texture.vert", graphics_context.get_shader_format()),
			GpuShaderArguments(0, 3, 0, 0),
		);
		texture_frag_shader.create(
			ShaderFile("texture.frag", graphics_context.get_shader_format()),
			GpuShaderArguments(1, 4, 0, 0),
		);
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
					//graphics_context.get_swapchain_texture_format()
					swapchain_texture.get_format(),
				)
			], GpuTextureFormat.d32_float_s8_uint,
			);
		}
		texture_pipeline.create(pipeline_create_info);
		// solid
		scope GpuVertexShader solid_vert_shader;
		scope GpuFragmentShader solid_frag_shader;
		graphics_context.create(solid_pipeline, solid_vert_shader, solid_frag_shader);
		solid_vert_shader.create(
			ShaderFile("vertex_color.vert", graphics_context.get_shader_format()),
			GpuShaderArguments(0, 3, 0, 0),
		);
		solid_frag_shader.create(
			ShaderFile("vertex_color.frag", graphics_context.get_shader_format()),
			GpuShaderArguments(1, 4, 0, 0),
		);
		// solid pipeline
		pipeline_create_info.vertex_shader = solid_vert_shader.handle;
		pipeline_create_info.fragment_shader = solid_frag_shader.handle;
		with (pipeline_create_info)
		{
			depth_stencil_state = GpuDepthStencilState(
				GpuCompareOp.less,
				GpuStencilOpState.init,
				GpuStencilOpState.init,
				0u, 0u,
				true, true, false,
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

		// Mesh, Geometry
		/+
		object_geometry.vertices = [
			VertexPNU(Vec3(-0.5f, -0.5f, 0.0f), Vec3(-0.5f, -0.5f, 0f), Vec2(0.0f, 0.0f,),),
			VertexPNU(Vec3(+0.5f, -0.5f, 0.0f,), Vec3(+0.5f, -0.5f, 0f), Vec2(1.0f, 0.0f,),),
			VertexPNU(Vec3(0.5f, +0.5f, 0.0f,), Vec3(+0.5f, +0.5f, 0f), Vec2(1.0f, 1.0f,),),
			VertexPNU(Vec3(-0.5f, +0.5f, 0.0f,), Vec3(-0.5f, +0.5f, 0f), Vec2(0.0f, 1.0f,),),
		];
		object_geometry.indices = [0, 1, 2, 0, 2, 3];
		object_mesh.initialize(VertexPNU.sizeof * 4, uint.sizeof * 6);
		object_mesh.set([object_geometry,]);
		+/

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

		// upload
		scope GpuBufferTransferBuffer tb_geometry, tb_storage;
		scope GpuTextureTransferBuffer tb_texture;
		graphics_context.create(tb_geometry, tb_storage, tb_texture);
		tb_geometry.create(object_geometry.size)
			.map()
			.set(object_geometry.vertices, object_geometry.offset_vertex)
			.set(object_geometry.indices, object_geometry.offset_index)
			.unmap();
		tb_texture.create(object_image.size)
			.map()
			.set(object_image)
			.unmap();
		command_buffer.acquire_buffer()
			.with_copy_pass((copy_pass) {
				copy_pass.upload(
					GpuTransferBufferLocation(tb_geometry, object_geometry.offset_vertex),
					GpuBufferRegion(vertex_buffer, 0u)
				)
					.upload(
						GpuTransferBufferLocation(tb_geometry, object_geometry.offset_index),
						GpuBufferRegion(index_buffer, 0u)
					)
					.upload(
						GpuTextureTransferInfo(tb_texture, 0),
						GpuTextureRegion(object_texture)
					);
				return;
			}).submit();

		// depth texture
		graphics_context.create(depth_texture);
		depth_texture.create(GpuTextureCreateInfo(
				GpuTextureType._2d,
				GpuTextureFormat.d32_float_s8_uint,
				GpuTextureUsageFlags.depth_stencil_target,
				graphics_context.client_width, graphics_context.client_height,
				1, 1, GpuSampleCount.x1,
		));

		graphics_context.release_transfer_buffer();

		return;
	}

	override void finalize()
	{
		graphics_context.resource_store.release_all();
		return;
	}

	override void process()
	{
		object_manager.process();
		return;
	}

	override void draw()
	{
		import std.math;

		GpuColorTargetInfo color_target_info;
		GpuDepthStencilTargetInfo depth_target_info;
		Matrix!(4, 4) view_mat, pos_mat;
		//UniformVertexScene vert_scene;
		UniformVertexView vert_view;
		UniformVertexModel vert_model;
		UniformFragmentScene frag_scene;
		UniformFragmentView frag_view;
		UniformFragmentModel frag_model;
		UniformFragmentLight frag_light;

		// View
		vert_view.mat_view = multiply_ltor(
			transformer_look_at(Vec3(0f, 0f, -2.5f), Vec3(0f, 0f, 0f), Vec3(0f, 1f, 0f)),
			transformer_perspective(PI_2),
		);
		// Light
		frag_scene.ambient_light = ColorF(1.0f, 1.0f, 1.0f, 0.1f);
		frag_view.vec_view = Vec3(0f, 0f, -2.5f);
		with (frag_light.list[0])
		{
			pos = Vec3(0f, +0.5f, -3f);
			color = Vec3(0.7f, 0.7f, 0.7f);
			intensity = 1.0;
		}
		command_buffer.acquire_buffer()
			.acquire_texture(swapchain_texture);
		if (swapchain_texture !is null)
		{
			// color
			color_target_info = GpuColorTargetInfo(
				swapchain_texture,
				GpuLoadOp.clear, GpuStoreOp.store,
			);
			// depth
			depth_target_info = GpuDepthStencilTargetInfo(
				depth_texture.handle,
				1.0f,
				GpuLoadOp.clear,
				GpuStoreOp.store,
			);
			command_buffer.with_render_pass(
				[color_target_info],
				depth_target_info,
				(ref GpuRenderPass pass) {
				pass.bind(solid_pipeline)
					.bind([
						GpuTextureSamplerBinding(object_texture, object_sampler)
					], 0)
					.bind([vertex_buffer])
					.bind(index_buffer)
					.push_vertex(vert_view, 1)
					.push_fragment(frag_view, 1,)
					.push_fragment(frag_scene, 0,);
				foreach (entity; entity_list)
				{
					vert_model.mat_model =
						object_manager.component.get!TransformComponent(entity)
						.model_matrix;

					vert_model.mat_model_normal = cast(Matrix!(4, 4, float))(cast(Matrix!(3, 3, float))(
						vert_model.mat_model)).inverse().transpose();

					pass.push_vertex(vert_model, 2)
						.push_fragment(frag_model, 2,)
						.push_fragment(frag_light, 3,)
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

import std.random;

struct Comp
{
	float[4] param;
}

struct TransformComponent
{
	Vec3 pos;
	Quaternion!float rotate_quat = Quaternion!float(Vec3(1.0f, 0.0f, 0.0f), 0f);
	Vec3 scale;
	Body _body;

	Matrix!(4, 4, float) model_matrix(float scale = 1.0f)
	{
		import std.math;

		return matrix_scale!3(0.25f)
			.multiply(rotate_quat.to_matrix)
			.extend!(Matrix!(4, 4))
			.multiply(transformer_translate(pos));
	}
}

class PositionSystem : IObjectSystem
{
	void initialize(ObjectManager object_manager)
	{
		foreach (entity; object_manager.entity.list)
		{
			object_manager.attach!TransformComponent(entity);
			with (object_manager.component.get!TransformComponent(entity))
			{
				pos = Vec3(
					uniform(-1.0f, +1.0f),
					uniform(-1.0f, +1.0f),
					uniform(-1.0f, +1.0f),
				);
				rotate_quat = Quaternion!float(Vec3(1.0f, 0.0f, 0.0f), 0f);
				_body = Body(Shape(Sphere(0.3f)), pos, 1.0f);
				_body.pos = pos;
				_body.vel = Quaternion!float(Vec3(1.0f, 0.0f, 0.0f), uniform(0f, PI * 2))
					.multiply(Quaternion!float(Vec3(0.0f, 1.0f, 0.0f), uniform(0f, PI * 2)))
					.to_vec * 0.03;
			}
			import std.exception;

			enforce(!object_manager.component.get!TransformComponent(entity)
					._body.position.contain_nan);
		}
		return;
	}

	void finalize(ObjectManager object_manager)
	{
		return;
	}

	void process(ObjectManager object_manager)
	{
		import std.stdio;

		/+writeln(object_manager.component.get!TransformComponent(object_manager.entity.list[0])
				._body);+/
		foreach (entity; object_manager.entity.list)
		{
			with (object_manager.component.get!TransformComponent(entity))
			{
				_body.pos += _body.vel;
			}
		}
		foreach (entity_1; object_manager.entity.list)
		{
			ref Body body_1 = object_manager.component.get!TransformComponent(entity_1)._body;

			foreach (entity_2; object_manager.entity.list)
			{

				if (entity_1.index >= entity_2.index)
				{
					continue;
				}
				ref Body body_2 = object_manager.component.get!TransformComponent(entity_2)._body;
				//writeln("e1:", entity_1.index, body_1);
				//writeln("e2: ", entity_2.index, body_2);
				CollideManifold manifold = detect_collision(body_1, body_2);
				if (manifold.hit)
				{
					resolve_collision(body_1, body_2, manifold);
					correct_position(body_1, body_2, manifold);
				}
			}
		}

		foreach (entity; object_manager.entity.list)
		{
			with (object_manager.component.get!TransformComponent(entity))
			{
				//if (distance(_body.pos, Vec3(0f, 0f, 0f)) > 5f)

				resolve_collision(_body);

			}
		}

		foreach (entity; object_manager.entity.list)
		{
			with (object_manager.component.get!TransformComponent(entity))
			{
				pos = _body.pos;
			}
		}

		return;
	}
}
