module app_list.pipeline.post_fog;

import kelp_sdl;
import kelp_gfx;

GfxGraphicsContext create_pipeline_post_fog(
	ref GfxGraphicsContext graphics_context,
	out GpuComputePipeline post_fog_pipeline,
)
{
	graphics_context.create(post_fog_pipeline);
	//GpuComputePipelineCreateInfo pipeline_create_info;
	auto pipeline_create_info = GpuComputePipelineCreateInfo(
		ShaderFile("post_fog.comp", GpuShaderFormat.spirv)
	);
	with (pipeline_create_info)
	{
		//num_readonly_storage_buffers = 0;
		num_samplers = 2;
		num_readwrite_storage_textures = 1;
		num_uniform_buffers = 2;
		threadcount_x = 8;
		threadcount_y = 8;
		threadcount_z = 1;
	}
	post_fog_pipeline.create(
		pipeline_create_info
	);
	return graphics_context;
}
