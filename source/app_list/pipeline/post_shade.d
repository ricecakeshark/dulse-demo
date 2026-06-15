module app_list.pipeline.post_shade;

import kelp_sdl;
import kelp_gfx;

void create_pipeline_shade(
	ref GfxGraphicsContext graphics_context,
	out GpuComputePipeline shade_pipeline,
)
{
	graphics_context.create(shade_pipeline);
	//GpuComputePipelineCreateInfo pipeline_create_info;
	auto pipeline_create_info = GpuComputePipelineCreateInfo(
		ShaderFile("post_shade.comp", GpuShaderFormat.spirv)
	);
	with (pipeline_create_info)
	{
		//num_readonly_storage_buffers = 0;
		num_samplers = 5;
		num_readwrite_storage_textures = 1;
		num_uniform_buffers = 1;
		threadcount_x = 8;
		threadcount_y = 8;
		threadcount_z = 1;
	}
	shade_pipeline.create(
		pipeline_create_info
	);
	return;
}
