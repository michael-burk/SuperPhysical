//@author: vux
//@help: standard constant shader
//@tags: color
//@credits: 


#define Instancing = true;
#define Deferred = true;

struct gBuffer{
	
	float4 pos : COLOR0;
	float4 norm : COLOR1;
	float4 uv : COLOR2;
	
};

struct vsInput
{
	uint ii : SV_InstanceID;
    float4 posObject : POSITION;
	float3 norm : NORMAL;
	float4 uv: TEXCOORD0;
};

struct psInput
{
	uint ii : SV_InstanceID;
    float4 posScreen : SV_Position;
	float4 posW : POSW;
	float3 norm : NORMAL;
	float4 uv: TEXCOORD0;
};


cbuffer cbPerObj : register( b1 )
{
//	uint materialID;
	uint IntanceStartIndex = 0;
	float4x4 tVP : LAYERVIEWPROJECTION;
	float4x4 tWI : WORLDINVERSE;
	float4x4 tW : WORLD;
	float4x4 tV : VIEW;
	float4x4 tP : PROJECTION;
	float4x4 tVI : VIEWINVERSE;
};

SamplerState g_samLinear
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = WRAP;
    AddressV = WRAP;
};

StructuredBuffer<float4x4> world;
StructuredBuffer<uint> materialID;


Texture2DArray normalTex <string uiname="NormalMap"; >;
Texture2DArray heightMap <string uiname="HeightMap"; >;


cbuffer cbTextureData : register(b2)
{
	float4x4 tTex <string uiname="Texture Transform"; bool uvspace=true; >;
};

struct MaterialStruct
{
	
	float 	fHeightMapScale;
	float 	POMnumSamples;
	float 	POM;
	float	bumpy;
	
	row_major float4x4	tTex;
	row_major float4x4	tTexInv;
	
	#ifdef doControlTextures
	
	float	sampleNormal;
	float	sampleHeight;
	float	pad0;
	float	pad1;
	
	#endif
	
};

StructuredBuffer <MaterialStruct> Material_NormalMapping  <string uiname="Material";>;

#include "ParallaxOcclusionMapping.fxh"

psInput VS(vsInput input)
{
	/*Here we look up for local world transform using
	the object instance id and start offset*/
	float4x4 wo = world[input.ii + IntanceStartIndex];
	
	/* the WORLD transform applies to the 
	whole batch in case of instancing, so we can transform 
	all the batch at once using it */
	wo = mul(world[input.ii + IntanceStartIndex],tW);
		
	psInput output;
	output.posW = mul(input.posObject, wo);
	output.posScreen = mul(input.posObject,mul(wo,tVP));
	output.norm = normalize( mul(mul(input.norm, (float3x3)wo), (float3x3)transpose(tWI)) );
	output.uv = input.uv;
	output.ii = input.ii;
	return output;
}

gBuffer PS(psInput input): SV_Target

{
	gBuffer output;
	
	uint texID = materialID[input.ii + IntanceStartIndex];
	
	input.uv = mul(input.uv,Material_NormalMapping[texID].tTex);
	
	float3 N = input.norm;
	
	#ifdef doControlTextures
	
		
		float3 V = normalize(tVI[3].xyz - input.posW.xyz);
	
		
		// compute derivations of the world position
		float3 p_dx = ddx(input.posW.xyz);
		float3 p_dy = ddy(input.posW.xyz);
		// compute derivations of the texture coordinate
		float2 tc_dx = ddx(input.uv.xy);
		float2 tc_dy = ddy(input.uv.xy);
				
		// compute initial tangent and bi-tangent
		float3 t = normalize( (tc_dy.y * p_dx - tc_dx.y * p_dy));
		float3 b = normalize( (tc_dy.x * p_dx - tc_dx.x * p_dy)); // sign inversion
			
		// get new tangent from a given mesh normal
		float3 x = cross(N, t);
		t = cross(x, N);
		t = normalize(t);
		// get updated bi-tangent
		x = cross(b, N);
		b = cross(N, x);
		b = normalize(b);
		
		if(Material_NormalMapping[texID].POM){
			parallaxOcclusionMapping(input.uv.xy, input.posW.xyz, V, float3x3(t,b,N), texID, input.ii + IntanceStartIndex);
		}
			float3 bumpMap = float3(.5,.5,1);
			if(Material_NormalMapping[texID].sampleNormal) bumpMap = normalTex.Sample(g_samLinear,float3(input.uv.xy, texID)).rgb;
			if(length(bumpMap) > 0) bumpMap = (bumpMap * 2.0f) - 1.0f;
			N = normalize(N + (bumpMap.x * (t) + bumpMap.y * (b)) * Material_NormalMapping[texID].bumpy);
			
		
	#endif
	
	output.pos = input.posW;
	output.norm = float4(N,(float) materialID[input.ii + IntanceStartIndex] * 0.001);
	output.uv = mul(input.uv, Material_NormalMapping[texID].tTexInv);	
	
	return output;
}

technique11 GBuffer
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetPixelShader( CompileShader( ps_5_0, PS() ) );
	}
}





