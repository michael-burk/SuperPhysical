//@author: vux
//@help: standard constant shader
//@tags: color
//@credits: 
Texture2D inputTexture <string uiname="Alpha Tex";>;

static float2 exponents = float2(.01,.1);

StructuredBuffer<float4x4> world;

StructuredBuffer<float> iidb;

struct vsInput
{
//	uint ii : SV_InstanceID;
	uint vid : SV_VertexID ;
    float4 posObject : POSITION;
};

struct psInput
{
    float4 posScreen : SV_Position;
	float4 posObject : POSITION;

};

struct vsInput_AT
{
	uint vid : SV_VertexID ;
    float4 posObject : POSITION;
	float4 uv: TEXCOORD0;
};

struct psInput_AT
{
    float4 posScreen : SV_Position;
	float4 posObject : POSITION;
	float4 uv: TEXCOORD0;
};

SamplerState linearSampler <string uiname="Sampler State";>
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
};

cbuffer cbPerDraw : register(b0)
{
	float4x4 tVP : VIEWPROJECTION;
};

cbuffer cbPerObj : register( b1 )
{	
	float4x4 tW : WORLD;
	float4x4 tV : VIEW;
	float4x4 tP : PROJECTION;
	float3 lightPos;
	float lightDist;
	float depthOffset = 0.0001;
	int shadowType;
	
};

cbuffer cbTextureData : register(b2)
{
	float4x4 tTex <string uiname="Texture Transform"; bool uvspace=true; >;
};


psInput VS(vsInput input)
{
	uint ii = iidb[input.vid];
	
	/*Here we look up for local world transform using
	the object instance id and start offset*/
	float4x4 wo = world[ii];
	
	/* the WORLD transform applies to the 
	whole batch in case of instancing, so we can transform 
	all the batch at once using it */
	wo = mul(wo,tW);
	
	float4x4 wv = mul(wo,tV);
	
	psInput output;
	output.posObject = mul(input.posObject,wo);
	output.posScreen = mul(input.posObject,mul(wo,tVP));
	return output;
}



float4 PS(psInput input): SV_Target
{	

		if(shadowType == 0 || shadowType == 1){
				//VSM
			    float4 col = 0;
	
				float worldSpaceDistance = distance(lightPos, input.posObject.xyz);
				float dist = (worldSpaceDistance - 0) /
			              (lightDist - 0) + depthOffset;
				
//				float alpha = inputTexture.Sample(linearSampler,input.uv.xy).a;
			
				col.r = dist;
				col.g = col.r * col.r;
//				col.a = pow(max(alpha,0),.25);
				
			    return col;
			
		}
		
		else if(shadowType == 2){
				//ESM
				float worldSpaceDistance = distance(lightPos, input.posObject.xyz);
				float dist = (worldSpaceDistance - 0) /
       			(lightDist - 0) + depthOffset;

   				return exp(30 * dist);
			
		}
		
		else return 0;
	

}


technique11 VSM
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_5_0, VS() ) );
		SetPixelShader( CompileShader( ps_5_0, PS() ) );
	}
}



