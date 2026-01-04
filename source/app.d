module myapp;

import kelp_core;
import kelp_sdl;
import kelp_render;
import bindbc.sdl;

import std.stdio;
import core.memory;

GPUGraphicsContext graphics_context;

float aspect = 960.0f / 540.0f;

void main()
{
	Core core;
	SDLDeviceSubsystem device;

	core = new Core();

	core.subsystem.pool.query!(EventSubsystem).register_poller(delegate Event[]() {
		return pollEvent();
	});

	core.subsystem.append(
		new SDLSubsystem(),
		new SDLDeviceSubsystem(),
		new SDLGraphicsSubsystem()
	);
	core.initialize();
	device = core.subsystem.pool.query!(SDLDeviceSubsystem)();

	graphics_context = new GPUGraphicsContext();
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
	GPUGraphicsContext graphics_context;

	GPURenderContext render_context;
	GPUGraphicsPipeline graphics_pipeline;
	GPUVertexBuffer vertex_buffer;
	GPUIndexBuffer index_buffer;
	GPUTexture texture;
	GPUSampler sampler;
	Surface image;

	float[3][100] entity_list;

	this(Core core, GPUGraphicsContext graphics_context)
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
		scope GPUVertexShader vertex_shader;
		scope GPUFragmentShader fragment_shader;
		vertex_shader = graphics_context.create_vertex_shader();
		fragment_shader = graphics_context.create_fragment_shader();
		vertex_shader.create("TexturedQuadWithMatrix.vert", GPUShaderArguments(0, 1, 0, 0));
		fragment_shader.create("TexturedQuadWithMultiplyColor.frag", GPUShaderArguments(1, 1, 0, 0));
		// Pipeline
		scope GPUGraphicsPipelineCreateInfo pipeline_create_info;
		pipeline_create_info.vertex_shader = vertex_shader.handle;
		pipeline_create_info.fragment_shader = fragment_shader.handle;
		with (pipeline_create_info)
		{
			vertex_input_state = GPUVertexInputState(
				[
				GPUVertexBufferDescription(
					0,
					PositionTextureVertex.sizeof,
					GPUVertexInputRate.vertex,
					0
				)
			],
			[
				GPUVertexAttribute(
					0, 0, GPUVertexElementFormat.float3, 0
				),
				GPUVertexAttribute(
					1, 0, GPUVertexElementFormat.float2, float.sizeof * 3
				)
			]
			);
			primitive_type = SDL_GPU_PRIMITIVETYPE_TRIANGLELIST;
			target_info = GPUGraphicsPipelineTargetInfo(
				[
				GPUColorTargetDescription(
					graphics_context.get_swapchain_texture_format(),
					GPUColorTargetBlendState(
						GPUBlendFactor.src_alpha,
						GPUBlendFactor.one_minus_src_alpha,
						GPUBlendOp.add,
						GPUBlendFactor.src_alpha,
						GPUBlendFactor.one_minus_src_alpha,
						GPUBlendOp.add,
						cast(GPUColorComponentFlags) SDL_GPUColorComponentFlags.init,
						true,
				)
				)
			]
			);
		}
		graphics_pipeline = graphics_context.create_graphics_pipeline();
		graphics_pipeline.create(pipeline_create_info);

		// Vertex Buffer
		PositionTextureVertex[] vertex_data = [
			{-0.5f, -0.5f, 0.0f, 0.0f, 0.0f,},
			{+0.5f, -0.5f, 0.0f, 1.0f, 0.0f,},
			{+0.5f, +0.5f, 0.0f, 1.0f, 1.0f,},
			{-0.5f, +0.5f, 0.0f, 0.0f, 1.0f,},
		];

		vertex_buffer = graphics_context.create_vertex_buffer();
		vertex_buffer.create(PositionTextureVertex.sizeof * 4);

		// index buffer
		index_buffer = graphics_context.create_index_buffer();
		ushort[] index_data = [0, 1, 2, 0, 2, 3];
		index_buffer.create(index_data);

		// texture
		image = new Surface();
		image.load("./image/dot4.png");
		texture = graphics_context.create_texture();
		texture.create(GPUTextureCreateInfo(
				GPUTextureType._2d, GPUTextureFormat.r8g8b8a8_unorm,
				GPUTextureUsageFlags.sampler,
				image.width, image.height,
				1, 1,
		));

		// sampler
		sampler = graphics_context.create_sampler();
		sampler.create(GPUSamplerCreateInfo(
				GPUFilter.nearest,
				GPUFilter.nearest,
				GPUSamplerMipmapMode.nearest,
				GPUSamplerAddressMode.clamp_to_edge,
				GPUSamplerAddressMode.clamp_to_edge,
				GPUSamplerAddressMode.clamp_to_edge,
		));

		// upload
		scope GPUBufferTransferBuffer buffer_transfer_buffer;
		buffer_transfer_buffer = new GPUBufferTransferBuffer(graphics_context.device);
		buffer_transfer_buffer.create(vertex_buffer.size + index_buffer.size)
			.map()
			.set(vertex_data, index_data)
			.unmap();

		scope GPUTextureTransferBuffer texture_transfer_buffer;
		texture_transfer_buffer = new GPUTextureTransferBuffer(graphics_context.device);
		texture_transfer_buffer.create(image.size)
			.map()
			.set(image)
			.unmap();

		scope GPUUploadContext upload_context;
		upload_context = graphics_context.create_upload_context();
		upload_context.begin()
			.upload(
				GPUTransferBufferLocation(buffer_transfer_buffer, 0),
				GPUBufferRegion(vertex_buffer, 0u)
			)
			.upload(
				GPUTransferBufferLocation(buffer_transfer_buffer, vertex_buffer.size),
				GPUBufferRegion(index_buffer, 0u)
			)
			.upload(
				GPUTextureTransferInfo(texture_transfer_buffer, 0),
				GPUTextureRegion(texture.handle, 0, 0, 0, 0, 0, image.width, image.height, 1)
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

		GPUColorTargetInfo color_target_info;
		Matrix!(4, 4) pos_mat;

		render_context.acquire_buffer()
			.acquire_texture()
			.if_acquired(() {
				color_target_info = GPUColorTargetInfo(
					render_context.swapchain_texture,
					GPULoadOp.clear, GPUStoreOp.store,
				);
				render_context.begin([color_target_info])
					.bind(graphics_pipeline)
					.bind([GPUTextureSamplerBinding(texture, sampler)])
					.bind([vertex_buffer])
					.bind(index_buffer);
				foreach (entity; entity_list)
				{
					pos_mat = matrix_scale([0.1f, 0.1f, 0.1f]) * matrix_scale([1.0f / aspect, 1.0f, 1.0f]) * matrix_translate(
						[
						cos((0.001f * timer.past) * entity[0])*0.9f,
						sin((0.001f * timer.past) * entity[1])*0.9f,
						sin((0.001f * timer.past) * entity[2])*0.9f
					]);
					/+pos_mat = matrix_scale([0.1f, 0.1f, 0.1f]) * matrix_scale([1.0f / aspect, 1.0f, 1.0f]) * matrix_translate([
						cos(entity[0]),
						sin(entity[1]),
						0.0f
					]);+/
					render_context.push_vertex(pos_mat.toSDL(), 0)
						.push_fragment(
							Vector!(4)(1.0f, 1.0f, 1.0f, 1.0f)
							.toSDL(), 0
						)
						.draw_indexed(ParamIndexedPrimitive(6, 1, 0, 0, 0));
				}
				render_context.end();
				return;
			}).submit();
		return;
	}
}

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
