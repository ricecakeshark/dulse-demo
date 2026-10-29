module app_list.cube_defer.cube_defer;

import app_list.app_interface;
import app_list.cube_defer;

import dulse;
import dulse_sdl;
import dulse_gfx;
import dulse_preset;

import std.math : PI_2;

class CubeDeferDemo : AppInterface
{
	Core core;
	TimerSubsystem timer;
	LoggerSubsystem logger;
	GraphicsContext gc;

	GraphicsPipeline pipeline_defer_texture, pipeline_defer_solid;
	ComputePipeline pipeline_compose, pipeline_compose_debug;
	ComputePipeline pipeline_phong, pipeline_pre_edge, pipeline_post_edge,
	pipeline_post_blur, pipeline_post_fog, pipeline_post_color;

	Texture depth_texture;
	Texture albedo_texture, normal_texture, color_texture, material_texture, entity_texture, edge_texture;
	TextureAlternate alt_texture;
	GpuSampler sampler_nearest, sampler_smooth;
	GpuFence fence;

	GfxMesh object_mesh;
	GfxGeometry!(VertexPNU, uint) object_geometry;
	VertexBuffer vertex_buffer;
	IndexBuffer index_buffer;

	Texture object_texture;
	Surface object_image;

	Entity[4] entity_list;
	ObjectManager object_manager;

	UniformScene uniform_scene = UniformScene(Vec4(1f, 1f, 1f, 0.1f));
	UniformView uniform_view = UniformView(
		transformer_look_at(Vec3(0f, 0f, -3.0f), Vec3(0f, 0f, 0f), Vec3(0f, 1f, 0f)),
		transformer_perspective(PI_2),
		Vec3(0f, 0f, -3.0f),
	);
	UniformModelVert uniform_model_vert;
	UniformModelFrag uniform_model_frag;
	UniformLight uniform_light;
	UniformColor uniform_color;

	this(Core core)
	{
		this.core = core;
		this.gc = core.subsystem.query!GraphicsSubsystem()[0].context;
		return;
	}

	override void initialize()
	{
		core.subsystem.query(timer, logger);
		gc.create(command_buffer, swapchain_texture, /+fence+/);
		// config
		swapchain_texture.set(
			GpuSwapchainComposition.HDR_extended_linear,
			GpuPresentMode.immediate,
		);
		// Entity
		core.subsystem.query!ObjectSubsystem()[0].create(object_manager);
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
		create_pipeline_defer_texture(gc, pipeline_defer_texture);
		create_pipeline_defer_solid(gc, pipeline_defer_solid);
		create_pipeline_compose(gc, pipeline_compose);
		//create_pipeline_compose_debug(gc, pipeline_compose_debug);
		create_pipeline_phong(gc, pipeline_phong);
		create_pipeline_pre_edge(gc, pipeline_pre_edge);
		create_pipeline_post_edge(gc, pipeline_post_edge);
		create_pipeline_post_blur(gc, pipeline_post_blur);
		create_pipeline_post_fog(gc, pipeline_post_fog);
		create_pipeline_post_color(gc, pipeline_post_color);

		// texture, sampler
		object_image = new Surface();
		object_image.load("./image/test_texture.png");
		gc.create(object_texture);
		object_texture.create(GpuTextureCreateInfo(
				GpuTextureType._2d, GpuTextureFormat.r8g8b8a8_unorm,
				GpuTextureUsageFlags.sampler,
				object_image.width, object_image.height,
				1, 1,
		));
		// depth texture
		gc.create(depth_texture);
		depth_texture.create(GpuTextureCreateInfo(
				GpuTextureType._2d,
				GpuTextureFormat.d32_float,
				GpuTextureUsageFlags.depth_stencil_target | GpuTextureUsageFlags.sampler,
				gc.client_width, gc.client_height,
				1, 1, GpuSampleCount.x1,
		));
		// texture
		scope GpuTextureCreateInfo tci;
		gc.create(
			sampler_nearest, sampler_smooth,
			albedo_texture, normal_texture, material_texture, entity_texture,
			color_texture, edge_texture,
		);
		sampler_nearest.set_to(
			albedo_texture, normal_texture, material_texture, entity_texture,
			color_texture, edge_texture,
		);
		albedo_texture.set(gc.preset.albedo).create();
		normal_texture.set(gc.preset.normal,).create();
		material_texture.set(gc.preset.material,).create();
		entity_texture.set(gc.preset.entity,).create();
		color_texture.set(gc.preset.color,).create();
		edge_texture.set(gc.preset.edge,).create();

		// alt texture
		gc.create(alt_texture);
		alt_texture.create(GpuTextureCreateInfo(
				GpuTextureType._2d, GpuTextureFormat.r16g16b16a16_float,
				tci.usage = GpuTextureUsageFlags.sampler | GpuTextureUsageFlags.compute_storage_write,
				gc.client_width, gc.client_height, 1, 1,
		));

		// sampler
		sampler_smooth.create(GpuSamplerCreateInfo(
				GpuFilter.linear, GpuFilter.linear,
		));
		sampler_nearest.create(GpuSamplerCreateInfo(
				GpuFilter.nearest, GpuFilter.nearest,
		));

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
					vertex_buffer,
					index_buffer,
				),
				sequence(
					tb_texture,
					object_texture,
				),
			)
			.submit();
			//.submit(fence);
			//fence.wait();
		return;
	}

	override void finalize()
	{
		gc.resource_store.release_all();
		alt_texture.release();
		return;
	}

	override void process()
	{
		with (object_manager.resource.query!TimerResource())
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
		// prepare uniform buffer object
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
							GpuTextureSamplerBinding(object_texture, sampler_smooth),
							vertex_buffer, index_buffer,
						)
						.push_vertex(2, uniform_model_vert)
						.push_fragment(2, uniform_model_frag)
						.draw_indexed(ParamIndexedPrimitive(cast(uint) object_geometry.count_index, 1, 0, 0, 0));
				}
			},
				[
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
				],
				GpuDepthStencilTargetInfo(
					depth_texture.handle,
					1.0f,
					GpuLoadOp.clear, GpuStoreOp.dont_care,
			),
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
						.dispatch(
							pipeline_phong.dispatch_size(gc.client_size)
						);
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
						.dispatch(
							pipeline_pre_edge.dispatch_size(gc.client_size)
						);
					return;
				},
					[GpuStorageTextureReadWriteBinding(edge_texture)],
				);
			// compose
			alt_texture.swap();
			command_buffer
				.compute(
					(compute_pass) {
					compute_pass.bind(pipeline_compose)
						.bind(
							GpuTextureSamplerBinding(depth_texture, sampler_nearest),
							GpuTextureSamplerBinding(albedo_texture, sampler_smooth),
							GpuTextureSamplerBinding(color_texture, sampler_nearest),
						)
						.dispatch(
							pipeline_compose.dispatch_size(gc.client_size)
						);
					return;
				}, [GpuStorageTextureReadWriteBinding(alt_texture.dest)],
				);
			// post_blur
			alt_texture.swap();
			command_buffer.compute(
				(compute_pass) {
				compute_pass.bind(pipeline_post_blur)
					.bind(
						GpuTextureSamplerBinding(depth_texture, sampler_nearest,),
						GpuTextureSamplerBinding(alt_texture.src, sampler_nearest,),
					)
					.push(
						0,
						UniformPostBlur(0.1, 5.0,),
						uniform_view,
					)
					.dispatch(
						pipeline_post_blur.dispatch_size(gc.client_size),
					);
				return;
			},
				[GpuStorageTextureReadWriteBinding(alt_texture.dest)],
				null,
			);
			// post_fog
			alt_texture.swap();
			command_buffer.compute(
				(compute_pass) {
				compute_pass.bind(pipeline_post_fog)
					.bind(
						GpuTextureSamplerBinding(depth_texture, sampler_nearest,),
						GpuTextureSamplerBinding(alt_texture.src, sampler_nearest,),
					)
					.push(
						0,
						UniformPostFog(0.1, 5.0, ColorF(1.0, 1.0, 1.0, 1.0)),
						uniform_view,
					)
					.dispatch(
						pipeline_post_fog.dispatch_size(gc.client_size),
					);
				return;
			},
				[GpuStorageTextureReadWriteBinding(alt_texture.dest)],
				null,
			);
			// post_edge
			command_buffer.compute(
				(compute_pass) {
				compute_pass.bind(pipeline_post_edge)
					.bind(
						GpuTextureSamplerBinding(edge_texture, sampler_nearest,),
					)
					.push(
						0,
						UniformPostEdge(
						Vec4(1.0f, 1.0f, 0.0f, 1.0f),
						Vec4(0.0f, 0.0f, 0.0f, 1.0f),
						Vec4(0.0f, 1.0f, 1.0f, 1.0f),
					)
				)
					.dispatch(
						pipeline_post_edge.dispatch_size(gc.client_size),
					);
				return;
			},
				[GpuStorageTextureReadWriteBinding(alt_texture.dest)],
				null,
			);
			// color_process
			uniform_color.mode.output_mode = 1;
			uniform_color.color = UniformColorColor(+0.0, 1.0);
			uniform_color.tone = UniformColorTone(0.1, 1.0, 0.0, 12.5);
			alt_texture.swap();
			command_buffer.compute(
				(compute_pass) {
				compute_pass.bind(pipeline_post_color)
					.bind(
						GpuTextureSamplerBinding(alt_texture.src, sampler_nearest,),
					)
					.push(
						0,
						uniform_color.mode,
						uniform_color.color,
						uniform_color.tone,
					)
					.dispatch(
						pipeline_post_color.dispatch_size(gc.client_size),
					);
				return;
			},
				[GpuStorageTextureReadWriteBinding(alt_texture.dest)],
				null,
			);
			// blit
			command_buffer.blit(
				GpuBlitInfo(
					GpuBlitRegion(alt_texture.dest),
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
