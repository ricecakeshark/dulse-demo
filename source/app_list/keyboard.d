module app_list.keyboard;

import app_list.app_interface;
import kelp_core;
import kelp_sdl;
import kelp_gfx;
import bindbc.sdl;

import std.stdio;

/+
 class KeyboardApp : AppInterface
{
	Core core;
	DeviceSubsystem device;
	TimerSubsystem timer;
	GfxGraphicsContext graphics_context;

	GfxRenderContext render_context;
	GfxGeometry[] geometry_list;
	GpuGraphicsPipeline graphics_pipeline;
	GpuVertexBuffer vertex_buffer;
	GpuIndexBuffer index_buffer;
	GpuTexture texture;
	GpuSampler sampler;

	Surface image;

	AudioDevice audio_device;
	AudioStream audio_stream;
	AudioPulse audio_pulse;
	AudioMixer audio_mixer;
	AudioFragment pulse_buffer;

	float[3][100] entity_list;

	this(Core core, GfxGraphicsContext graphics_context)
	{
		this.core = core;
		this.graphics_context = graphics_context;
		return;
	}

	override void initialize()
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
		graphics_context.create(graphics_pipeline, vertex_shader, fragment_shader);
		vertex_shader.create(
			ShaderFile("texture.vert", graphics_context.get_shader_format()), //ShaderFile("TexturedQuad.vert", graphics_context.get_shader_format()),
			GpuShaderArguments(0, 2, 0, 0),
		);
		fragment_shader.create(
			ShaderFile("texture.frag", graphics_context.get_shader_format()), //ShaderFile("TexturedQuad.frag", graphics_context.get_shader_format()),
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
					vertex_buffer_description!(float[3], float[2])
				],
				vertex_attributes!(float[3], float[2])(0),
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
		graphics_pipeline.create(pipeline_create_info);

		// Geometry
		geometry.vertex = [
			/+VertexPT(Vec3(-0.5f, -0.5f, 0.0f), Vec2(0.0f, 0.0f,),),
			VertexPT(Vec3(+0.5f, -0.5f, 0.0f,), Vec2(1.0f, 0.0f,),),
			VertexPT(Vec3(0.5f, +0.5f, 0.0f,), Vec2(1.0f, 1.0f,),),
			VertexPT(Vec3(-0.5f, +0.5f, 0.0f,), Vec2(0.0f, 1.0f,),),+/
		];
		geometry.index = [0, 1, 2, 0, 2, 3];
		// Buffer
		graphics_context.create(vertex_buffer,index_buffer)
		vertex_buffer.create(geometry.count_vertex,geometry.stride_vertex);
		index_buffer.create(geometry.count_index, GpuIndexElementSize._32bit);

		// texture, sampler
		graphics_context.create(texture, sampler);
		image = new Surface();
		image.load("./image/dot4.png");
		
		texture.create(GpuTextureCreateInfo(
				GpuTextureType._2d, GpuTextureFormat.r8g8b8a8_unorm,
				GpuTextureUsageFlags.sampler,
				image.width, image.height,
				1, 1,
		));
		sampler.create(GpuSamplerCreateInfo(
				GpuFilter.nearest,
				GpuFilter.nearest,
				GpuSamplerMipmapMode.nearest,
				GpuSamplerAddressMode.clamp_to_edge,
				GpuSamplerAddressMode.clamp_to_edge,
				GpuSamplerAddressMode.clamp_to_edge,
		));

		// upload
		scope GfxUploadContext upload_context;
		scope GpuBufferTransferBuffer buffer_transfer_buffer;
		scope GpuTextureTransferBuffer texture_transfer_buffer;
		graphics_context.create(upload_context, buffer_transfer_buffer, texture_transfer_buffer);
		buffer_transfer_buffer.create(geometry.bytes)
			.map()
			.set(geometry.vertex, geometry.offset_vertex)
			.set(geometry.index, geometry.offset_index)
			.unmap();
		texture_transfer_buffer.create(image.size)
			.map()
			.set(image)
			.unmap();
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

		// audio
		audio_device = new AudioDevice();
		audio_device.open();
		//enforce(audio_device.last_result == true);
		audio_stream = new AudioStream();
		audio_stream.create(
			SdlAudioSpec(SdlAudioFormat.f32le, 1, 48_000),
			SdlAudioSpec(SdlAudioFormat.f32le, 2, 48_000),
		);
		writeln(audio_device.name);
		audio_device.bind([audio_stream]);

		audio_pulse = new AudioPulse(440.0, 48_000);
		audio_mixer = new AudioMixer();
		audio_mixer.register(audio_pulse);

		writeln(audio_stream.queued);
		writeln(audio_stream.device_id);
		writeln("gain:", audio_stream.gain, ",", audio_device.gain);

		graphics_context.create(render_context);
		core.subsystem.query(timer, device);
		return;
	}

	override void finalize()
	{
		graphics_context.release_all();
		return;
	}

	float x = 0.0f;
	float y = 0.0f;
	float z = 0.0f;

	override void process()
	{
		// audio
		float temp_hz = 440.0f;
		audio_stream.if_queueable(() {
			if (
				device.keyboard.released(Scancode.num_1) &&
			device.keyboard.released(Scancode.num_2) &&
			device.keyboard.released(Scancode.num_3) &&
			device.keyboard.released(Scancode.num_4) &&
			device.keyboard.released(Scancode.num_5)
				)
			{
				return;
			}
			if (device.keyboard.pressed(Scancode.num_1))
			{
				temp_hz = 440.0f * pitch(-7, 0);
			}
			if (device.keyboard.pressed(Scancode.num_2))
			{
				temp_hz = 440.0f * pitch(-5, 0);
			}
			if (device.keyboard.pressed(Scancode.num_3))
			{
				temp_hz = 440.0f * pitch(-3, 0);
			}
			if (device.keyboard.pressed(Scancode.num_4))
			{
				temp_hz = 440.0f * pitch(-1, 0);
			}
			if (device.keyboard.pressed(Scancode.num_5))
			{
				temp_hz = 440.0f * pitch(0, 0);
			}
			audio_pulse.frequency_ratio = temp_hz;
			audio_pulse.gain = 0.1f;
			audio_mixer.write_back(pulse_buffer);
			audio_stream.put(pulse_buffer);
		});
		return;
	}

	override void draw()
	{
		import std.math;

		GpuColorTargetInfo color_target_info;
		Matrix!(4, 4) view_mat, pos_mat;

		view_mat = multiply_ltor(
			transformer_look_at(Vec3(0f, 0f, -20f), Vec3(0f, 0f, 0f), Vec3(0f, 1f, 0f)), //transformer_ortho_wh(960f,540f),
			transformer_perspective(PI_2),
		);

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
						transformer_scale([10.0f, 10.0f, 10.0f]),
						transformer_rotate_z(timer.past * 0.002f * entity[0]),
						transformer_translate([
							cos((0.0012f * timer.past) * entity[0]) * 10.0f,
							sin((0.0013f * timer.past) * entity[1]) * 10.0f,
							cos((0.0015f * timer.past) * entity[0]) * 10.0f
						]),
					);
					render_context.push_vertex(view_mat, 0)
						.push_vertex(pos_mat, 1)
						.push_fragment(
							Vector!(4)(
							cos((0.001f * timer.past) * entity[1])
							.fabs() * 0.9f,
							cos((0.001f * timer.past) * entity[2])
							.fabs() * 0.9f,
							1.0f, 1.0f),
							0,
						)
						.draw_indexed(ParamIndexedPrimitive(6, 1, 0, 0, 0));
				}
				render_context.end();
				return;
			}).submit();
		return;
	}

	override int opCmp(Object other) const
	{
		return 0;
	}
}
+/
