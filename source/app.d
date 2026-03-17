module myapp;

import app_list;
import kelp_core;
import kelp_sdl;
import kelp_gfx;
import std.stdio;

float aspect = 960.0f / 540.0f;

void main()
{
	Core core;
	DeviceSubsystem device;
	TimerSubsystem timer;
	GfxGraphicsContext graphics_context;
	AppInterface[] app_list;
	LoopedInt!(4) app_index, app_index_next;

	core = new Core();
	core.append_sdl_subsystem()
		.initialize();
	core.subsystem.query(device, timer);

	graphics_context = new GfxGraphicsContext();
	graphics_context.initialize(GpuBackend.vulkan);

	app_list = [
		cast(AppInterface) new ManyObject(core, graphics_context),
		new ShaderTest(core, graphics_context),
		cast(AppInterface) new TextApp(core, graphics_context),
		new ComputeDemo(core, graphics_context),
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
			timer.sleep(100);
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
