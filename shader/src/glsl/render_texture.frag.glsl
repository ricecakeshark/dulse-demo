#version 460
#extension GL_EXT_scalar_block_layout : enable

const float LIGHT_ATTENUATION = 0.9f;
const int MAX_LIGHT_POINT = 32;
// in
layout(location = 0) in vec2 in_uv;
layout(location = 1) in vec3 in_normal;
layout(location = 2) in vec3 in_world_pos;
// out
layout(location = 0) out vec4 draw_color;
// sampling texture
layout(set = 2, binding = 0) uniform sampler2D albedo_texture;
layout(set = 2, binding = 0) uniform sampler2D normal_texture;
//layout(set = 2, binding = 0) uniform sampler2D material_texture;


struct LightPoint
{
	vec3 pos;
	vec3 color;
	float intensity;
};
// Scene (storage buffer)
layout(set = 2, binding = 1) readonly buffer Scene
{
	LightPoint[4] light_point;
	uint count_light_point;
} scene_ssbo;

// uniform buffer
layout(std430, set = 3, binding = 0) uniform Scene
{
	//float light_attenuation;
	vec4 light_ambient;
} scene;
// View
layout(std430, set = 3, binding = 1) uniform View
{
	//mat4 mat;
	vec3 vec;
} view;
// Model
layout(std430, set = 3, binding = 2) uniform Model
{
	float specular_strength;
	float shininess;
} model;
// Light
layout(std430, set = 3, binding = 3) uniform Light
{
	//float light_attenuation;
	LightPoint[1] light_point_list;
	uint count_light_point;
} light;

void main()
{
	vec2 uv = gl_FragCoord.xy / screenSize;
	// out_albedo
	vec4 texel_color = texture(user_texture, in_uv);
	out_albedo = texel_color;
	// out_normal
	vec3 normal_world = normalize(in_normal);
	out_normal = normal_world;

	
	/*
	vec3 vec_light = normalize(light.light_point_list[0].pos - in_world_pos);
	vec3 vec_view = normalize(view.vec - in_world_pos);
	vec3 vec_reflect = reflect(-vec_light, normal_world);
	*/

	/*
	// ambient
	vec3 ambient = scene.light_ambient.rgb * scene.light_ambient.a;
	// diffuse
	float diff = max(dot(normal_world, vec_light), 0.0);
	vec3 diffuse = light.light_point_list[0].color * light.light_point_list[0].intensity * diff;
	// specular
	float spec = 0.0;
	if(diff > 0.0){
		spec = pow(max(dot(vec_view, vec_reflect), 0.0), model.shininess);
	}
	vec3 specular = light.light_point_list[0].color 
		* light.light_point_list[0].intensity * model.specular_strength * spec;
	*/
	//draw_color = vec4((ambient + diffuse) * texel_color.rgb + specular, texel_color.a);

	return;
}
