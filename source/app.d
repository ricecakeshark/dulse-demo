module myapp;

import app_list;
import kelp_core;
import kelp_sdl;
import kelp_gfx;
import std.stdio;
import core.memory;

float aspect = 960.0f / 540.0f;

void main()
{
	Core core;
	DeviceSubsystem device;
	TimerSubsystem timer;
	GfxGraphicsContext graphics;
	AppInterface[] app_list;
	LoopedInt!(4) app_index, app_index_next;

	core = new Core();
	core.append_sdl_subsystem()
		.initialize();
	core.subsystem.query(device, timer);

	graphics = new GfxGraphicsContext();
	graphics.initialize(960, 540, GpuBackend.vulkan);

	app_list = [
		cast(AppInterface) new ManyObject(core, graphics),
		cast(AppInterface) new CubeDemo(core, graphics),
		//new ShaderTest(core, graphics_context),
		new TextApp(core, graphics),
		new ComputeDemo(core, graphics),
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
	graphics.finalize();
	core.finalize();

	return;
}
