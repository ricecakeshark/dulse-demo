module myapp;

// common kelp
import kelp_core;
import kelp_api;
import kelp_loader;

// kelp interface
import kelp_sdl;
import kelp_render;

// normal import
import bindbc.sdl;
import std.stdio;

void main()
{
	writeln("Edit source/app.d to start your project.");

	SDL sdl;
	sdl = new SDL();
	sdl.initialize();
	sdl.getVersion().writeln();

	Graphics graphics;
	graphics = new Graphics();
	graphics.initialize();
	foreach (count; 0 .. (60 * 5))
	{
		graphics.process();
		SDL_Delay(16);
	}
	graphics.finalize();

	sdl.finalize();
	return;
}
