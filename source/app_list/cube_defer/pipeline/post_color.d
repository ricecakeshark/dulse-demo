module app_list.cube_defer.pipeline.post_color;

import kelp_sdl;
import kelp_gfx;

GfxGraphicsContext create_pipeline_post_color(
	ref GfxGraphicsContext graphics_context,
	out GpuComputePipeline post_color_pipeline,
)
{
	graphics_context.create(post_color_pipeline);
	//GpuComputePipelineCreateInfo pipeline_create_info;
	auto pipeline_create_info = GpuComputePipelineCreateInfo(
		ShaderFile("post_color.comp", GpuShaderFormat.spirv)
	);
	with (pipeline_create_info)
	{
		//num_readonly_storage_buffers = 0;
		num_samplers = 1;
		num_readwrite_storage_textures = 1;
		num_uniform_buffers = 3;
		threadcount_x = 8;
		threadcount_y = 8;
		threadcount_z = 1;
	}
	post_color_pipeline.create(
		pipeline_create_info
	);
	return graphics_context;
}
