//@author: mburk
//@help: internet
//@tags: shading
//@credits: Vux, Dottore, Catweasel

static const float MAX_REFLECTION_LOD = 9.0;

float2 R : Targetsize;

int ID : DRAWINDEX;

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
	float 	 shadowPOMSamples;
	float 	 shadowPOM;
};

struct LightMatricesStruct
{
	row_major 	float4x4 VP;
	row_major	float4x4 V;
	row_major	float4x4 P;
};

struct MaterialStruct
{
	float metallic;
	float roughness;
	
	float 	pad0;
	float 	pad1;
	float4  Color;
	float4  Emissive;
	
	row_major float4x4	tTex;
	row_major float4x4	tTexInv;
	
	float 	sssAmount;
	float 	sssFalloff;
	float 	sss;
	float 	pad2;
	
	float 	fHeightMapScale;
	float 	POMnumSamples;
	float 	POM;
	float 	pad3;
	
	float4	Refraction;
	
	float	bumpy;
	float	noTile;
	float	useTex;
	float	Iridescence;
	
	#ifdef doControlTextures
	
	float	sampleAlbedo;
	float	sampleEmissive;
	float	sampleNormal;
	float	sampleHeight;
	
	float	sampleRoughness;
	float	sampleMetallic;
	float	sampleAO;
	float	pad4;
	
	#endif
};


static const float3 F = float3(0.04,0.04,0.04);	

cbuffer cbPerObject : register (b0)
{	
	//transforms
	float4x4 tW: WORLD;
	float4x4 tWI: WORLDINVERSE;
	float4x4 tVP: VIEWPROJECTION;
	float4x4 tWVP: WORLDVIEWPROJECTION;
	
	float4 GlobalReflectionColor <bool color = true; string uiname="Global Reflection Color";>  = { 0.0f,0.0f,0.0f,0.0f };
	float4 GlobalDiffuseColor <bool color = true; string uiname="Global Diffuse Color";>  = { 0.0f,0.0f,0.0f,0.0f };
	
	float Alpha <float uimin=0.0; float uimax=1.0;> = 1;
	float lPower <String uiname="Power"; float uimin=0.0;> = 1.0;     //shininess of specular highlight

	float2 iblIntensity <String uiname="IBL Intensity";> = float2(1,1);	
	
	uint mCount <String uiname="Material Count";> ;
	
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

StructuredBuffer <bool> useTex;

TextureCube cubeTexRefl <string uiname="CubeMap Refl"; >;
TextureCube cubeTexIrradiance <string uiname="CubeMap Irradiance"; >;
Texture2D brdfLUT <string uiname="brdfLUT"; >;

Texture2DArray lightMap <string uiname="SpotTex"; >;
Texture2DArray shadowMap <string uiname="ShadowMap"; >;

StructuredBuffer <LightStruct> Light  <string uiname="Light Parameter Buffer";>;
StructuredBuffer <LightMatricesStruct> LightMatrices  <string uiname="Light Matrices Buffer";>;
StructuredBuffer <MaterialStruct> Material  <string uiname="Material";>;

SamplerState g_samLinear
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = WRAP;
    AddressV = WRAP;
};

SamplerState g_samLinearIBL
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
};

#include "ShadowMapping.fxh"
#include "NoTile.fxh"
#include "ParallaxOcclusionMapping.fxh"
#include "CookTorrance.fxh"
#ifdef doIBL
#include "IBL.fxh"
#elif doIridescence	
#include "IRIDESCENCE.fxh"
#elif doGlobalLight
#include "GLOBALLIGHT.fxh"
#endif
#ifdef doPlanarReflections
#include "PLANARREFLECTION.fxh"
#endif

#ifdef doToneMap
#include "ToneMapping.fxh"
#endif

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
	Out.TexCd = mul(TexCd,Material[ID%mCount].tTex);
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
	Out.TexCd = mul(TexCd,Material[ID%mCount].tTex);
    return Out;
}

#ifdef doShadowPOM
float4 doLighting(float4 PosW, float3 N, float4 TexCd, float3x3 tbn){
#else
float4 doLighting(float4 PosW, float3 N, float4 TexCd){
#endif
	
	uint texID = ID%mCount;
	
	///////////////////////////////////////////////////////////////////////////
	// INITIALIZE GLOBAL VARIABLES
	///////////////////////////////////////////////////////////////////////////
	
	float3 V = normalize(tVI[3].xyz - PosW.xyz);

	///////////////////////////////////////////////////////////////////////////
	// INITIALIZE PBR PRAMETERS WITH TEXTURE LOOKUP
	///////////////////////////////////////////////////////////////////////////
	
	float4 albedo = 1;
	float roughnessT = 0;
	float aoT = 1;
	float metallicT = 0;
	
	#ifdef doControlTextures
	if(useTex[texID]){
	
		roughnessT = Material[texID].roughness;
		if(Material[texID].sampleRoughness) roughnessT = roughTex.Sample(g_samLinear, float3(TexCd.xy, texID)).r;
		roughnessT = min(max(roughnessT * Material[texID].roughness,.02),1);

		aoT = 1;
		if(Material[texID].sampleAO) aoT = aoTex.Sample(g_samLinear,  float3(TexCd.xy, texID)).r;
	
		metallicT = 1;
		if(Material[texID].sampleMetallic) metallicT = metallTex.Sample(g_samLinear, float3(TexCd.xy, texID)).r;
		metallicT *= Material[texID].metallic;
		
		float4 texCol = 1;
		if(Material[texID].sampleAlbedo) texCol = texture2d.Sample(g_samLinear, float3(TexCd.xy, texID));
	
		albedo = texCol * saturate(Material[texID].Color) * aoT;	
		
	} else {
		roughnessT = min(max(Material[texID].roughness,.02),1);
		aoT = 1;
		metallicT = Material[texID].metallic;
		albedo = saturate(Material[texID].Color);
	}
	
	#else
		
		roughnessT = min(max(Material[texID].roughness,.02),1);
		aoT = 1;
		metallicT = Material[texID].metallic;
		albedo = saturate( Material[texID].Color);
		
		
	
	#endif
	
	///////////////////////////////////////////////////////////////////////////
	// INITIALIZE PBR PRAMETERS WITH TEXTURE LOOKUP
	///////////////////////////////////////////////////////////////////////////
	
	float3 iridescenceColor = 1;
	#ifdef doIridescence
	if (Material[texID].Iridescence){
		float inverseDotView = 1.0 - max(dot(N,V),0.0);
		iridescenceColor = iridescence.Sample(g_samLinear, float3(inverseDotView,0,texID)).rgb;
	} 	
	#endif
		
	///////////////////////////////////////////////////////////////////////////
	// INITIALIZE VARIABLES FOR LIGHT LOOP
	///////////////////////////////////////////////////////////////////////////
	
	float4 viewPosition;
	float4 projectTexCoord;
	
	float3 F0 = lerp(F, albedo.xyz, metallicT);
	
	int shadowCounter = 0;
	int spotLightCount = 0;
	int lightCounter = 0;
	
	float4 shadow = 0;
	
	float3 lightToObject;
	float3 L;
	float lightDist;
	float falloff;

	float3 finalLight = 0;
	float attenuation;
	///////////////////////////////////////////////////////////////////////////
	// SHADING AND SHADOW MAPPING FOR EACH LIGHT
	///////////////////////////////////////////////////////////////////////////
	
	for(uint i = 0; i< num; i++){

		lightToObject = Light[i].lPos.xyz - PosW.xyz;
		L = normalize(lightToObject);
		lightDist = length(lightToObject);
		
		falloff = smoothstep(0,Light[i].lAtt1,(Light[i%num].lightRange-lightDist));
			
		
		switch (Light[i].lightType){
			
		// DIRECTIONAL
			case 0:
			
				shadow = 0;

				viewPosition = mul(PosW, LightMatrices[i].VP);
				
				projectTexCoord.x =  viewPosition.x / viewPosition.w / 2.0f + 0.5f;
		   		projectTexCoord.y = -viewPosition.y / viewPosition.w / 2.0f + 0.5f;			
				projectTexCoord.z =  viewPosition.z / viewPosition.w / 2.0f + 0.5f;
			
				
			
				if((saturate(projectTexCoord.x) == projectTexCoord.x) && (saturate(projectTexCoord.y) == projectTexCoord.y)
				&& (saturate(projectTexCoord.z) == projectTexCoord.z
				&& Light[i].useShadow)){
					doShadow(shadow, Light[i].shadowType, lightDist, Light[i%num].lightRange, projectTexCoord, viewPosition, i, shadowCounter, N, L);
				
					shadow += smoothstep(0,1,saturate(pow(length(.5-projectTexCoord.xy)*2,3)));
				} else {
					shadow = 1;
				}
							

					#ifdef doShadowPOM
						if(Light[i].shadowPOM > 0 && Material[texID].POM && useTex[texID]) shadow = min(shadow, parallaxSoftShadowMultiplier(-L, TexCd.xy, tbn, texID, i,Light[i].shadowPOM).xxxx);
					#endif
	
//				attenuation = Light[i].lAtt0 * falloff;	
			
				finalLight += cookTorrance(V, L, N, albedo.xyz, Light[i].Color.rgb,
				lerp(1.0,saturate(shadow),falloff).x, 1.0, lightDist, Material[texID].sssAmount, Material[texID].sssFalloff, F0, 1, roughnessT, metallicT, aoT, iridescenceColor, texID);
				
				lightCounter ++;
				if(Light[i].useShadow) shadowCounter++;	
				break;
			
			// SPOT
			case 1:
			
				shadow = 0;
				viewPosition = mul(PosW, LightMatrices[i].VP);
					
				projectTexCoord.x =  viewPosition.x / viewPosition.w / 2.0f + 0.5f;
		   		projectTexCoord.y = -viewPosition.y / viewPosition.w / 2.0f + 0.5f;			
				projectTexCoord.z =  viewPosition.z / viewPosition.w / 2.0f + 0.5f;
			
				float3 falloffSpot = 0;
			
				if((saturate(projectTexCoord.x) == projectTexCoord.x) && (saturate(projectTexCoord.y) == projectTexCoord.y)
				&& (saturate(projectTexCoord.z) == projectTexCoord.z)){
					
					uint tXS,tYS,mS;
					lightMap.GetDimensions(tXS,tYS,mS);
					if(tXS+tYS > 4) falloffSpot = lightMap.SampleLevel(g_samLinear, float3(projectTexCoord.xy, spotLightCount), 0 ).rgb;
					else if(tXS+tYS < 4) falloffSpot = smoothstep(1,0,saturate(length(.5-projectTexCoord.xy)*2));
					
					if(Light[i].useShadow){
						doShadow(shadow, Light[i].shadowType, lightDist, Light[i%num].lightRange, projectTexCoord, viewPosition, i, shadowCounter, N, L);
						shadow = min(dot(N,L) * 2, shadow);
					}
			
				} else {
					shadow = 1;
				}
				
				#ifdef doShadowPOM
//						float3 LDir1 = float3(LightMatrices[i].V._m02,LightMatrices[i].V._m12,LightMatrices[i].V._m22);	
						if(Light[i].shadowPOM > 0 && Material[texID].POM && useTex[texID]) shadow = min(shadow, parallaxSoftShadowMultiplier(-L, TexCd.xy, tbn, texID, i,Light[i].shadowPOM).xxxx);
				#endif
			
				attenuation = Light[i].lAtt0 * falloff;
				finalLight += cookTorrance(V, L, N, albedo.xyz, Light[i].Color.rgb,
				shadow.x, falloffSpot, lightDist, Material[texID].sssAmount, Material[texID].sssFalloff, F0, attenuation, roughnessT, metallicT, aoT, iridescenceColor, texID);

				if(Light[i].useShadow) shadowCounter++;	
				lightCounter ++;
				spotLightCount++;
				break;
	
			// POINT
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
						projectTexCoord.z =  viewPosition.z / viewPosition.w / 2.0f + 0.5f;
					
						if((saturate(projectTexCoord.x) == projectTexCoord.x) && (saturate(projectTexCoord.y) == projectTexCoord.y)
						&& (saturate(projectTexCoord.z) == projectTexCoord.z)){
							
							viewPosition = mul(PosW, LightMatrices[p + lightCounter].VP);
							
							projectTexCoord.x =  viewPosition.x / viewPosition.w / 2.0f + 0.5f;
				   			projectTexCoord.y = -viewPosition.y / viewPosition.w / 2.0f + 0.5f;
							projectTexCoord.z =  viewPosition.z / viewPosition.w / 2.0f + 0.5f;
							
							doShadow(shadow, Light[i].shadowType, lightDist, Light[i%num].lightRange, projectTexCoord, viewPosition, i, p+shadowCounter, N, L);

						}
					}
					
							#ifdef doShadowPOM
								if(Light[i].shadowPOM > 0 && Material[texID].POM && useTex[texID]) shadow = min(shadow, parallaxSoftShadowMultiplier(-L, TexCd.xy, tbn, texID, i,Light[i].shadowPOM).xxxx);
							#endif
					
							float attenuation = Light[i].lAtt0 * falloff;
							finalLight += cookTorrance(V, L, N, albedo.xyz, Light[i].Color.rgb,
							shadow.x, 1.0, lightDist, Material[texID].sssAmount, Material[texID].sssFalloff, F0, attenuation, roughnessT, metallicT, aoT, iridescenceColor, texID);
				
							shadowCounter += 6;
							lightCounter  += 6;
				} else {
							shadow = 1;
							#ifdef doShadowPOM
								if(Light[i].shadowPOM > 0 && Material[texID].POM) shadow = min(shadow, parallaxSoftShadowMultiplier(-L, TexCd.xy, tbn, texID, i,Light[i].shadowPOM).xxxx);
							#endif
					
						    float attenuation = Light[i].lAtt0 * falloff;
							finalLight += cookTorrance(V, L, N, albedo.xyz, Light[i].Color.rgb,
							shadow, 1, lightDist, Material[texID].sssAmount, Material[texID].sssFalloff, F0, attenuation, roughnessT, metallicT, aoT, iridescenceColor, texID);
			
				}	
			
			

			break;			
		}	
	}
	
	///////////////////////////////////////////////////////////////////////////
	// IMAGE BASED LIGHTING
	///////////////////////////////////////////////////////////////////////////
	#ifdef doIBL
		finalLight += IBL(N, V, F0, albedo, iridescenceColor, roughnessT, metallicT, aoT, texID );
	#elif doIridescence
		finalLight += IRIDESCENCE(N, V, F0, albedo, iridescenceColor, roughnessT, aoT,metallicT );
	#elif doGlobalLight
		finalLight +=  GLOBALLIGHT(N, V, F0, albedo, roughnessT, aoT, metallicT );
	#endif
	#ifdef doPlanarReflections
		finalLight += PLANARREFLECTION(PosW, N, V, F0, albedo, roughnessT, aoT, metallicT, TexCd, ID );
	#endif
	
	///////////////////////////////////////////////////////////////////////////
	// EMISSIVE LIGHTING
	///////////////////////////////////////////////////////////////////////////
	
	#ifdef doControlTextures
		if(Material[texID].sampleEmissive){
			finalLight.rgb += saturate(Material[texID].Emissive.rgb + EmissiveTex.SampleLevel(g_samLinear, float3(TexCd.xy, texID),0).rgb);
		} else {
			finalLight.rgb += saturate( Material[texID].Emissive.rgb);
		}
	#else
		finalLight.rgb += saturate( Material[texID].Emissive.rgb);
	#endif
	
	#ifdef doToneMap
	finalLight.rgb = ACESFitted(finalLight.rgb);
	#endif
	
	
	return float4(finalLight,Alpha*albedo.a);
}


float4 PS_PBR(vs2ps In): SV_Target
{	
	#ifdef doShadowPOM
		return doLighting(In.PosW, In.NormW, In.TexCd, 1);
	#else	
		return doLighting(In.PosW, In.NormW, In.TexCd);
	#endif
}

float4 PS_PBR_Bump(vs2psBump In): SV_Target
{	
	uint texID = ID%mCount;
	#ifdef doPOM
	if(Material[texID].POM && useTex[texID]){
		parallaxOcclusionMapping(In.TexCd.xy, In.PosW.xyz, normalize(tVI[3].xyz - In.PosW.xyz), float3x3(In.tangent,In.binormal,In.NormW.xyz),texID);
	}
	#endif
	
	float3 bumpMap = float3(0,0,0);
	
	#ifdef doControlTextures
	if(Material[texID].sampleNormal && useTex[texID]) bumpMap = normalTex.Sample(g_samLinear,float3(In.TexCd.xy, texID)).rgb;
	if(length(bumpMap) > 0) bumpMap = (bumpMap * 2.0f) - 1.0f;
	#endif
	
	float3 Nb = normalize(In.NormW.xyz + (bumpMap.x * In.tangent + bumpMap.y * In.binormal)*Material[texID].bumpy);
	
	#ifdef doShadowPOM
		return doLighting(In.PosW, Nb, In.TexCd, float3x3(In.tangent, In.binormal,In.NormW));
	#else	
		return doLighting(In.PosW, In.NormW, In.TexCd);
	#endif

}

float4 PS_PBR_Bump_AutoTNB(vs2ps In): SV_Target
{	
	uint texID = ID%mCount;
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
//	float3 n = normalize(In.NormW);
	float3 x = cross(In.NormW, t);
	t = cross(x, In.NormW);
	t = normalize(t);
	// get updated bi-tangent
	x = cross(b, In.NormW);
	b = cross(In.NormW, x);
	b = normalize(b);
	
	
	#ifdef doControlTextures
	#ifdef doPOM
	if(Material[texID].POM && useTex[texID]){
		parallaxOcclusionMapping(In.TexCd.xy, In.PosW.xyz, normalize(tVI[3].xyz - In.PosW.xyz), float3x3(t,b,In.NormW.xyz),texID);
	}
	#endif
	#endif
	
	float3 bumpMap = float3(0,0,0);

	#ifdef doControlTextures
	if(Material[texID].sampleNormal && useTex[texID]) bumpMap = normalTex.Sample(g_samLinear,float3(In.TexCd.xy, texID)).rgb;
	if(length(bumpMap) > 0) bumpMap = (bumpMap * 2.0f) - 1.0f;
	#endif
	
	float3 Nb = normalize(In.NormW.xyz + (bumpMap.x * (-t) + bumpMap.y * (b))*Material[texID].bumpy);

	#ifdef doShadowPOM
		return doLighting(In.PosW, Nb, In.TexCd, float3x3(t, b, Nb));
	#else	
		return doLighting(In.PosW, Nb, In.TexCd);
	#endif
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