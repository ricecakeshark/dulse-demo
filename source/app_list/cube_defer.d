module app_list.cube_defer;

import app_list.app_interface;
import app_list.uniform;
import app_list.ecs;
import app_list.pipeline;

import kelp_core;
import kelp_sdl;
import kelp_gfx;

class CubeDeferDemo : AppInterface
{
	Core core;
	TimerSubsystem timer;
	LoggerSubsystem logger;
	GfxGraphicsContext graphics_context;

	GpuGraphicsPipeline pipeline_defer_texture, pipeline_defer_solid;
	GpuComputePipeline pipeline_compose, pipeline_compose_debug;
	GpuComputePipeline pipeline_phong, pipeline_pre_edge, pipeline_post_edge, pipeline_post_blur_fog, pipeline_post_color;

	GpuTexture depth_texture;
	GpuTexture albedo_texture, normal_texture, color_texture, material_texture, entity_texture, edge_texture;
	GpuTexture temp_alpha_texture, temp_beta_texture;
	GpuSampler sampler_nearest, sampler_smooth;
	GpuFence fence;

	GfxMesh object_mesh;
	GfxGeometry!(VertexPNU, uint) object_geometry;
	GpuVertexBuffer vertex_buffer;
	GpuIndexBuffer index_buffer;

	GpuTexture object_texture;
	Surface object_image;

	Entity[4] entity_list;
	ObjectManager object_manager;

	this(Core core)
	{
		this.core = core;
		this.graphics_context = core.subsystem.query!GfxGraphicsSubsystem().context;
		return;
	}

	override void initialize()
	{
		core.subsystem.query(timer, logger);
		graphics_context.create(command_buffer, swapchain_texture, fence);
		// config
		swapchain_texture.set(
			GpuSwapchainComposition.HDR_extended_linear,
			GpuPresentMode.immediate,
		);
		// Entity
		core.subsystem.query!ObjectSubsystem().create(object_manager);
		object_manager.create(entity_list)
			.append_component!TransformComponent();
		foreach (entity; entity_list)
		{
			object_manager.attach!TransformComponent(entity);
		}
		object_manager.register!TransformSystem()
			.append_resource(TimerResource(0))
			.initialize();

		// Pipeline
		create_pipeline_defer_texture(graphics_context, pipeline_defer_texture);
		create_pipeline_defer_solid(graphics_context, pipeline_defer_solid);
		create_pipeline_compose(graphics_context, pipeline_compose);
		create_pipeline_compose_debug(graphics_context, pipeline_compose_debug);
		create_pipeline_phong(graphics_context, pipeline_phong);
		create_pipeline_pre_edge(graphics_context, pipeline_pre_edge);
		create_pipeline_post_edge(graphics_context, pipeline_post_edge);
		create_pipeline_post_blur_fog(graphics_context, pipeline_post_blur_fog);
		create_pipeline_post_color(graphics_context, pipeline_post_color);

		// texture, sampler
		object_image = new Surface();
		object_image.load("./image/test_texture.png");
		graphics_context.create(object_texture);
		object_texture.create(GpuTextureCreateInfo(
				GpuTextureType._2d, GpuTextureFormat.r8g8b8a8_unorm,
				GpuTextureUsageFlags.sampler,
				object_image.width, object_image.height,
				1, 1,
		));
		// depth texture
		graphics_context.create(depth_texture);
		depth_texture.create(GpuTextureCreateInfo(
				GpuTextureType._2d,
				GpuTextureFormat.d32_float,
				GpuTextureUsageFlags.depth_stencil_target | GpuTextureUsageFlags.sampler,
				graphics_context.client_width, graphics_context.client_height,
				1, 1, GpuSampleCount.x1,
		));
		// texture
		scope GpuTextureCreateInfo tci;
		graphics_context.create(
			sampler_smooth, sampler_nearest,
			albedo_texture, normal_texture, color_texture, material_texture, entity_texture, edge_texture,
			temp_alpha_texture, temp_beta_texture,
		);
		tci = GpuTextureCreateInfo(
			GpuTextureType._2d, GpuTextureFormat.r16g16b16a16_float,
			tci.usage = GpuTextureUsageFlags.sampler | GpuTextureUsageFlags.compute_storage_write,
			graphics_context.client_width, graphics_context.client_height, 1, 1,
		);
		temp_alpha_texture.create(tci);
		temp_beta_texture.create(tci);
		tci.format = GpuTextureFormat.r8g8b8a8_unorm;
		tci.usage = GpuTextureUsageFlags.sampler | GpuTextureUsageFlags.color_target
			| GpuTextureUsageFlags.compute_storage_read;
		albedo_texture.create(tci);
		tci.format = GpuTextureFormat.r16g16b16a16_float;
		normal_texture.create(tci);
		material_texture.create(tci);
		tci.usage = GpuTextureUsageFlags.sampler | GpuTextureUsageFlags.color_target
			| GpuTextureUsageFlags.compute_storage_simultaneous_read_write;
		color_texture.create(tci);
		tci.format = GpuTextureFormat.r8g8b8a8_unorm;
		edge_texture.create(tci);
		tci.format = GpuTextureFormat.r32g32_int;
		tci.usage = GpuTextureUsageFlags.sampler | GpuTextureUsageFlags.color_target
			| GpuTextureUsageFlags.compute_storage_read;
		entity_texture.create(tci);

		sampler_smooth.create(GpuSamplerCreateInfo(
				GpuFilter.linear, GpuFilter.linear,
		));
		sampler_nearest.create(GpuSamplerCreateInfo(
				GpuFilter.nearest, GpuFilter.nearest,
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
		scope GpuBufferTransferBuffer buffer_transfer_buffer;
		scope GpuTextureTransferBuffer tb_texture;
		graphics_context.create(buffer_transfer_buffer, tb_texture);
		buffer_transfer_buffer.prepare(object_geometry);
		tb_texture
			.create(object_texture.size)
			.map()
			.set(object_image)
			.unmap();

		command_buffer
			.acquire_buffer()
			.copy((copy_pass) {
				copy_pass
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
						GpuTextureRegion(object_texture),
					);
				return;
			}).submit(fence);
		fence.wait();

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
		return;
	}

	GpuCommandBuffer command_buffer;
	GpuSwapchainTexture swapchain_texture;

	override void draw()
	{
		import std.math : PI_2;

		GpuColorTargetInfo[] color_targets;
		GpuDepthStencilTargetInfo depth_target_info;

		UniformScene uniform_scene;
		UniformView uniform_view;
		UniformModelVert uniform_model_vert;
		UniformModelFrag uniform_model_frag;
		UniformLight uniform_light;
		// prepare uniform buffer object
		uniform_scene = UniformScene(Vec4(1f, 1f, 1f, 0.1f));
		uniform_view = UniformView(
			transformer_look_at(Vec3(0f, 0f, -3.0f), Vec3(0f, 0f, 0f), Vec3(0f, 1f, 0f)),
			transformer_perspective(PI_2),
			Vec3(0f, 0f, -3.0f),
		);
		with (uniform_light.light_point_list[0])
		{
			pos = Vec4(0f, +0.5f, -3f, 1.0f);
			color = Vec4(0.7f, 0.7f, 0.7f, 0f);
			intensity = 1.0;
		}
		// render
		command_buffer
			.acquire_buffer()
			.acquire_texture(swapchain_texture);
		if (swapchain_texture.handle !is null)
		{
			color_targets = [
				GpuColorTargetInfo(
					albedo_texture, GpuLoadOp.clear, GpuStoreOp.store,
				),
				GpuColorTargetInfo(
					normal_texture, GpuLoadOp.clear, GpuStoreOp.store,
				),
				GpuColorTargetInfo(
					material_texture, GpuLoadOp.clear, GpuStoreOp.store,
				),
				GpuColorTargetInfo(
					entity_texture, 0, 0, ColorF(0f, 0f, 0f, 0f), GpuLoadOp.clear, GpuStoreOp.store,
				),
			];
			depth_target_info = GpuDepthStencilTargetInfo(
				depth_texture.handle,
				1.0f,
				GpuLoadOp.clear, GpuStoreOp.dont_care,
			);
			// g-buffer
			command_buffer.render(
				(render_pass) {
				// prepare pipeline_defer
				render_pass
					.push_vertex(1, uniform_view)
					.push_fragment(1, uniform_view);
				// foreach entity
				foreach (entity; entity_list)
				{
					// update UB
					uniform_model_vert = UniformModelVert(
						object_manager.component.get!TransformComponent(entity)
						.model_matrix()
					);
					uniform_model_frag = UniformModelFrag(0.5f, 64.0f, entity.index + 1);

					render_pass
						.bind(
							pipeline_defer_texture,
							[
								GpuTextureSamplerBinding(object_texture, sampler_smooth)
							],
							[vertex_buffer], index_buffer,
						)
						.push_vertex(2, uniform_model_vert)
						.push_fragment(2, uniform_model_frag)
						.draw_indexed(ParamIndexedPrimitive(cast(uint) object_geometry.count_index, 1, 0, 0, 0));
				}
			},
				color_targets,
				depth_target_info,
			);
			// phong
			command_buffer
				.compute(
					(compute_pass) {
					compute_pass.bind(pipeline_phong)
						.bind(
							GpuTextureSamplerBinding(depth_texture, sampler_nearest),
							GpuTextureSamplerBinding(albedo_texture, sampler_smooth),
							GpuTextureSamplerBinding(normal_texture, sampler_nearest),
							GpuTextureSamplerBinding(material_texture, sampler_nearest),
						)
						.push(0, uniform_scene, uniform_view, uniform_light,)
						.dispatch(graphics_context.client_width / 8, graphics_context.client_height / 8, 1);
					return;
				}, [GpuStorageTextureReadWriteBinding(color_texture)],
				);
			// pre_edge
			command_buffer
				.compute(
					(compute_pass) {
					compute_pass.bind(pipeline_pre_edge)
						.bind(
							GpuTextureSamplerBinding(depth_texture, sampler_nearest),
							GpuTextureSamplerBinding(normal_texture, sampler_nearest),
							GpuTextureSamplerBinding(entity_texture, sampler_nearest),
						)
						.push(0, uniform_view)
						.dispatch(graphics_context.client_width / 8, graphics_context.client_height / 8, 1);
					return;
				},
					[GpuStorageTextureReadWriteBinding(edge_texture)],
				);
			// compose
			command_buffer
				.compute(
					(compute_pass) {
					compute_pass.bind(pipeline_compose)
						.bind(
							GpuTextureSamplerBinding(depth_texture, sampler_nearest),
							GpuTextureSamplerBinding(albedo_texture, sampler_smooth),
							GpuTextureSamplerBinding(color_texture, sampler_nearest),
						)
						.dispatch(graphics_context.client_width / 8, graphics_context.client_height / 8, 1);
					return;
				}, [GpuStorageTextureReadWriteBinding(temp_alpha_texture)],
				);
			// compose_debug
			/+
			command_buffer.compute(
				(compute_pass) {
				compute_pass.bind(pipeline_compose_debug)
					.bind(
						GpuTextureSamplerBinding(depth_texture, sampler_nearest),
						GpuTextureSamplerBinding(albedo_texture, sampler_smooth),
						GpuTextureSamplerBinding(normal_texture, sampler_nearest),
						GpuTextureSamplerBinding(color_texture, sampler_nearest),
						GpuTextureSamplerBinding(material_texture, sampler_nearest),
						GpuTextureSamplerBinding(entity_texture, sampler_nearest),
						GpuTextureSamplerBinding(edge_texture, sampler_nearest),
					)
					.push(0, UniformComposeConfig(0),)
					.dispatch(graphics_context.client_width / 8, graphics_context.client_height / 8, 1);
				return;
			},
				[GpuStorageTextureReadWriteBinding(render_texture)],
				null,
			);+/
			// post_blur_fog
			command_buffer.compute(
				(compute_pass) {
				compute_pass.bind(pipeline_post_blur_fog)
					.bind(
						GpuTextureSamplerBinding(depth_texture, sampler_nearest,),
						GpuTextureSamplerBinding(temp_alpha_texture, sampler_nearest,),
					)
					.push(
						0,
						UniformPostBlurFog(0.1, 5.0, 0.1, 5.0, ColorF(0.5, 0.7, 0.9, 1.0)),
						uniform_view,
					)
					.dispatch(graphics_context.client_width / 8, graphics_context.client_height / 8, 1);
				return;
			},
				[GpuStorageTextureReadWriteBinding(temp_beta_texture)],
				null,
			);
			// post_edge
			/+command_buffer.compute(
				(compute_pass) {
				compute_pass.bind(pipeline_post_edge)
					.bind(
						GpuTextureSamplerBinding(edge_texture, sampler_nearest,),
					)
					.push(
						UniformPostEdge(
						Vec4(1.0f, 1.0f, 1.0f, 1.0f),
						Vec4(0.0f, 0.0f, 0.0f, 1.0f),
						Vec4(1.0f, 1.0f, 1.0f, 1.0f),
					)
				)
					.dispatch(graphics_context.client_width / 8, graphics_context.client_height / 8, 1);
				return;
			},
				[GpuStorageTextureReadWriteBinding(post_color_texture)],
				null,
			);+/
			// tonemap
			command_buffer.compute(
				(compute_pass) {
				compute_pass.bind(pipeline_post_color)
					.bind(
						GpuTextureSamplerBinding(temp_beta_texture, sampler_nearest,),
					)
					.push(
						0,
						UniformColorMode(1),
						UniformColor(),
						UniformTone(0.4, 0.6, 0.3, 0.7),
					)
					.dispatch(graphics_context.client_width / 8, graphics_context.client_height / 8, 1);
				return;
			},
				[GpuStorageTextureReadWriteBinding(temp_alpha_texture)],
				null,
			);
			// blit
			command_buffer.blit(
				GpuBlitInfo(
					GpuBlitRegion(temp_alpha_texture),
					GpuBlitRegion(swapchain_texture),
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
