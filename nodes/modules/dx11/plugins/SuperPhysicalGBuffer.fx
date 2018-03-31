//@author: vux
//@help: standard constant shader
//@tags: color
//@credits: 

uint materialID;

struct gBuffer{
	
	float4 pos : COLOR0;
	float4 norm : COLOR1;
	float4 uv : COLOR2;
	
};

struct vsInput
{
    float4 posObject : POSITION;
	float3 norm : NORMAL;
	float4 uv: TEXCOORD0;
};

struct psInput
{
    float4 posScreen : SV_Position;
	float4 posW : POSW;
	float3 norm : NORMAL;
	float4 uv: TEXCOORD0;
};


cbuffer cbPerDraw : register(b0)
{
	float4x4 tVP : LAYERVIEWPROJECTION;
	float4x4 tWI : WORLDINVERSE;
};

cbuffer cbPerObj : register( b1 )
{
	float4x4 tW : WORLD;
};

cbuffer cbTextureData : register(b2)
{
	float4x4 tTex <string uiname="Texture Transform"; bool uvspace=true; >;
};

psInput VS(vsInput input)
{
	psInput output;
	output.posW = mul(input.posObject, tW);
	output.posScreen = mul(input.posObject,mul(tW,tVP));
	output.norm = normalize( mul(input.norm, (float3x3)transpose(tWI)) );
	output.uv = input.uv;
	return output;
}



gBuffer PS(psInput input): SV_Target

{
	gBuffer output;
	
	output.pos = input.posW;
	output.norm = float4(input.norm,(float) materialID * 0.001);
	output.uv = input.uv;
	
	return output;

}



technique11 GBuffer
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetPixelShader( CompileShader( ps_4_0, PS() ) );
	}
}





