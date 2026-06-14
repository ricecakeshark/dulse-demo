module app_list.pipeline.post_edge;

import kelp_sdl;
import kelp_gfx;

void create_post_edge_pipeline(
	ref GfxGraphicsContext graphics_context,
	out GpuComputePipeline post_edge_pipeline,
)
{
	graphics_context.create(post_edge_pipeline);
	//GpuComputePipelineCreateInfo pipeline_create_info;
	auto pipeline_create_info = GpuComputePipelineCreateInfo(
		ShaderFile("post_edge.comp", GpuShaderFormat.spirv)
	);
	with (pipeline_create_info)
	{
		//num_readonly_storage_buffers = 0;
		num_samplers = 5;
		num_readwrite_storage_textures = 1;
		num_uniform_buffers = 4;
		threadcount_x = 8;
		threadcount_y = 8;
		threadcount_z = 1;
	}
	post_edge_pipeline.create(
		pipeline_create_info
	);
	return;
}
