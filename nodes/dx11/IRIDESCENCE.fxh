
float3 IRIDESCENCE(float3 N, float3 V, float3 F0, float4 albedo, float3 iridescenceColor, float roughness, float metallic){
	///////////////////////////////////
	//  IBL
	//////////////////////////////////

	float3 IBL = float3(0,0,0);

	float3 kS  = fresnelSchlickRoughness(max(dot(N, V), 0.0), F0,roughness);
	float3 kD  = 1.0 - kS;
		   kD *= 1.0 - metallic;
	float2 envBRDF  = brdfLUT.Sample(g_samLinear, float2(max(dot(N, V), 0.0)-.01,roughness)*float2(1,-1)).rg;

	
	iridescenceColor *= (kS * envBRDF.x + envBRDF.y);
	IBL = iridescenceColor / kD;	
	IBL +=  GlobalDiffuseColor.rgb * albedo.rgb * kD + GlobalReflectionColor.rgb *(kS * envBRDF.x + envBRDF.y) * 2 * iridescenceColor;
	
	//////////////////////////////////

	return IBL;
}
