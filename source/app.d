module myapp;

import app_list;
import kelp_core;
import kelp_sdl;
import kelp_gfx;

//import std.stdio;
import std.conv : text;
import std.stdio;
import core.memory : GC;

void main()
{
	scope Core core;
	scope GfxGraphicsSubsystem graphics;
	scope TimerSubsystem timer;
	scope LoggerSubsystem logger;
	scope GfxInputSubsystem input;
	scope AppInterface[] app_list;
	scope LoopedInt!(6) app_index, app_index_next;

	import std.process;

	auto pid = spawnProcess(
		["../build_shader/build/shader_builder.exe", "--verbose"],
		stdin, stdout, stderr,
	);
	wait(pid);

	core = new Core();
	core.append_gio_subsystem();
	core.initialize();
	core.subsystem.query(timer, graphics, logger, input);
	graphics.context.initialize(1920, 1080, "D-lang app with SDL3 GPU_API (Vulkan backend)", GpuBackend
			.vulkan);

	app_list = [
		cast(AppInterface) new ManyObject(core),
		//new CubeForward(core),
		new CubeDeferDemo(core),
		new TextApp(core),
		new ComputeDemo(core),
		new GuageDemo(core),
		//new KeyboardApp(core, graphics_context),
	];
	app_list[app_index].initialize();

	while (core.continuable)
	{
		core.process();

		if (input.keyboard.pressed_just(Scancode.escape))
		{
			writeln("pressed ESC");
			core.bus.send(new QuitMessage());
		}

		if (input.keyboard.pressed_just(Scancode.left))
		{
			app_index_next = app_index - 1;
		}

		if (input.keyboard.pressed_just(Scancode.right))
		{
			app_index_next = app_index + 1;
		}
		
		if (app_index_next != app_index)
		{
			app_list[app_index].finalize();
			timer.sleep(100);
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
