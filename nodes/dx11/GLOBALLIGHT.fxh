
float3 GLOBALLIGHT(float3 N, float3 V, float3 F0, float4 albedo, float roughness, float ao, float metallic){
	///////////////////////////////////
	//  IBL
	//////////////////////////////////

	float3 IBL = float3(0,0,0);

	float3 kS  = fresnelSchlickRoughness(max(dot(N, V), 0.0), F0,roughness);
	float3 kD  = 1.0 - kS;
		   kD *= 1.0 - metallic;
	float2 envBRDF  = brdfLUT.Sample(g_samLinearIBL, float2(max(dot(N, V), 0.0),roughness)*float2(1,-1)).rg;

	float GlobalReflConstant = 1.75;
	#ifdef doPlanarReflections
			#ifndef Deferred
				if(PlanarID == ID){
					if(dot(planeNormal[0], V) < 0) GlobalReflConstant -= planarIntensity;
				}
			#endif
	#endif
	
	IBL +=  GlobalDiffuseColor.rgb * albedo.rgb * kD * ao + GlobalReflectionColor.rgb *(kS * envBRDF.x + envBRDF.y) * ao * GlobalReflConstant;
	
	//////////////////////////////////

	return IBL;
}
