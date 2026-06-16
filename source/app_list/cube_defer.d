module app_list.cube_defer;

import app_list.app_interface;
import app_list.uniform;

import app_list.ecs;

import app_list.pipeline;

/+import app_list.pipeline.pre_phong;
import app_list.pipeline.post_shade;
import app_list.pipeline.post_edge;+/

import kelp_core;
import kelp_sdl;
import kelp_gfx;

class CubeDeferDemo : AppInterface
{
	Core core;
	TimerSubsystem timer;
	TimerSubsystem logger;
	GfxGraphicsContext graphics_context;

	GpuGraphicsPipeline pipeline_defer;
	GpuComputePipeline pipeline_compose, pipeline_phong, pipeline_edge;
	GfxMesh object_mesh;
	GfxGeometry!(VertexPNU, uint) object_geometry;

	GpuTexture render_texture, depth_texture;
	GpuTexture albedo_texture, normal_texture, color_texture, material_texture, pos_texture;
	GpuSampler sampler_nearest, sampler_smooth;

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

		// Pipeline
		create_pipeline_defer(graphics_context, pipeline_defer);
		create_pipeline_compose(graphics_context, pipeline_compose);
		create_pipeline_phong(graphics_context, pipeline_phong);
		create_pipeline_edge(graphics_context, pipeline_edge);

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

		graphics_context.create(depth_texture);
		depth_texture.create(GpuTextureCreateInfo(
				GpuTextureType._2d,
				GpuTextureFormat.d32_float,
				GpuTextureUsageFlags.depth_stencil_target | GpuTextureUsageFlags.sampler,
				graphics_context.client_width, graphics_context.client_height,
				1, 1, GpuSampleCount.x1,
		));

		graphics_context.create(
			render_texture, sampler_smooth, sampler_nearest,
			albedo_texture, normal_texture, color_texture, material_texture, pos_texture,
		);
		render_texture.create(GpuTextureCreateInfo(
				GpuTextureType._2d, GpuTextureFormat.r32g32b32a32_float,
				GpuTextureUsageFlags.sampler | GpuTextureUsageFlags.compute_storage_simultaneous_read_write,
				graphics_context.client_width, graphics_context.client_height, 1, 1,
		));
		scope GpuTextureCreateInfo tci;
		tci = GpuTextureCreateInfo(
			GpuTextureType._2d, GpuTextureFormat.r32g32b32a32_float,
			GpuTextureUsageFlags.sampler | GpuTextureUsageFlags.color_target | GpuTextureUsageFlags.compute_storage_simultaneous_read_write,
			graphics_context.client_width, graphics_context.client_height, 1, 1,
		);
		albedo_texture.create(tci);
		normal_texture.create(tci);
		color_texture.create(tci);
		material_texture.create(tci);
		pos_texture.create(tci);

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
		buffer_transfer_buffer.create(object_geometry.size)
			.map()
			.set(object_geometry.vertices, object_geometry.offset_vertex)
			.set(object_geometry.indices, object_geometry.offset_index)
			.unmap();
		tb_texture.create(object_texture.size)
			.map()
			.set(object_image)
			.unmap();

		command_buffer.acquire_buffer()
			.with_copy_pass((ref copy_pass) {
				copy_pass.upload(
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
			}).submit();
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

	GpuCommandBuffer command_buffer;
	GpuSwapchainTexture swapchain_texture;

	override void draw()
	{

		import std.math;

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
			Vec3(0f, 0f, -3.0f),
		);
		with (uniform_light.light_point_list[0])
		{
			pos = Vec4(0f, +0.5f, -3f, 1.0f);
			color = Vec4(0.7f, 0.7f, 0.7f, 0f);
			intensity = 1.0;
		}
		// render
		command_buffer.acquire_buffer()
			.acquire_texture(swapchain_texture);
		if (swapchain_texture.handle !is null)
		{
			color_targets = [
				GpuColorTargetInfo(
					albedo_texture,
					GpuLoadOp.clear, GpuStoreOp.store,
				),
				GpuColorTargetInfo(
					normal_texture,
					GpuLoadOp.clear, GpuStoreOp.store,
				),
				GpuColorTargetInfo(
					material_texture,
					GpuLoadOp.clear, GpuStoreOp.store,
				),
			];
			depth_target_info = GpuDepthStencilTargetInfo(
				depth_texture.handle,
				1.0f,
				GpuLoadOp.clear, GpuStoreOp.dont_care,
			);
			// g-buffer
			command_buffer.with_render_pass(
				color_targets,
				depth_target_info,
				(render_pass) {
				// prepare pipeline_defer
				render_pass.push_vertex(uniform_view, 1)
					.push_fragment(uniform_view, 1);
				// foreach entity
				foreach (entity; entity_list)
				{
					// update UB
					uniform_model_vert = UniformModelVert(
						object_manager.component.get!TransformComponent(entity)
						.model_matrix()
					);
					uniform_model_frag = UniformModelFrag(0.5f, 64.0f, 1);

					render_pass.bind(pipeline_defer)
						.bind([
							GpuTextureSamplerBinding(object_texture, sampler_smooth)
						], 0)
						.bind([vertex_buffer])
						.bind(index_buffer)
						.push_vertex(uniform_model_vert, 2)
						.push_fragment(uniform_model_frag, 2u)
						.draw_indexed(ParamIndexedPrimitive(cast(uint) object_geometry.count_index, 1, 0, 0, 0));
				}
			},);
			// phong
			
			command_buffer.with_compute_pass(
				[GpuStorageTextureReadWriteBinding(color_texture)],
				null,
				(compute_pass) {
				compute_pass.bind(pipeline_phong)
					.bind([
						GpuTextureSamplerBinding(albedo_texture, sampler_smooth),
						GpuTextureSamplerBinding(normal_texture, sampler_nearest),
						GpuTextureSamplerBinding(material_texture, sampler_nearest),
						GpuTextureSamplerBinding(depth_texture, sampler_nearest),
					])
					.push(uniform_scene, 0)
					.push(uniform_view, 1)
					.push(uniform_light, 2)
					.dispatch(graphics_context.client_width / 8, graphics_context.client_height / 8, 1);
				return;
			}
			);
			// compose
			command_buffer.with_compute_pass(
				[GpuStorageTextureReadWriteBinding(render_texture)],
				null,
				(compute_pass) {
				compute_pass.bind(pipeline_compose)
					.bind(
						[
						GpuTextureSamplerBinding(albedo_texture, sampler_smooth),
						GpuTextureSamplerBinding(normal_texture, sampler_nearest),
						GpuTextureSamplerBinding(color_texture, sampler_nearest),
						GpuTextureSamplerBinding(material_texture, sampler_nearest),
						GpuTextureSamplerBinding(depth_texture, sampler_nearest),
					], 0
				)
					.push(UniformComposeConfig(0), 0)
					.dispatch(graphics_context.client_width / 8, graphics_context.client_height / 8, 1);
				return;
			}
			);

			// post_edge
			command_buffer.with_compute_pass(
				[GpuStorageTextureReadWriteBinding(render_texture)],
				null,
				(compute_pass) {
				compute_pass.bind(pipeline_edge)
					.bind(
						[
						GpuTextureSamplerBinding(albedo_texture, sampler_smooth),
						GpuTextureSamplerBinding(normal_texture, sampler_nearest),
						GpuTextureSamplerBinding(material_texture, sampler_nearest),
						GpuTextureSamplerBinding(depth_texture, sampler_nearest),
					], 0
				)
					.push(uniform_view)
					.dispatch(graphics_context.client_width / 8, graphics_context.client_height / 8, 1);
				return;
			}
			);

			// blit
			command_buffer.blit_texture(
				GpuBlitInfo(
					GpuBlitRegion(render_texture),
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
