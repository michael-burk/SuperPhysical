//@author: Johannes Schmidt || Kopffarben GbR
//@help: LightHelper
//@tags: forwardPlus
//@credits: Jeremiah van Oosten

#ifndef FORWARDPLUS_FXH
#include "forwardplus.fxh"
#endif

StructuredBuffer<Light_FWP> Lights : LIGHTS;
SamplerState g_samLinear : IMMUTABLE
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
};


cbuffer cbPerDraw : register( b0 )
{
	float4x4 tVP : LAYERVIEWPROJECTION;
	float4x4 tVI : VIEWINVERSE;
	float4x4 tW : WORLD;
	float alpha;
};


struct VS_IN
{
	uint ii : SV_InstanceID;
	float4 PosO : POSITION;
	float2 TexCd : TEXCOORD0;

};

struct vs2ps
{
    float4 PosWVP: SV_POSITION;	
	float4 Color: TEXCOORD0;
    float2 TexCd: TEXCOORD1;
	
};

vs2ps VS(VS_IN input)
{
    //inititalize all fields of output struct with 0
    vs2ps Out = (vs2ps)0;
	
	Light_FWP light = Lights[input.ii];
	
	float4 Pos = float4(mul(input.PosO.xyz,(float3x3)tVI),1);
	
	Pos = (Pos * float4(light.range,light.range,light.range,1) * float4(2,2,2,1) ) + light.position; 
    Out.PosWVP  = mul(Pos ,mul(tW,tVP));
	Out.Color = light.color;
	Out.Color.w *= alpha;
    Out.TexCd = input.TexCd;
    return Out;
}




float4 PS_Tex(vs2ps In): SV_Target
{
     
    return In.Color;
}





technique10 Constant
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetPixelShader( CompileShader( ps_4_0, PS_Tex() ) );
	}
}




