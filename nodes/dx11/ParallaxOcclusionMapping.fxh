//StructuredBuffer <float> fHeightMapScale;
//
//StructuredBuffer <uint> POM_numSamples;


void parallaxOcclusionMapping(inout float2 texcoord, inout float3 PosW, float3 V, float3x3 tbn, uint texID){
    
	
	
	float3x3 tangentToWorldSpace;

	tangentToWorldSpace[0] = -tbn[0];
	tangentToWorldSpace[1] = tbn[1];
	tangentToWorldSpace[2] = tbn[2];
	
	float3x3 worldToTangentSpace = transpose(tangentToWorldSpace);
	
//	float3 E = V;
	float3 N = tbn[2];
	V	= mul( V, worldToTangentSpace );
//    N = mul( tbn[2], worldToTangentSpace );
	
    float fParallaxLimit = -length( V.xy ) / V.z;
    fParallaxLimit *= -Material[texID].fHeightMapScale;  
    
    float2 vOffsetDir = normalize( V.xy );
    float2 vMaxOffset = vOffsetDir * fParallaxLimit;
    
//    int POM_numSamples = (int)lerp( nMaxSamples, nMinSamples, saturate(-dot( N, V)) );
    float fStepSize = 1.0 / (float)Material[texID].POMnumSamples;
    
    float2 dx = ddx_fine( texcoord );
    float2 dy = ddy_fine( texcoord );
    
    float fCurrRayHeight = 1.0;
    float2 vCurrOffset = float2( 0, 0 );
    float2 vLastOffset = float2( 0, 0 );
    
    float fLastSampledHeight = 1;
    float fCurrSampledHeight = 1;

    uint nCurrSample = 0;
    
    float delta1;
	float delta2;
	float ratio;
    while ( nCurrSample < (float) Material[texID].POMnumSamples ){    
                
      fCurrSampledHeight = heightMap.SampleGrad( g_samLinear, float3(texcoord + vCurrOffset, texID), dx, dy ).r;
      if ( fCurrSampledHeight > fCurrRayHeight ){
        delta1 = fCurrSampledHeight - fCurrRayHeight;
        delta2 = ( fCurrRayHeight + fStepSize ) - fLastSampledHeight;
    
        ratio = delta1/(delta1+delta2);
    
        vCurrOffset = (ratio) * vLastOffset + (1.0-ratio) * vCurrOffset;
    
        nCurrSample = Material[texID].POMnumSamples + 1;
      } else {
        nCurrSample++;
    
        fCurrRayHeight -= fStepSize;
    
        vLastOffset = vCurrOffset;
        vCurrOffset += fStepSize * vMaxOffset;
    
        fLastSampledHeight = fCurrSampledHeight;
      }
    
    }
	texcoord += vCurrOffset;
	
	float scale = sqrt(tW._11*tW._11 + tW._12*tW._12 + tW._13*tW._13);
	PosW.xyz -= mul(mul((float3(vCurrOffset,delta1*-Material[texID].fHeightMapScale)),mul(tangentToWorldSpace,(float3x3)Material[texID].tTexInv)).xyz,scale);
}

