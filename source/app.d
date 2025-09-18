module myapp;

import kelp_core;
import kelp_api;
import kelp_loader;
import kelp_sdl;
import bindbc.sdl;
import std.stdio;

void main()
{
	writeln("Edit source/app.d to start your project.");

	SDL sdl;
	sdl = new SDL();
	sdl.initialize();
	sdl.getVersion().writeln();
	sdl.finalize();

	PluginLoader loader;
	loader = new PluginLoader();
	loader.load("kelp_render");
	//kelp_loader.f().writeln();
	//loader_debug_string.writeln();

	return;
}
