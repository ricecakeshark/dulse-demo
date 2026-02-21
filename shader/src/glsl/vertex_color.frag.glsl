#version 450

// input
layout(location = 0) in VS_Out
{
	vec4 color;
} ps_in;

layout(location = 0) out vec4 draw_color;


void main()
{
	draw_color = ps_in.color;
	return;
}
