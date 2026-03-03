#version 450

// input
layout(location = 0) in VS_Out
{
	vec4 color;
} ps_in;
// out
layout(location = 0) out vec4 draw_color;
// uniform buffer
layout(set = 3, binding = 0) uniform CBuffer
{
	vec4 color_1;
} cb;

void main()
{
	draw_color = ps_in.color;
	return;
}
