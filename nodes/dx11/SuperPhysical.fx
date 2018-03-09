//@author: mburk
//@help: internet
//@tags: shading
//@credits: Vux, Dottore, Catweasel

static const float MAX_REFLECTION_LOD = 9.0;

float2 R : Targetsize;

struct LightStruct
{
	float4   Color;
    float4   lPos;
	
    float    lightRange;
    float    lAtt0;
    float    lAtt1;
    float    lightType;
	
    float 	 useShadow;
	float 	 shadowType;
	float 	 lightBleedingLimit;
	float 	 lightSize;
	
	float 	 penumbraScale;
	float 	 numShadowSamples;
	float 	 pad0;
	float 	 pad1;
};

struct LightMatricesStruct
{
	row_major 	float4x4 VP;
	row_major	float4x4 V;
	row_major	float4x4 P;
};


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
//	bool gammaCorrection = true;
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

StructuredBuffer <LightStruct> Light  <string uiname="Light Parameter Buffer";>;
StructuredBuffer <LightMatricesStruct> LightMatrices  <string uiname="Light Matrices Buffer";>;

SamplerState g_samLinear
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = WRAP;
    AddressV = WRAP;
};

#include "ShadowMapping.fxh"
#include "NoTile.fxh"
#include "ParallaxOcclusionMapping.fxh"
#include "CookTorrance.fxh"
#include "IBL.fxh"
//#include "dx11/ToneMapping.fxh"

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

float4 doLighting(float4 PosW, float3 N, float4 TexCd){
	
	///////////////////////////////////////////////////////////////////////////
	// INITIALIZE GLOBAL VARIABLES
	///////////////////////////////////////////////////////////////////////////
	
	float3 V = normalize(tVI[3].xyz - PosW.xyz);

	float3 LightDirW;
	float4 viewPosition;
	float4 projectTexCoord;
	float3 projectionColor;
	float2 reflectTexCoord;
	float4 finalLight = float4(0.0,0.0,0.0,0.0);
	
	uint tX,tY,m;
	float4 texCol = float4(1,1,1,1);
	float texRoughness = 1;
	float aoT = 1;
	float metallicT = 1;
	
	///////////////////////////////////////////////////////////////////////////
	// INITIALIZE PBR PRAMETERS WITH TEXTURE LOOKUP
	///////////////////////////////////////////////////////////////////////////
	
	roughTex.GetDimensions(tX,tY);
	if(tX+tY > 4 && !noTile) texRoughness = roughTex.Sample(g_samLinear, TexCd.xy).r;
	else if(tX+tY > 4 && noTile) texRoughness = textureNoTile(roughTex,TexCd.xy).r;
	texRoughness *= roughness;
	texRoughness = min(max(texRoughness,.01),.95);
//	texRoughness += .05;
	
	aoTex.GetDimensions(tX,tY);
	if(tX+tY > 4 && !noTile) aoT = aoTex.Sample(g_samLinear, TexCd.xy).r;
	else if(tX+tY > 4 && noTile) aoT = textureNoTile(aoTex,TexCd.xy).r;
	
	metallTex.GetDimensions(tX,tY);
	if(tX+tY > 4 && !noTile) metallicT = metallTex.Sample(g_samLinear, TexCd.xy).r;
	else if(tX+tY > 4 && noTile) metallicT = textureNoTile(metallTex, TexCd.xy).r;
	metallicT *= metallic;
	
	texture2d.GetDimensions(tX,tY);
	if(tX+tY > 4 && !noTile) texCol = texture2d.Sample(g_samLinear, TexCd.xy);
	else if(tX+tY > 4 && noTile) texCol = textureNoTile(texture2d,TexCd.xy);
	float4 albedo = texCol * saturate(Color) * aoT;
	
	
	///////////////////////////////////////////////////////////////////////////
	// INITIALIZE PBR PRAMETERS WITH TEXTURE LOOKUP
	///////////////////////////////////////////////////////////////////////////
	
	float3 iridescenceColor = 1;
	
	if (useIridescence){
		float inverseDotView = 1.0 - max(dot(N,V),0.0);
		iridescenceColor = iridescence.Sample(g_samLinear, float2(inverseDotView,0)).rgb;
	} 	
		
	
	float3 F0 = lerp(F, albedo.xyz, metallicT);
	
	int shadowCounter = 0;
	int spotLightCount = 0;
	int lightCounter = 0;
	float4 shadow = 0;
	float3 lightToObject;
	float3 L;
	float lightDist;
	float falloff;
	
//	uint a;
//	float b,c;
//	shadowMap.GetDimensions(a,b,c);
//	float2 shadowTexSize = float2(b,c);
	
	for(uint i = 0; i< num; i++){

		lightToObject = Light[i].lPos.xyz - PosW.xyz;
		L = normalize(lightToObject);
		lightDist = length(lightToObject);
		
		falloff = smoothstep(0,Light[i].lAtt1,(Light[i%num].lightRange-lightDist));
			
		switch (Light[i].lightType){
			
			
		//DIRECTIONAL
			case 0:
				shadow = 0;
			
				if(Light[i].useShadow){
				viewPosition = mul(PosW, LightMatrices[i].VP);
				
				projectTexCoord.x =  viewPosition.x / viewPosition.w / 2.0f + 0.5f;
		   		projectTexCoord.y = -viewPosition.y / viewPosition.w / 2.0f + 0.5f;			
				projectTexCoord.z = viewPosition.z / viewPosition.w / 2.0f + 0.5f;
			
				if((saturate(projectTexCoord.x) == projectTexCoord.x) && (saturate(projectTexCoord.y) == projectTexCoord.y)
				&& (saturate(projectTexCoord.z) == projectTexCoord.z)){
					doShadow(shadow, Light[i].shadowType, lightDist, Light[i%num].lightRange, projectTexCoord, viewPosition, i, shadowCounter);
				} else {
					shadow = 1;
				}
					float3 LDir = float3(LightMatrices[i].V._m02,LightMatrices[i].V._m12,LightMatrices[i].V._m22);			
					shadowCounter++;
							
					finalLight.xyz += cookTorrance(V, -LDir, N, albedo.xyz, Light[i].Color.rgb,
					lerp(1.0,saturate(shadow),falloff).x, 1.0, 1, lightDist, sss, sssFalloff, F0, Light[i].lAtt0, texRoughness, metallicT, aoT, iridescenceColor);
				} else {
					float3 LDir = float3(LightMatrices[i].V._m02,LightMatrices[i].V._m12,LightMatrices[i].V._m22);	
					finalLight.xyz += cookTorrance(V, -LDir, N, albedo.xyz, Light[i].Color.rgb,
					1.0, 1.0, 1.0, lightDist, sss, sssFalloff, F0, Light[i].lAtt0, texRoughness, metallicT, aoT, iridescenceColor);
				}
				lightCounter ++;
				break;
			
			//SPOT
			case 1:
				shadow = 0;
				viewPosition = mul(PosW, LightMatrices[i].VP);
					
				projectTexCoord.x =  viewPosition.x / viewPosition.w / 2.0f + 0.5f;
		   		projectTexCoord.y = -viewPosition.y / viewPosition.w / 2.0f + 0.5f;			
				projectTexCoord.z = viewPosition.z / viewPosition.w / 2.0f + 0.5f;
			
				float3 falloffSpot = 0;
				if((saturate(projectTexCoord.x) == projectTexCoord.x) && (saturate(projectTexCoord.y) == projectTexCoord.y)
				&& (saturate(projectTexCoord.z) == projectTexCoord.z)){
					
					uint tXS,tYS,mS;
					lightMap.GetDimensions(tXS,tYS,mS);
					if(tXS+tYS > 4) falloffSpot = lightMap.Sample(g_samLinear, float3(projectTexCoord.xy, spotLightCount), 0 ).rgb;
					else if(tXS+tYS < 4) falloffSpot = smoothstep(1,0,saturate(length(.5-projectTexCoord.xy)*2));
					
					if(Light[i].useShadow) doShadow(shadow, Light[i].shadowType, lightDist, Light[i%num].lightRange, projectTexCoord, viewPosition, i, shadowCounter);
					
				} else {
					shadow = 1;
				}
				
				if(Light[i].useShadow){
						shadowCounter++;
						float attenuation = Light[i].lAtt0;
						finalLight.xyz += cookTorrance(V, L, N, albedo.xyz, Light[i].Color.rgb,
						shadow.x, falloffSpot * falloff, falloff, lightDist, sss, sssFalloff, F0, attenuation, texRoughness, metallicT, aoT, iridescenceColor);
					
				} else {
						float attenuation = Light[i].lAtt0;
						finalLight.xyz += cookTorrance(V, L, N, albedo.xyz, Light[i].Color.rgb,
						1.0, falloffSpot * falloff, falloff, lightDist, sss, sssFalloff, F0, attenuation, texRoughness, metallicT, aoT, iridescenceColor);
				}
			
				lightCounter ++;
				spotLightCount++;
				break;
	
			//POINT
			case 2:
			
				shadow = 0;
			
				if(Light[i].useShadow){
					
					for(int p = 0; p < 6; p++){
						
						float4x4 LightPcropp = LightMatrices[p + lightCounter].P;
				
						LightPcropp._m00 = 1;
						LightPcropp._m11 = 1;
						
						float4x4 LightVPNew = mul(LightMatrices[p + lightCounter].V,LightPcropp);
						
						viewPosition = mul(PosW, LightVPNew);
						
						projectTexCoord.x =  viewPosition.x / viewPosition.w / 2.0f + 0.5f;
			   			projectTexCoord.y = -viewPosition.y / viewPosition.w / 2.0f + 0.5f;
						projectTexCoord.z = viewPosition.z / viewPosition.w / 2.0f + 0.5f;
					
						if((saturate(projectTexCoord.x) == projectTexCoord.x) && (saturate(projectTexCoord.y) == projectTexCoord.y)
						&& (saturate(projectTexCoord.z) == projectTexCoord.z)){
							
							viewPosition = mul(PosW, LightMatrices[p + lightCounter].VP);
							
							projectTexCoord.x =  viewPosition.x / viewPosition.w / 2.0f + 0.5f;
				   			projectTexCoord.y = -viewPosition.y / viewPosition.w / 2.0f + 0.5f;
							projectTexCoord.z = viewPosition.z / viewPosition.w / 2.0f + 0.5f;
							
							doShadow(shadow, Light[i].shadowType, lightDist, Light[i%num].lightRange, projectTexCoord, viewPosition, i, p+shadowCounter);
							
						}
					}
							float attenuation = Light[i].lAtt0 * falloff;
							finalLight.xyz += cookTorrance(V, L, N, albedo.xyz, Light[i].Color.rgb,
							shadow.x, 1.0, falloff, lightDist, sss, sssFalloff, F0, attenuation, texRoughness, metallicT, aoT, iridescenceColor);
				
							shadowCounter += 6;
							lightCounter  += 6;
				} else {
						    float attenuation = Light[i].lAtt0 * falloff;
							finalLight.xyz += cookTorrance(V, L, N, albedo.xyz, Light[i].Color.rgb,
							1, 1, falloff, lightDist, sss, sssFalloff, F0, attenuation, texRoughness, metallicT, aoT, iridescenceColor);
			
				}	
			
			

			break;			
		}	
	}
	
	finalLight.rgb += IBL(N, V, F0, albedo, iridescenceColor, texRoughness, metallicT, aoT );
	
	EmissiveTex.GetDimensions(tX,tY);
	if(tX+tY > 4 && !noTile) finalLight.rgb += saturate(Emissive.rgb + EmissiveTex.SampleLevel(g_samLinear, TexCd.xy,0).rgb);
	else if(tX+tY > 4 && noTile) finalLight.rgb += saturate(Emissive.rgb + textureNoTile(EmissiveTex,TexCd.xy).rgb);
	else finalLight.rgb += saturate(Emissive.rgb);
	
//	Gamma Correction
//	if(gammaCorrection) finalLight.rgb = ACESFitted(finalLight.rgb);

	finalLight.a = Alpha*albedo.a;

	return finalLight;
}


float4 PS_PBR(vs2ps In): SV_Target
{	
	return doLighting(In.PosW, normalize(In.NormW), In.TexCd);
}

float4 PS_PBR_Bump(vs2psBump In): SV_Target
{	
	
	if(pom){
		parallaxOcclusionMapping(In.TexCd.xy, In.PosW.xyz, normalize(tVI[3].xyz - In.PosW.xyz), float3x3(In.tangent,In.binormal,In.NormW.xyz));
	}
	
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
	
	if(pom){
		parallaxOcclusionMapping(In.TexCd.xy, In.PosW.xyz, normalize(tVI[3].xyz - In.PosW.xyz), float3x3(t,b,In.NormW.xyz));
	}
	
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


