static const half3 wavelength[3] =
{
	{ 1, 0, 0},
	{ 0, 1, 0},
	{ 0, 0, 1},
};

float3 IBL(float3 N, float3 V, float3 F0, float4 albedo, float3 iridescenceColor, float roughness, float metallic, float ao){
	///////////////////////////////////
	//  IBL
	//////////////////////////////////
	

	float3 reflColor = float3(0,0,0);
	float3 refrColor = float3(0,0,0);
	float3 IBL = float3(0,0,0);

	float3 kS  = fresnelSchlickRoughness(max(dot(N, V), 0.0), F0,roughness);
	float3 kD  = 1.0 - kS;
		   kD *= 1.0 - metallic;
	float2 envBRDF  = brdfLUT.Sample(g_samLinear, float2(max(dot(N, V), 0.0)-.01,roughness)*float2(1,-1)).rg;
	
	float3 reflVect = -reflect(V,N);
	float3 reflVecNorm = N;
	
	
			
	IBL = cubeTexIrradiance.Sample(g_samLinear,reflVecNorm).rgb;
	IBL  = IBL * albedo.xyz;
	
	float3 refl = cubeTexRefl.SampleLevel(g_samLinear,reflVect,roughness*MAX_REFLECTION_LOD).rgb;
	
	#ifdef doIridescence
	if(useIridescence){
	  refl *= iridescenceColor * (kS * envBRDF.x + envBRDF.y);
	} 
	#else
		refl *= (kS * envBRDF.x + envBRDF.y);
	#endif
	
	#ifdef doRefraction
	if(refraction){
		float3 refrVect;
	    for(int r=0; r<3; r++) {
	    	refrVect = refract(-V, N , refractionIndex[r]);
	    	refrColor += cubeTexRefl.SampleLevel(g_samLinear,refrVect,roughness*MAX_REFLECTION_LOD).rgb * wavelength[r];
		}
		refrColor *= 1 - (kS * envBRDF.x + envBRDF.y);
		
		IBL *= roughness;
	}
	#endif
	
	
	IBL  = saturate( (IBL * iblIntensity.x + refrColor) * kD + refl * iblIntensity.y) * ao;
	
	#ifdef doRefraction
	if(refraction){
		IBL += GlobalReflectionColor.rgb;
	}
	#endif
	
	#ifdef doGlobalLight
	IBL +=  GlobalDiffuseColor.rgb * albedo.rgb * kD + GlobalReflectionColor.rgb *(kS * envBRDF.x + envBRDF.y) * 2 * iridescenceColor;
	#endif
	
	//////////////////////////////////

	return IBL;
}
