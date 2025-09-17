module myapp;

import kelp_core, kelp_api;
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
	return;
}
