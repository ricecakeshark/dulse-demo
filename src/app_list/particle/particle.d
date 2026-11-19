module app_list.particle.particle;

import app_list.app_interface;
import app_list.particle;

import dulse;
import dulse_sdl;
import dulse_gfx;
import dulse_preset;

import std.math : PI_2;
import std.range:repeat;

class ParticleDemo : AppInterface
{
	Core core;
	TimerSubsystem timer;
	LoggerSubsystem logger;
	GraphicsContext gc;

	CommandBuffer cb;
	SwapchainTexture swapchain_texture;

	ComputePipeline pipeline_particle_process;
	GraphicsPipeline pipeline_particle_draw;
	ComputePipeline pipeline_compose;
	Texture depth_texture;
	Texture albedo_texture, normal_texture, color_texture, material_texture, entity_texture, edge_texture;
	Texture object_texture;
	TextureAlternate texture_alt;
	Sampler sampler_nearest, sampler_smooth;
	ObjectManager object_manager;

	UniformScene uniform_scene;
	UniformView uniform_view;
	UniformModelVert uniform_model_vert;
	GfxMesh object_mesh;
	GfxGeometry!(VertexTex, uint) object_geometry;
	VertexBuffer vertex_buffer;
	IndexBuffer index_buffer;
	GpuBufferTransferBuffer bt_buffer;
	StorageBuffer particle_buffer;

	this(Core core)
	{
		this.core = core;
		this.gc = core.subsystem.query!GraphicsSubsystem()[0].context;
		return;
	}

	override void initialize()
	{
		core.subsystem.query(timer, logger);
		gc.create(cb, swapchain_texture,);
		// config
		swapchain_texture.set(
			GpuSwapchainComposition.HDR_extended_linear,
			GpuPresentMode.immediate,
		);
		// Entity

		core.subsystem.query!ObjectSubsystem()[0].create(object_manager);
		/+foreach (entity; entity_list)
		{
			object_manager.attach!TransformComponent(entity);
		}+/
		object_manager
			.append_resource(TimerResource(0))
			.initialize();

		// Pipeline
		gc.create_pipeline_particle_process(
			pipeline_particle_process,
		);
		gc.create_pipeline_particle_draw(
			pipeline_particle_draw,
		);
		create_pipeline_compose(
			gc, pipeline_compose,
		);

		// texture, sampler
		gc.create(
			sampler_nearest, sampler_smooth,
			depth_texture,
			albedo_texture, normal_texture, material_texture, entity_texture,
			color_texture,
			object_texture,
			texture_alt,
		);
		// preset
		depth_texture.set(gc.preset.depth).create();
		albedo_texture.set(gc.preset.albedo).create();
		normal_texture.set(gc.preset.normal,).create();
		material_texture.set(gc.preset.material,).create();
		entity_texture.set(gc.preset.entity,).create();
		color_texture.set(gc.preset.color,).create();
		texture_alt.src.set(gc.preset.alt).create();

		sampler_smooth.create(GpuSamplerCreateInfo(
				GpuFilter.linear, GpuFilter.linear,
		));
		// object
		scope Surface object_image;
		object_image = new Surface();
		object_image.load("./image/test_texture.png");
		gc.create(object_texture);
		object_texture.create(GpuTextureCreateInfo(
				GpuTextureType._2d, GpuTextureFormat.r8g8b8a8_unorm,
				GpuTextureUsageFlags.sampler,
				object_image.width, object_image.height,
				1, 1,
		));
		sampler_smooth.set_to(object_texture);
		//
		GpuBufferTransferBuffer vi_buffer;
		gc.create(vi_buffer, vertex_buffer, index_buffer,);

		FileHandler("./model/octahedron.obj").load_obj(object_geometry);
		// Mesh
		object_mesh.initialize(
			VertexTex.sizeof * object_geometry.count_vertex,
			uint.sizeof * object_geometry.count_index,
		);
		object_mesh.set([object_geometry]);
		vertex_buffer.create(object_geometry.count_vertex, object_geometry.stride_vertex);
		index_buffer.create(object_geometry.count_index, GpuIndexElementSize._32bit);
		vi_buffer.prepare(object_geometry);
		cb.acquire_buffer()
			.copy(
				sequence(vi_buffer, vertex_buffer, index_buffer),
			)
			.submit();

		// particle buffer
		gc.create(
			bt_buffer, particle_buffer,
		);
		particle_buffer.create(
			Particle.sizeof * 100,
			GpuBufferUsageFlags.compute_storage_write,
		);
		bt_buffer.create(Particle.sizeof * 100);
		Particle[100] particle_list;
		foreach(ref particle;particle_list)
		{
			particle = Particle(0);
		}
		bt_buffer.map()
			.set(particle_list, 0u
		).unmap();

		cb.acquire_buffer()
			.copy(
				sequence(bt_buffer, particle_buffer,),
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
		with (object_manager.resource.query!TimerResource())
		{
			elapsed_time = cast(uint) timer.past;
		}
		return;
	}

	override void draw()
	{

		uniform_view = UniformView(
			transformer_look_at(Vec3(0f, 0f, -10.0f), Vec3(0f, 0f, 0f), Vec3(0f, 1f, 0f)),
			transformer_perspective(PI_2),
			Vec3(0f, 0f, -3.0f),
		);
		// process particle
		cb
			.acquire_buffer()
			.acquire_texture(swapchain_texture);
		if (swapchain_texture.handle !is null)
		{
			// process particle
			cb.compute(
				(pass) {
				pass
					.bind_all(
						pipeline_particle_process,
					)
					.dispatch(1, 1, 1);
				return;
			},
				particle_buffer,
			);

			// render particle
			cb.render(
				(render_pass) {
				// prepare pipeline_defer
				render_pass
					.push_vert(1,
						uniform_view, uniform_model_vert,
					)
					.push_frag(1,
						uniform_view,
					)
					.bind_all(
						pipeline_particle_draw,
						vertex_buffer,index_buffer,
					)
					.bind_to_vertex(0, particle_buffer,)
					.draw_indexed(
						ParamIndexedPrimitive(cast(uint)object_geometry.count_vertex, 100, 0, 0, )
					);
			},
				[
					GpuColorTargetInfo(
						texture_alt.src, GpuLoadOp.clear, GpuStoreOp.store,
					),
				],
				GpuDepthStencilTargetInfo(
					depth_texture.handle,
					1.0f,
					GpuLoadOp.clear, GpuStoreOp.dont_care,
			),
			);
			// blit
			cb.blit(
				GpuBlitInfo(
					GpuBlitRegion(texture_alt.src),
					GpuBlitRegion(swapchain_texture),
			)
			);
		}
		cb.submit();
		return;
	}

	override int opCmp(Object other) const
	{
		return 0;
	}
}

import std.random;

struct Particle
{
	Vec3 pos;
	Vec3 vel;

	this(float init)
	{
		pos = Vec3(uniform(-1f, +1f), uniform(-1f, +1f), uniform(-1f, +1f),);
		vel = Vec3(uniform(-1f, +1f), uniform(-1f, +1f), uniform(-1f, +1f),);
		return;
	}
}
