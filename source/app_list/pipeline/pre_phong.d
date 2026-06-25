module app_list.pipeline.pre_phong;

import kelp_sdl;
import kelp_gfx;

GfxGraphicsContext create_pipeline_phong(
	ref GfxGraphicsContext graphics_context,
	out GpuComputePipeline pipeline,
)
{
	graphics_context.create(pipeline);
	auto pipeline_create_info = GpuComputePipelineCreateInfo(
		ShaderFile("pre_phong.comp", GpuShaderFormat.spirv)
	);
	with (pipeline_create_info)
	{
		//num_readonly_storage_buffers = 0;
		num_samplers = 4;
		num_readwrite_storage_textures = 1;
		num_uniform_buffers = 3;
		threadcount_x = 8;
		threadcount_y = 8;
		threadcount_z = 1;
	}
	pipeline.create(
		pipeline_create_info
	);
	return graphics_context;
}
