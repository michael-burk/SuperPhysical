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
float roughness, float ao, float metallic, float4 TexCd, int ID){

	if(dot(planeNormal[0], V) > 0) return 0;
	
	float3 kS  = fresnelSchlickRoughness(max(dot(N, V), 0.0), F0,roughness);
	float3 kD  = 1.0 - kS;
		   kD *= 1.0 - metallic;
	float2 envBRDF  = brdfLUT.Sample(g_samLinearIBL, float2(max(dot(N, V), 0.0)-.01,roughness)*float2(1,-1)).rg;
	
	
	float4 viewPosition = mul(PosW, CamtVP);
	float2 projectTexCoord;	
	projectTexCoord.x =  viewPosition.x / viewPosition.w / 2.0f + 0.5f;
	projectTexCoord.y = -viewPosition.y / viewPosition.w / 2.0f + 0.5f;	
	
//	float PRDepth = PlanarDepth.Sample(g_samLinearPR, projectTexCoord);

	float4 PR = PlanarReflections.SampleLevel(g_samLinearPR, projectTexCoord, roughness * MAX_REFLECTION_LOD * 9);
	
	return PR.rgb *(kS * envBRDF.x + envBRDF.y) * planarIntensity;

}
