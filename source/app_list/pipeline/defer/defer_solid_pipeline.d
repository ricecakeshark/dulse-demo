module app_list.pipeline.defer.defer_solid_pipeline;

import kelp_sdl;
import kelp_gfx;

GfxGraphicsContext create_pipeline_defer_solid(
	ref GfxGraphicsContext graphics_context,
	out GpuGraphicsPipeline defer_pipeline
)
{
	scope GpuVertexShader vertex_shader;
	scope GpuFragmentShader fragment_shader;
	graphics_context.create(defer_pipeline, vertex_shader, fragment_shader);
	vertex_shader.create(
		ShaderFile("defer_solid.vert", graphics_context.get_shader_format()),
		GpuShaderArguments(0, 3, 0, 0),
	);
	fragment_shader.create(
		ShaderFile("defer_solid.frag", graphics_context.get_shader_format()),
		GpuShaderArguments(0, 4, 0, 0),
	);
	// Defer Pipeline
	scope GpuGraphicsPipelineCreateInfo defer_pipeline_info;
	defer_pipeline_info.vertex_shader = vertex_shader.handle;
	defer_pipeline_info.fragment_shader = fragment_shader.handle;
	with (defer_pipeline_info)
	{
		vertex_input_state = GpuVertexInputState(
			[
				vertex_buffer_description!(float[3], float[3], float[4])
			],
			vertex_attributes!(float[3], float[3], float[4])(0),
		);
		primitive_type = GpuPrimitiveType.triangle_list;
		rasterizer_state = GpuRasterizerState(
			GpuFillMode.fill,
			GpuCullMode.back,
			GpuFrontFace.counter_clockwise,
		);
		depth_stencil_state = GpuDepthStencilState(
			GpuCompareOp.less,
			GpuStencilOpState.init,
			GpuStencilOpState.init,
			0u, 0u,
			true, true, false,
		);
		target_info = GpuGraphicsPipelineTargetInfo(
			[
			GpuColorTargetDescription(
				GpuTextureFormat.r8g8b8a8_unorm
			), GpuColorTargetDescription(
				GpuTextureFormat.r16g16b16a16_float
			), GpuColorTargetDescription(
				GpuTextureFormat.r16g16b16a16_float
			), GpuColorTargetDescription(
				GpuTextureFormat.r32g32_int
			),
		], GpuTextureFormat.d32_float,
		);
	}
	defer_pipeline.create(defer_pipeline_info);
	return graphics_context;
}
