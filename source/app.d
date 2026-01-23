module myapp;

import kelp_core;
import kelp_sdl;
import kelp_render;
import bindbc.sdl;

import std.math;
import std.stdio;
import core.memory;

GfxGraphicsContext graphics_context;

float aspect = 960.0f / 540.0f;

void main()
{
	Core core;
	DeviceSubsystem device;

	core = new Core();
	core.subsystem.append(
		new SDLSubsystem(core),
		new SDLDeviceSubsystem(core),
		new SDLEventSubsystem(core), //new SDLGraphicsSubsystem()

		

	);
	core.initialize();
	device = core.subsystem.pool.query!(DeviceSubsystem)();

	graphics_context = new GfxGraphicsContext();
	graphics_context.initialize();
	auto app = new TestApp(core, graphics_context);
	app.initialize();

	while (core.continuable)
	{
		core.process();
		if (device.keyboard.pressed_just(Scancode.escape))
		{
			writeln("pressed ESC");
			break;
		}
		app.process();
		app.draw();
	}
	app.finalize();
	core.finalize();

	return;
}

class TestApp
{
	Core core;
	SDLDeviceSubsystem device;
	TimerSubsystem timer;
	GfxGraphicsContext graphics_context;

	GfxRenderContext render_context;
	GfxGeometry!(VertexPT, ushort) geometry;
	GpuGraphicsPipeline graphics_pipeline;
	GpuVertexBuffer vertex_buffer;
	GpuIndexBuffer index_buffer;
	GpuTexture texture;
	GpuSampler sampler;

	Surface image;

	float[3][100] entity_list;

	this(Core core, GfxGraphicsContext graphics_context)
	{
		this.core = core;
		this.graphics_context = graphics_context;
		return;
	}

	void initialize()
	{
		foreach (ref entity; entity_list)
		{
			import std.random;

			entity[0] = uniform(0.5f, 1.3f);
			entity[1] = uniform(0.5f, 1.3f);
			entity[2] = uniform(0.5f, 1.3f);
		}
		// Shader
		scope GpuVertexShader vertex_shader;
		scope GpuFragmentShader fragment_shader;
		vertex_shader = graphics_context.create_vertex_shader();
		fragment_shader = graphics_context.create_fragment_shader();
		vertex_shader.create(
			ShaderFile("TexturedQuadWithMatrix.vert", graphics_context.get_shader_format()),
			GpuShaderArguments(0, 1, 0, 0),
		);
		fragment_shader.create(
			ShaderFile("TexturedQuadWithMultiplyColor.frag", graphics_context.get_shader_format()),
			GpuShaderArguments(1, 1, 0, 0),
		);
		// Pipeline
		scope GpuGraphicsPipelineCreateInfo pipeline_create_info;
		pipeline_create_info.vertex_shader = vertex_shader.handle;
		pipeline_create_info.fragment_shader = fragment_shader.handle;
		with (pipeline_create_info)
		{
			vertex_input_state = GpuVertexInputState(
				[
				GpuVertexBufferDescription(
					0,
					VertexPT.sizeof,
					GpuVertexInputRate.vertex,
					0
				)
			],
			[
				GpuVertexAttribute(
					0, 0, GpuVertexElementFormat.float3, 0
				),
				GpuVertexAttribute(
					1, 0, GpuVertexElementFormat.float2, float.sizeof * 3
				)
			]
			);
			primitive_type = SDL_GPU_PRIMITIVETYPE_TRIANGLELIST;
			target_info = GpuGraphicsPipelineTargetInfo(
				[
				GpuColorTargetDescription(
					graphics_context.get_swapchain_texture_format(),
					GpuColorTargetBlendState(
						GpuBlendFactor.src_alpha,
						GpuBlendFactor.one_minus_src_alpha,
						GpuBlendOp.add,
						GpuBlendFactor.src_alpha,
						GpuBlendFactor.one_minus_src_alpha,
						GpuBlendOp.add,
						cast(GpuColorComponentFlags) SDL_GPUColorComponentFlags.init,
						true,
				)
				)
			]
			);
		}
		graphics_pipeline = graphics_context.create_graphics_pipeline();
		graphics_pipeline.create(pipeline_create_info);

		// Geometry
		geometry.vertex = [
			VertexPT(Vec3(-0.5f, -0.5f, 0.0f), Vec2(0.0f, 0.0f,)),
			VertexPT(Vec3(+0.5f, -0.5f, 0.0f,), Vec2(1.0f, 0.0f,)),
			VertexPT(Vec3(0.5f, +0.5f, 0.0f,), Vec2(1.0f, 1.0f,)),
			VertexPT(Vec3(-0.5f, +0.5f, 0.0f,), Vec2(0.0f, 1.0f,)),
		];
		geometry.index = [0, 1, 2, 0, 2, 3];
		// Buffer
		vertex_buffer = graphics_context.create_vertex_buffer();
		vertex_buffer.create(geometry.size_vertex);
		index_buffer = graphics_context.create_index_buffer();
		index_buffer.create(geometry.size_index);

		// texture
		image = new Surface();
		image.load("./image/dot4.png");
		texture = graphics_context.create_texture();
		texture.create(GpuTextureCreateInfo(
				GpuTextureType._2d, GpuTextureFormat.r8g8b8a8_unorm,
				GpuTextureUsageFlags.sampler,
				image.width, image.height,
				1, 1,
		));

		// sampler
		sampler = graphics_context.create_sampler();
		sampler.create(GpuSamplerCreateInfo(
				GpuFilter.nearest,
				GpuFilter.nearest,
				GpuSamplerMipmapMode.nearest,
				GpuSamplerAddressMode.clamp_to_edge,
				GpuSamplerAddressMode.clamp_to_edge,
				GpuSamplerAddressMode.clamp_to_edge,
		));

		// upload
		scope GpuBufferTransferBuffer buffer_transfer_buffer;
		buffer_transfer_buffer = new GpuBufferTransferBuffer(graphics_context.device);
		buffer_transfer_buffer.create(geometry.size)
			.map()
			.set(geometry.vertex, geometry.offset_vertex)
			.set(geometry.index, geometry.offset_index)
			.unmap();

		scope GpuTextureTransferBuffer texture_transfer_buffer;
		texture_transfer_buffer = new GpuTextureTransferBuffer(graphics_context.device);
		texture_transfer_buffer.create(image.size)
			.map()
			.set(image)
			.unmap();

		scope GfxUploadContext upload_context;
		upload_context = graphics_context.create_upload_context();
		upload_context.begin()
			.upload(
				GpuTransferBufferLocation(buffer_transfer_buffer, geometry.offset_vertex),
				GpuBufferRegion(vertex_buffer, 0u)
			)
			.upload(
				GpuTransferBufferLocation(buffer_transfer_buffer, geometry.offset_index),
				GpuBufferRegion(index_buffer, 0u)
			)
			.upload(
				GpuTextureTransferInfo(texture_transfer_buffer, 0),
				GpuTextureRegion(texture.handle, 0, 0, 0, 0, 0, image.width, image.height, 1)
			)
			.end()
			.submit();

		destroy(buffer_transfer_buffer);
		destroy(texture_transfer_buffer);

		render_context = graphics_context.create_render_context();
		timer = core.subsystem.pool.query!(TimerSubsystem)();
		return;
	}

	void finalize()
	{
		graphics_context.release_all();
		return;
	}

	float x = 0.0f;
	float y = 0.0f;
	float z = 0.0f;

	void process()
	{

		return;
	}

	void draw()
	{
		import std.math;

		GpuColorTargetInfo color_target_info;
		Matrix!(4, 4) pos_mat;

		render_context.acquire_buffer()
			.acquire_texture()
			.if_acquired(() {
				color_target_info = GpuColorTargetInfo(
					render_context.swapchain_texture,
					GpuLoadOp.clear, GpuStoreOp.store,
				);
				render_context.begin([color_target_info])
					.bind(graphics_pipeline)
					.bind([GpuTextureSamplerBinding(texture, sampler)])
					.bind([vertex_buffer])
					.bind(index_buffer);
				foreach (entity; entity_list)
				{
					pos_mat = multiply_ltor(
						transformer_translate([0.0f, 0.0f, -80.0f]),
						transformer_translate(
						[
							cos((0.001f * timer.past) * entity[0]) * 0.9f,
							sin((0.001f * timer.past) * entity[1]) * 0.9f,
							0.0f
						]
					),
					transformer_scale([0.3f, 0.3f, 0.3f]),
					transformer_rotate_z(cast(float)(timer.past * 0.001f * entity[0])),
					);
					render_context.push_vertex(pos_mat.transpose(), 0)
						.push_fragment(
							Vector!(4)(
							cos((0.001f * timer.past) * entity[1])
							.fabs() * 0.9f,
							cos((0.001f * timer.past) * entity[2])
							.fabs() * 0.9f,
							1.0f, 1.0f), 0
						)
						.draw_indexed(ParamIndexedPrimitive(6, 1, 0, 0, 0));
				}
				render_context.end();
				return;
			}).submit();
		return;
	}
}
/+
struct FlagMultiplyUniform
{
	float r, g, b, a;
}

FlagMultiplyUniform toSDL(in Vector!(4) vector) pure nothrow @nogc @safe
{
	return FlagMultiplyUniform(vector[0], vector[1], vector[2], vector[3]);
}

struct SDL_Matrix
{
	float m11, m12, m13, m14;
	float m21, m22, m23, m24;
	float m31, m32, m33, m34;
	float m41, m42, m43, m44;
}

SDL_Matrix toSDL(in Matrix!(4, 4) matrix)
{
	SDL_Matrix temp;
	temp.m11 = matrix[0, 0];
	temp.m12 = matrix[0, 1];
	temp.m13 = matrix[0, 2];
	temp.m14 = matrix[0, 3];
	temp.m21 = matrix[1, 0];
	temp.m22 = matrix[1, 1];
	temp.m23 = matrix[1, 2];
	temp.m24 = matrix[1, 3];
	temp.m31 = matrix[2, 0];
	temp.m32 = matrix[2, 1];
	temp.m33 = matrix[2, 2];
	temp.m34 = matrix[2, 3];
	temp.m41 = matrix[3, 0];
	temp.m42 = matrix[3, 1];
	temp.m43 = matrix[3, 2];
	temp.m44 = matrix[3, 3];
	return temp;
}
+/
