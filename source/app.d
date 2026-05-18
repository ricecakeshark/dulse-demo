module myapp;

import app_list;
import kelp_core;
import kelp_sdl;
import kelp_gfx;
import std.stdio;
import core.memory;

void main()
{
	scope Core core;
	scope GfxGraphicsSubsystem graphics;
	scope DeviceSubsystem device;
	scope TimerSubsystem timer;
	//scope GfxGraphicsContext graphics;
	scope AppInterface[] app_list;
	scope LoopedInt!(5) app_index, app_index_next;

	
	core = new Core();
	core.append_sdl_subsystem();
	core.subsystem.append(new GfxGraphicsSubsystem(core));
	core.initialize();
	core.subsystem.query(device, timer, graphics);
	graphics.context.initialize(960, 540, GpuBackend.vulkan);

	app_list = [
		cast(AppInterface) new ManyObject(core),
		cast(AppInterface) new CubeDemo(core),
		//new ShaderTest(core, graphics_context),
		new TextApp(core),
		new ComputeDemo(core),
		new GuageDemo(core),
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
	graphics.context.finalize();
	core.finalize();
	GC.collect();
	writeln(GC.profileStats);
	return;
}
