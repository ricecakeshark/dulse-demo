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
	LoopedInt!(3) app_index, app_index_next;

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

	app_list = [
		cast(AppInterface) new ManyObject(core, graphics_context),
		//new ShaderTest(core, graphics_context),
		cast(AppInterface) new TextApp(core, graphics_context),
		//new KeyboardApp(core, graphics_context),
	];
	app_list[app_index].initialize();

	while (core.continuable)
	{
		core.process();

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
