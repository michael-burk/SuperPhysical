matrix CamtVP : PRCAM;
Texture2D PlanarReflections : PLANARTEX ;
//Texture2D PlanarDepth : PLANARDEPTH ;
StructuredBuffer <float3> planeNormal : PLANENORMAL;

int PlanarID : PLANARID;
float planarIntensity : PLANARINTENSITY;

SamplerState g_samLinearPR 
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
};


float3 PLANARREFLECTION(float4 PosW, float3 N, float3 V, float3 F0, float4 albedo,
float roughness, float ao, float metallic, float4 TexCd, int ID, inout float planarMask){

	if(dot(planeNormal[0], V) > 0) return 0;
	
	float3 kS  = fresnelSchlickRoughness(max(dot(N, V), 0.0), F0,roughness);
	float3 kD  = 1.0 - kS;
		   kD *= 1.0 - metallic;
	float2 envBRDF  = brdfLUT.Sample(g_samLinearIBL, float2(max(dot(N, V), 0.0),roughness)*float2(1,-1)).rg;
	
	
		
	float3 bumpMap = float3(0,0,0);
	#ifndef Deferred
	#ifdef doControlTextures
		if(Material[ID].sampleNormal && useTex[ID]) bumpMap = normalTex.Sample(g_samLinear,float3(TexCd.xy, ID)).rgb;
	#endif
	#endif
	

	float4 viewPosition = mul(PosW, CamtVP);
	float2 projectTexCoord;	
	projectTexCoord.x =  viewPosition.x / viewPosition.w / 2.0f + 0.5f;
	projectTexCoord.y = -viewPosition.y / viewPosition.w / 2.0f + 0.5f;	

	
	// y tho?
	#ifdef doControlTextures
		float4 PR = PlanarReflections.SampleLevel(g_samLinearPR, projectTexCoord + (bumpMap.xy - .5)  * Material[ID].bumpy , saturate(roughness) * MAX_REFLECTION_LOD * MAX_REFLECTION_LOD);
	#else
		float4 PR = PlanarReflections.SampleLevel(g_samLinearPR, projectTexCoord + (bumpMap.xy - .5)  * Material[ID].bumpy , saturate(roughness) * MAX_REFLECTION_LOD * 1);
	#endif
	
	planarMask = 1 - PR.a;
	
	return PR.rgb *(kS * envBRDF.x + envBRDF.y) * planarIntensity;

}
