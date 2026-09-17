module myapp;

import app_list;
import dulse;
import dulse_sdl;
import dulse_gfx;

import std.conv : text;
import std.stdio;
import core.memory : GC;

void main()
{
	scope Core core;
	scope GraphicsSubsystem graphics;
	scope TimerSubsystem timer;
	scope LoggerSubsystem logger;
	scope InputSubsystem input;
	scope MixerSubsystem mixer;
	scope AppInterface[] app_list;
	scope LoopedInt!(6) app_index, app_index_next;

	import std.process;

	auto pid = spawnProcess(
		["../build_shader/build/shader_builder.exe", "--verbose"],
		stdin, stdout, stderr,
	);
	wait(pid);

	core = new Core();
	core.subsystem.append!(GfxSubsystemList)();
	core.initialize();
	core.subsystem.query(timer, graphics, logger, input, mixer);
	graphics.context.initialize(1920, 1080, "Dulse-demo with SDL3 GPU_API (Vulkan backend)", GpuBackend
			.vulkan);

	Track bgm_track;
	Audio bgm_1;
	mixer.create(bgm_track, bgm_1);
	bgm_1.load("./bgm/sunnyday.mp3");
	bgm_track.set(bgm_1).play();

	app_list = [
		cast(AppInterface) new CubeDeferDemo(core),
		new TextApp(core),
		//new ComputeDemo(core),
		//new GuageDemo(core),
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
