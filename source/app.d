module myapp;

import app_list;
import kelp_core;
import kelp_sdl;
import kelp_render;
import bindbc.sdl;

import std.math;
import std.stdio;
import core.memory;
import std.sumtype;

GfxGraphicsContext graphics_context;

float aspect = 960.0f / 540.0f;

void main()
{
	Core core;
	DeviceSubsystem device;
	AppInterface[] app_list;
	LoopedInt!(2) app_index, app_index_next;

	core = new Core();
	core.subsystem.append(
		new SDLSubsystem(core),
		new SDLDeviceSubsystem(core),
		new SDLEventSubsystem(core),
		new AudioSubsystem(),
	);
	core.initialize();
	device = core.subsystem.pool.query!(DeviceSubsystem)();

	graphics_context = new GfxGraphicsContext();
	graphics_context.initialize(GpuBackend.vulkan);

	//alias App = SumType!(TestApp,ShaderTest);
	//VariantPool!(App) app_list;

	app_list = [
		cast(AppInterface) new TestApp(core, graphics_context),
		cast(AppInterface) new ShaderTest(core, graphics_context),
	];
	app_list[app_index].initialize();

	AudioDevice audio_device;
	AudioStream audio_stream;
	import std.exception : enforce;

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

	auto audio_pulse = new AudioPulse(440.0,48_000);
	auto audio_mixer = new AudioMixer();
	audio_mixer.register(audio_pulse);
	float[] pulse_buffer;

	immutable int sample_rate = 48_000;
	immutable int minimum_queue = cast(int)((sample_rate * float.sizeof) *0.05);

	writeln(audio_stream.queued);
	writeln(audio_stream.device_id);
	writeln("gain:", audio_stream.gain, ",", audio_device.gain);

	while (core.continuable)
	{
		core.process();

		// audio
		if (audio_stream.queued < minimum_queue)
		{
			audio_mixer.write_back(pulse_buffer);
			audio_stream.put(pulse_buffer);
		}

		if (device.keyboard.pressed_just(Scancode.escape))
		{
			writeln("pressed ESC");
			break;
		}
		if (device.keyboard.pressed_just(Scancode.left))
		{
			app_index_next = app_index - 1;
		}
		if (device.keyboard.pressed_just(Scancode.right))
		{
			app_index_next = app_index + 1;
		}
		if (app_index_next != app_index)
		{
			writefln("finalize : %s", app_index);
			app_list[app_index].finalize();
			core.subsystem.pool.query!(TimerSubsystem)().sleep(100);
			writefln("initialize : %s", app_index_next);
			app_list[app_index_next].initialize();
			app_index = app_index_next;
		}
		app_list[app_index].process();
		app_list[app_index].draw();
	}
	app_list[app_index].finalize();
	core.finalize();

	return;
}
