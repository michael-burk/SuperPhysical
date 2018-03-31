//@author: mburk
//@help: internet
//@tags: shading
//@credits: Vux, Dottore, Catweasel

static const float MAX_REFLECTION_LOD = 9.0;

float2 R : Targetsize;


static const float3 F = float3(0.04,0.04,0.04);	

cbuffer cbPerObject : register (b0)
{	
	//transforms
	float4x4 tW: WORLD;
	float4x4 tWI: WORLDINVERSE;
	float4x4 tWVP: WORLDVIEWPROJECTION;
	
	float4 GlobalReflectionColor <bool color = true; string uiname="Global Reflection Color";>  = { 0.0f,0.0f,0.0f,0.0f };
	float4 GlobalDiffuseColor <bool color = true; string uiname="Global Diffuse Color";>  = { 0.0f,0.0f,0.0f,0.0f };
	
	float4 Color <bool color = true; string uiname="Color(Albedo)";>  = { 1.0f,1.0f,1.0f,1.0f };
	float4 Emissive <bool color = true; string uiname="Color(Emissive)";>  = { 0.0f,0.0f,0.0f,0.0f };
	float Alpha <float uimin=0.0; float uimax=1.0;> = 1;
	float lPower <String uiname="Power"; float uimin=0.0;> = 1.0;     //shininess of specular highlight

	bool refraction <String uiname="Refraction";> = false;
	bool useIridescence = false;	

	float4x4 tTex <bool uvspace=true;>;
	float4x4 tTexInv <bool uvspace=true;>;
	
	float2 iblIntensity <String uiname="IBL Intensity";> = float2(1,1);	
	
	float bumpy <string uiname="Bumpiness"; float uimin=0.0; float uimax=1.0;> = 0 ;
	bool pom <string uiname="Parallax Occlusion Mapping";> = false;
	float metallic <float uimin=0.0; float uimax=1.0;>;
	float roughness <float uimin=0.0; float uimax=1.0;>;
	
	float sss = 0;
	float sssFalloff = 0;
	bool noTile = false;
	uint num;
};

cbuffer cbPerRender : register (b1)
{	
	float4x4 tVI : VIEWINVERSE;
}

Texture2D texture2d <string uiname="Texture"; >;
Texture2D EmissiveTex <string uiname="Emissive"; >;
Texture2D normalTex <string uiname="NormalMap"; >;
Texture2D heightMap <string uiname="HeightMap"; >;
Texture2D roughTex <string uiname="RoughnessMap"; >;
Texture2D metallTex <string uiname="MetallicMap"; >;
Texture2D aoTex <string uiname="AOMap"; >;
Texture2D iridescence <string uiname="Iridescence"; >;

StructuredBuffer <float> refractionIndex <String uiname="Refraction Index";>;

TextureCube cubeTexRefl <string uiname="CubeMap Refl"; >;
TextureCube cubeTexIrradiance <string uiname="CubeMap Irradiance"; >;
Texture2D brdfLUT <string uiname="brdfLUT"; >;

Texture2DArray lightMap <string uiname="SpotTex"; >;
Texture2DArray shadowMap <string uiname="ShadowMap"; >;


SamplerState g_samLinear
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = WRAP;
    AddressV = WRAP;
};

struct vs2ps
{
    float4 PosWVP: SV_POSITION;
    float4 TexCd : TEXCOORD0;
	float4 PosW: TEXCOORD1;
	float3 NormW : TEXCOORD2;
	float3 V: TEXCOORD3;
};

struct vs2psBump
{
    float4 PosWVP: SV_POSITION;
    float4 TexCd : TEXCOORD0;
	float4 PosW: TEXCOORD1;
	float3 NormW : TEXCOORD2;
	float3 tangent : TEXCOORD3;
	float3 binormal : TEXCOORD4;
};

vs2psBump VS_Bump(
    float4 PosO: POSITION,
    float3 NormO: NORMAL,
    float4 TexCd : TEXCOORD0,
	float3 tangent : TANGENT,
    float3 binormal : BINORMAL
)
{
    //inititalize all fields of output struct with 0
    vs2psBump Out = (vs2psBump)0;
    Out.PosW = mul(PosO, tW);	
	Out.NormW = mul(NormO, (float3x3)transpose(tWI));
	Out.NormW = normalize(Out.NormW);
	// Calculate the tangent vector against the world matrix only and then normalize the final value.
    Out.tangent = mul(tangent, (float3x3)tW);
    Out.tangent = normalize(Out.tangent);
    // Calculate the binormal vector against the world matrix only and then normalize the final value.
    Out.binormal = mul(binormal, (float3x3)tW);
    Out.binormal = normalize(Out.binormal);
    Out.PosWVP  = mul(PosO, tWVP);
	Out.TexCd = mul(TexCd,tTex);
    return Out;
}

vs2ps VS(
    float4 PosO: POSITION,
    float3 NormO: NORMAL,
    float4 TexCd : TEXCOORD0

)
{
    //inititalize all fields of output struct with 0
    vs2ps Out = (vs2ps)0;
	
    Out.PosW = mul(PosO, tW);
	Out.NormW = mul(NormO, (float3x3)transpose(tWI));
	Out.NormW = normalize(Out.NormW);
    Out.PosWVP  = mul(PosO, tWVP);
	Out.TexCd = mul(TexCd,tTex);
    return Out;
}



float4 PS_PBR(vs2ps In): SV_Target
{	
	return doLighting(In.PosW, normalize(In.NormW), In.TexCd);
}

float4 PS_PBR_Bump(vs2psBump In): SV_Target
{	
	#ifdef doPOM
	if(pom){
		parallaxOcclusionMapping(In.TexCd.xy, In.PosW.xyz, normalize(tVI[3].xyz - In.PosW.xyz), float3x3(In.tangent,In.binormal,In.NormW.xyz));
	}
	#endif
	
	float3 bumpMap = float3(0,0,0);
	
	uint tX2,tY2,m2;
	normalTex.GetDimensions(tX2,tY2);
	if(tX2+tY2 > 4 && !noTile) bumpMap = normalTex.Sample(g_samLinear, In.TexCd.xy).rgb;
	else if(tX2+tY2 > 4 && noTile) bumpMap = textureNoTile(normalTex, In.TexCd.xy).rgb;
	if(length(bumpMap) > 0) bumpMap = (bumpMap * 2.0f) - 1.0f;
	
	float3 Nb = normalize(In.NormW.xyz + (bumpMap.x * In.tangent + bumpMap.y * In.binormal)*bumpy);
	return doLighting(In.PosW, Nb, In.TexCd);

}

float4 PS_PBR_Bump_AutoTNB(vs2ps In): SV_Target
{	
	
	// compute derivations of the world position
	float3 p_dx = ddx(In.PosW.xyz);
	float3 p_dy = ddy(In.PosW.xyz);
	// compute derivations of the texture coordinate
	float2 tc_dx = ddx(In.TexCd.xy);
	float2 tc_dy = ddy(In.TexCd.xy);
	// compute initial tangent and bi-tangent
	float3 t = normalize( tc_dy.y * p_dx - tc_dx.y * p_dy );
	float3 b = normalize( tc_dy.x * p_dx - tc_dx.x * p_dy ); // sign inversion
	// get new tangent from a given mesh normal
	float3 n = normalize(In.NormW);
	float3 x = cross(n, t);
	t = cross(x, n);
	t = normalize(t);
	// get updated bi-tangent
	x = cross(b, n);
	b = cross(n, x);
	b = normalize(b);
	
	#ifdef doPOM
	if(pom){
		parallaxOcclusionMapping(In.TexCd.xy, In.PosW.xyz, normalize(tVI[3].xyz - In.PosW.xyz), float3x3(t,b,In.NormW.xyz));
	}
	#endif
	
	float3 bumpMap = float3(0,0,0);

	uint tX2,tY2,m2;
	normalTex.GetDimensions(tX2,tY2);
	if(tX2+tY2 > 4 && !noTile) bumpMap = normalTex.Sample(g_samLinear,In.TexCd.xy).rgb;
	else if(tX2+tY2 > 4 && noTile) bumpMap = textureNoTile(normalTex,In.TexCd.xy).rgb;
	if(length(bumpMap) > 0) bumpMap = (bumpMap * 2.0f) - 1.0f;
	
	float3 Nb = normalize(In.NormW.xyz + (bumpMap.x * (t) + bumpMap.y * (b))*bumpy);
	
	return doLighting(In.PosW, Nb, In.TexCd);
}


technique10 PBR
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetPixelShader( CompileShader( ps_5_0, PS_PBR() ) );
	}
}

technique10 PBR_Bump
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS_Bump() ) );
		SetPixelShader( CompileShader( ps_5_0, PS_PBR_Bump() ) );
	}
}

technique10 PBR_Bump_AutoTNB
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetPixelShader( CompileShader( ps_5_0, PS_PBR_Bump_AutoTNB() ) );
	}
}


