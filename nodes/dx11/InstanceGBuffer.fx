#ifndef SBUFFER_FXH
#include <packs\happy.fxh\sbuffer.fxh>
#endif

struct gBuffer{
	
	float4 pos : SV_Target0;
	float4 norm : SV_Target1;
	float2 uv : SV_Target2;
	
};

struct vsInput
{
	//uint ii : SV_InstanceID;
	uint vid : SV_VertexID;
    float4 posObject : POSITION;
	float3 norm : NORMAL;
	float2 uv: TEXCOORD0;
};

struct psInput
{
	uint iid : IID;
    float4 posScreen : SV_Position;
	float4 posW : POSW;
	float3 norm : NORMAL;
	float2 uv: TEXCOORD0;
};


cbuffer cbPerObj : register( b1 )
{
//	uint materialID;
//	uint IntanceStartIndex = 0;
	float4x4 tVP : LAYERVIEWPROJECTION;
	float4x4 tWI : WORLDINVERSE;
	float4x4 tW : WORLD;
	float4x4 tV : VIEW;
	float4x4 tP : PROJECTION;
};

StructuredBuffer<float> iidBuffer;
float4x4  transformDefualt;
StructuredBuffer<float4x4> transformBuffer;
float4x4 transformTexDefault <string uiname="Texture Transform Defualt"; bool uvspace=true; >;
StructuredBuffer<float4x4> transformTexBuffer <string uiname="Texture Transform Buffer"; bool uvspace=true; >;;


float materialIDDefault;

StructuredBuffer<float> materialIDBuffer;




psInput VS(vsInput input)
{
	/*Here we look up for local world transform using
	the object instance id and start offset*/
	uint iid = iidBuffer[input.vid];
	float4x4 wo = sbLoad(transformBuffer, transformDefualt, iid);
	
	/* the WORLD transform applies to the 
	whole batch in case of instancing, so we can transform 
	all the batch at once using it */
	//wo = mul(world[input.ii + IntanceStartIndex],tW);
		
	psInput output;
	output.posW = mul(input.posObject, wo);
	output.posScreen = mul(input.posObject,mul(wo,tVP));
	output.norm = normalize( mul(mul(input.norm, (float3x3)wo), (float3x3)transpose(tWI)) );
	output.uv = mul(float4(input.uv, 0 ,1), sbLoad(transformTexBuffer, transformTexDefault,  iid)).xy;
	output.iid = iid;
	return output;
}

gBuffer PS(psInput input)

{
	gBuffer output;
	output.pos = input.posW;
	output.norm = float4(input.norm, sbLoad(materialIDBuffer, materialIDDefault, input.iid) * 0.001);
	output.uv = input.uv;
	return output;
}

technique11 GBuffer
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_5_0, VS() ) );
		SetPixelShader( CompileShader( ps_5_0, PS() ) );
	}
}





