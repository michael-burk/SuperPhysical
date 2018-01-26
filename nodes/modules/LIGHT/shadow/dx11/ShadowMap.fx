//@author: vux
//@help: standard constant shader
//@tags: color
//@credits: 
Texture2D inputTexture <string uiname="Alpha Tex";>;

static float2 exponents = float2(.01,.1);

struct vsInput
{
    float4 posObject : POSITION;
};

struct psInput
{
    float4 posScreen : SV_Position;
	float4 posObject : POSITION;

};

struct vsInput_AT
{
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
	psInput output;
	output.posObject = mul(input.posObject,tW);
	output.posScreen = mul(input.posObject,mul(tW,tVP));
	return output;
}

psInput_AT VS_AT(vsInput_AT input)
{
	psInput_AT output;
	output.posObject = mul(input.posObject,tW);
	output.posScreen = mul(input.posObject,mul(tW,tVP));
	output.uv = mul(input.uv, tTex);
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



