module app_list.pipeline.post_render;

import kelp_sdl;
import kelp_gfx;

void create_post_render_pipeline(
	ref GfxGraphicsContext graphics_context,
	out GpuComputePipeline post_shade_pipeline,
)
{
	graphics_context.create(post_shade_pipeline);
	//GpuComputePipelineCreateInfo pipeline_create_info;
	auto pipeline_create_info = GpuComputePipelineCreateInfo(
		ShaderFile("post_render.comp", GpuShaderFormat.spirv)
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
	post_shade_pipeline.create(
		pipeline_create_info
	);
	return;
}
