module app_list.particle.pipeline.particle;

import dulse_sdl;
import dulse_gfx;

GfxGraphicsContext create_pipeline_particle(
	ref GfxGraphicsContext graphics_context,
	out GpuGraphicsPipeline particle_pipeline
)
{
	scope GpuVertexShader vertex_shader;
	scope GpuFragmentShader fragment_shader;
	graphics_context.create(particle_pipeline, vertex_shader, fragment_shader);
	vertex_shader.create(
		ShaderFile("particle.vert", graphics_context.get_shader_format()),
		GpuShaderArguments(0, 2, 0, 0),
	);
	fragment_shader.create(
		ShaderFile("particle.frag", graphics_context.get_shader_format()),
		GpuShaderArguments(0, 0, 0, 0),
	);
	// Defer Pipeline
	scope GpuGraphicsPipelineCreateInfo particle_pipeline_info;
	particle_pipeline_info.vertex_shader = vertex_shader.handle;
	particle_pipeline_info.fragment_shader = fragment_shader.handle;
	with (particle_pipeline_info)
	{
		primitive_type = GpuPrimitiveType.point_list;
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
			true, false, false,
		);
		target_info = GpuGraphicsPipelineTargetInfo(
			[
			GpuColorTargetDescription(
				GpuTextureFormat.r16g16b16a16_float,
				GpuColorTargetBlendState(
					GpuBlendFactor.src_alpha,
					GpuBlendFactor.one_minus_src_alpha,
					GpuBlendOp.add,
					GpuBlendFactor.one,
					GpuBlendFactor.one_minus_src_alpha,
					GpuBlendOp.add,
					cast(GpuColorComponentFlags) 0xF,
					true,
			),
			), 
		], GpuTextureFormat.d32_float,
		);
	}
	particle_pipeline.create(particle_pipeline_info);
	return graphics_context;
}
