//@author: vux
//@help: template for standard shaders
//@tags: template
//@credits: 

float4x4 tVI:VIEWINVERSE;
#include "LightRaymarcher.fxh"

float4x4 tVP : VIEWPROJECTION;	
float4x4 tW : WORLD;

struct VS_IN
{
	float4 pos : POSITION;
	float4 uv : TEXCOORD0;

};

struct VS_OUT
{
    float4 pos: SV_POSITION;
    float4 uv: TEXCOORD0;
};

VS_OUT VS(VS_IN input)
{
    VS_OUT output;
    output.pos  = mul(input.pos,tW);
    output.uv= input.uv;
    return output;
}



struct PS_OUT
{
	float4 color : SV_Target0;
	float depth : SV_Depth;
};


PS_OUT PS(VS_OUT input)
{
    PS_OUT Out;
	
	float3 ro = tVI[3].xyz;
	float3 rd = UVtoEYE(input.uv.xy);
	
	float d = raymarch (ro, rd, 128);
	float3 p = ro + d * rd;
	
	float3 normal = calcNormal(p);
	
	float fog = 1/(1 + d * d *0.25);

	float4 col = 0;
	col.rgb =  1-sceneSDF(p);

	
	float4 pos = mul (float4 (p.xyz,1),tVP);
	
	if (abs(sceneSDF(p)) > .01) discard;
	
	Out.color = col* 2;
	Out.depth = pos.z/pos.w;
	
    return Out;
}





technique10 Constant
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetPixelShader( CompileShader( ps_4_0, PS() ) );
	}
}




