// Per-View: (Projective, Viewport) 
cbuffer view : register(b0, space1)
{
	row_major matrix<float,4,4> view_mat;
	//float4x4 view_mat;
}
// Per-Object: (Model, View, Projection)
cbuffer model : register(b1, space1)
{
	row_major matrix<float,4,4> model_mat;
	//float4x4 model_mat;
}

struct Input
{
	float3 position : TEXCOORD0;
	float4 color : TEXCOORD1;
};

struct Output
{
	float4 color : TEXCOORD0;
	float4 position : SV_Position;
};

Output main(Input input)
{
	Output output;
	output.color = input.color;
	output.position = mul(float4(input.position, 1.0f), mul(model_mat, view_mat));
	return output;
}
