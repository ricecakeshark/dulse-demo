module app_list.cube_defer.pipeline.shade_compose_debug;

import kelp_sdl;
import kelp_gfx;

GfxGraphicsContext create_pipeline_compose_debug(
	ref GfxGraphicsContext graphics_context,
	out GpuComputePipeline compose_pipeline,
)
{
	graphics_context.create(compose_pipeline);
	//GpuComputePipelineCreateInfo pipeline_create_info;
	auto pipeline_create_info = GpuComputePipelineCreateInfo(
		ShaderFile("shade_compose.comp", GpuShaderFormat.spirv)
	);
	with (pipeline_create_info)
	{
		//num_readonly_storage_buffers = 0;
		num_samplers = 7;
		num_readwrite_storage_textures = 1;
		num_uniform_buffers = 1;
		threadcount_x = 8;
		threadcount_y = 8;
		threadcount_z = 1;
	}
	compose_pipeline.create(
		pipeline_create_info
	);
	return graphics_context;
}
