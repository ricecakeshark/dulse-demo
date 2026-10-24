module app_list.text.pipeline.text;

import dulse_sdl;
import dulse_gfx;

GraphicsContext create_pipeline_text(
	ref GraphicsContext graphics_context,
	out GraphicsPipeline pipeline
)
{
	scope GpuVertexShader vertex_shader;
	scope GpuFragmentShader fragment_shader;
	graphics_context.create(pipeline, vertex_shader, fragment_shader);
	vertex_shader.create(
		ShaderFile("text.vert", graphics_context.device.get_shader_format()), //ShaderFile("const_position.vert", graphics_context.device.get_shader_format()),
		GpuShaderArguments(0, 2, 0, 0),
	);
	fragment_shader.create(
		ShaderFile("text.frag", graphics_context.device.get_shader_format()),
		GpuShaderArguments(1, 1, 0, 0),
	);
	scope GfxGraphicsPipelineCreateInfo pipeline_create_info;
	pipeline_create_info.vertex_shader = vertex_shader;
	pipeline_create_info.fragment_shader = fragment_shader;
	with (pipeline_create_info)
	{
		vertex_input_state = GpuVertexInputState(
			[
				vertex_buffer_description!(float[3], float[2])
			],
			vertex_attributes!(float[3], float[2])(0),
		);
		primitive_type = GpuPrimitiveType.triangle_list;
		target_info = GraphicsPipelineTargetInfo(
			[
			GpuColorTargetDescription(
				graphics_context.get_swapchain_texture_format(),
				GpuColorTargetBlendState(
					GpuBlendFactor.src_alpha,
					GpuBlendFactor.one_minus_src_alpha,
					GpuBlendOp.add,
					GpuBlendFactor.src_alpha,
					GpuBlendFactor.one_minus_src_alpha,
					GpuBlendOp.add,
					cast(GpuColorComponentFlags) 0xF,
					true,
			)
			)
		]
		);
		rasterizer_state.cull_mode = GpuCullMode.none;
	}
	pipeline
		.bind(pipeline_create_info)
		.create();
	return graphics_context;
}
