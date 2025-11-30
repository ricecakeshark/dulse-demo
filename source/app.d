module myapp;

import kelp_core;
import kelp_sdl;
import kelp_render;
import bindbc.sdl;

import std.stdio;
import core.memory;

void main()
{
	auto core = new Kelp();
	core.initialize();
	core.subsystem.query!(EventSubsystem)[0].register_poller(delegate Event[]() {
		return pollEvent();
	});

	core.subsystem.append(
		new SDLSubsystem(),
		new SDLDeviceSubsystem(),
		new SDLGraphicsSubsystem()
	);

	auto app = new TestApp(core);
	app.initialize();

	while (core.continuable)
	{
		core.process();
		app.process();
	}
	app.finalize();
	core.finalize();

	return;
}

class TestApp
{
	SDLDeviceSubsystem device;

	GPUWindow gpu_window;
	GPUDevice gpu_device;

	GPURenderContext render_context;
	GPUUploadContext upload_context;

	GPUGraphicsPipeline graphics_pipeline;
	GPUVertexBuffer cube_vertex_buffer;

	this(Kelp core)
	{
		device = core.subsystem.query!(SDLDeviceSubsystem)()[0];
		return;
	}

	void initialize()
	{
		GPUVertexShader vertex_shader;
		GPUFragmentShader fragment_shader;

		gpu_window = new GPUWindow();
		gpu_window.create(960, 540, "like a sdl_gpu_example");
		gpu_device = new GPUDevice();
		gpu_device.create();
		gpu_device.claim(gpu_window);

		// Shader
		vertex_shader = new GPUVertexShader(gpu_device);
		fragment_shader = new GPUFragmentShader(gpu_device);
		vertex_shader.create("PositionColor.vert", GPUShaderArguments(0, 0, 0, 0));
		fragment_shader.create("SolidColor.frag", GPUShaderArguments(0, 0, 0, 0));

		// Pipeline
		GPUGraphicsPipelineCreateInfo pipeline_create_info = {
			vertex_shader: vertex_shader.handle,
			fragment_shader: fragment_shader.handle,
			vertex_input_state: GPUVertexInputState(
				[
				GPUVertexBufferDescription(
					0,
					PositionColorVertex.sizeof,
					SDL_GPU_VERTEXINPUTRATE_VERTEX,
					0,
				)
			].ptr, 1,
			[
				GPUVertexAttribute(
					0, 0, SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3, 0,
				),
				GPUVertexAttribute(
					1, 0, SDL_GPU_VERTEXELEMENTFORMAT_UBYTE4_NORM, float.sizeof * 3
				),
			].ptr,
			2,
			),
			primitive_type: SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
			target_info: GPUGraphicsPipelineTargetInfo(
				[
				GPUColorTargetDescription(
					getSwapchainTextureFormat(gpu_device, gpu_window)
				)
			].ptr, 1,
			)};

			/+pipeline_create_info = GPUGraphicsPipelineCreateInfo(
				vertex_shader.handle,
				fragment_shader.handle,
				GPUVertexInputState(
					[
					GPUVertexBufferDescription(
						0,
						PositionColorVertex.sizeof,
						SDL_GPU_VERTEXINPUTRATE_VERTEX,
						0,
					)
				].ptr, 1,
				[
					GPUVertexAttribute(
						0, 0, SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3, 0,
					),
					GPUVertexAttribute(
						1, 0, SDL_GPU_VERTEXELEMENTFORMAT_UBYTE4_NORM, float.sizeof * 3
					),
				].ptr,
				2,
			),
			SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
			target_info : GPUGraphicsPipelineTargetInfo(
				[
				GPUColorTargetDescription(
					getSwapchainTextureFormat(gpu_device, gpu_window)
				)
			].ptr, 1,
			)
			);
			+/
			graphics_pipeline = new GPUGraphicsPipeline(gpu_device);
			graphics_pipeline.create(pipeline_create_info);
			destroy(vertex_shader);
			destroy(fragment_shader);

			// Vertex Buffer
			PositionColorVertex[] vertex_data = [
				{-1.0, -1.0, 0.0, 255, 0, 0, 255
		},
		{+1.0, -1.0, 0.0, 0, 255, 0, 255},
		{+0.0, +1.0, 0.0, 0, 0, 255, 255},];

		cube_vertex_buffer = new GPUVertexBuffer(gpu_device);
		cube_vertex_buffer
			.create(PositionColorVertex.sizeof * 3);
		cube_vertex_buffer.set(vertex_data);

		// upload
		auto buffer_transfer_buffer = new GPUBufferTransferBuffer(gpu_device);
		buffer_transfer_buffer.create(PositionColorVertex.sizeof * 3)
			.map()
			.set(vertex_data)
			.unmap();

		upload_context = new GPUUploadContext(gpu_device);
		upload_context.begin()
			.upload(
				GPUTransferBufferLocation(buffer_transfer_buffer, 0),
				GPUBufferRegion(cube_vertex_buffer.handle, 0, PositionColorVertex.sizeof * 3)
			)
			.end()
			.submit();
		destroy(buffer_transfer_buffer);
		destroy(upload_context);

		render_context = new GPURenderContext(gpu_device, gpu_window);
		return;
	}

	void finalize()
	{
		destroy(graphics_pipeline);
		destroy(cube_vertex_buffer);
		GC.collect();

		destroy(gpu_device);
		destroy(gpu_window);
		GC.collect();
		return;
	}

	void process()
	{
		if (device.keyboard.pressed_just(Scancode.escape))
		{
			writeln("pressed ESC");
		}

		GPUColorTargetInfo color_target_info;
		render_context.acquire();
		with (color_target_info)
		{
			texture = render_context.swapchain_texture.handle;
			clear_color = SDL_FColor(0.0, 0.1, 0.2, 1.0);
			load_op = SDL_GPU_LOADOP_CLEAR;
			store_op = SDL_GPU_STOREOP_STORE;
		}
		render_context.begin([color_target_info])
			.render(delegate void() {
				render_context.render_pass.bind(graphics_pipeline)
					.bind([cube_vertex_buffer]);
				render_context.render_pass.draw(3, 1, 0, 0);
				return;
			})
			.end().submit();
		return;
	}
}
