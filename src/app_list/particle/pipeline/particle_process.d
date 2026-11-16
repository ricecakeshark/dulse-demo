module app_list.particle.pipeline.particle_process;

import dulse_sdl;
import dulse_gfx;

GraphicsContext create_pipeline_particle_process(
	ref GraphicsContext gc,
	out ComputePipeline pipeline
)
{
		gc.create(pipeline);
		auto compute_pipeline_info = GfxComputePipelineCreateInfo(
			ShaderFile("particle_process.comp", GpuShaderFormat.spirv)
		);
		with (compute_pipeline_info)
		{
			num_readonly_storage_buffers = 0;
			num_samplers = 0;
			num_readwrite_storage_textures = 0;
			num_readwrite_storage_buffers = 1;
			num_uniform_buffers = 0;
			threadcount_x = 8;
			threadcount_y = 8;
			threadcount_z = 1;
		}
		pipeline
			.bind(compute_pipeline_info)
			.create();
	return gc;
}
