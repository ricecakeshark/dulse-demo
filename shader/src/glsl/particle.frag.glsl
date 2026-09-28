#version 460
#extension GL_EXT_scalar_block_layout : enable
// in
//layout(location = 0) in vec3 in_pos;
// out
layout(location = 0) out vec4 draw_color;

void main()
{
	/*
	const vec2 point = gl_PointCoord * 2.0 - 1.0;
	if(dot(point,point) > 1.0)
		discard;
		draw_color = vec4(1.0, 0.0, 1.0, 1.0);
	*/
	const float r = length(gl_PointCoord * 2.0 - 1.0);
	const float alpha = 1.0 - smoothstep(0.0, 1.0, r);
	draw_color = vec4(1.0, 1.0, 1.0, alpha);
	//draw_color = vec4(1.0, 0.0, 0.0, 0.2);
	return;
}