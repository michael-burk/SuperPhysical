//StructuredBuffer <float> fHeightMapScale;
//
//StructuredBuffer <uint> POM_numSamples;

#ifdef Instancing
void parallaxOcclusionMapping(inout float2 texcoord, inout float3 PosW, float3 V, float3x3 tbn, uint texID, inout float POM_Height, uint iid){
#else
void parallaxOcclusionMapping(inout float2 texcoord, inout float3 PosW, float3 V, float3x3 tbn, uint texID, inout float POM_Height){
#endif
	
	float3x3 tangentToWorldSpace;

	tangentToWorldSpace[0] = -tbn[0];
	tangentToWorldSpace[1] = tbn[1];
	tangentToWorldSpace[2] = tbn[2];
	
	float3x3 worldToTangentSpace = transpose(tangentToWorldSpace);
	
	float3 N = tbn[2];
	V	= mul( V, worldToTangentSpace );
	
    float fParallaxLimit = -length( V.xy ) / V.z;
	
	#ifdef Deferred
		float fHeightMapScale = Material_NormalMapping[texID].fHeightMapScale;  
	#else
		float fHeightMapScale = Material[texID].fHeightMapScale;  
	#endif
	
	
	fParallaxLimit *= -fHeightMapScale;  

    
    float2 vOffsetDir = normalize( V.xy );
    float2 vMaxOffset = vOffsetDir * fParallaxLimit;
    
	#ifdef Deferred
		float samples = (float)Material_NormalMapping[texID].POMnumSamples;
	#else
		float samples = (float)Material[texID].POMnumSamples;
	#endif
	
   	float fStepSize = 1.0 / samples;

    
    float2 dx = ddx( texcoord );
    float2 dy = ddy( texcoord );
    
    float fCurrRayHeight = 1.0;
    float2 vCurrOffset = float2( 0, 0 );
    float2 vLastOffset = float2( 0, 0 );
    
    float fLastSampledHeight = 1;
    float fCurrSampledHeight = 1;

    uint nCurrSample = 0;
    
    float delta1;
	float delta2;
	float ratio;
	// (uint) = (float)
    while ( nCurrSample < (uint) samples ){    
                
      fCurrSampledHeight = heightMap.SampleGrad( g_samLinear, float3(texcoord + vCurrOffset, texID), dx, dy ).r;
      if ( fCurrSampledHeight > fCurrRayHeight ){
        delta1 = fCurrSampledHeight - fCurrRayHeight;
        delta2 = ( fCurrRayHeight + fStepSize ) - fLastSampledHeight;
    
        ratio = delta1/(delta1+delta2);
    
        vCurrOffset = (ratio) * vLastOffset + (1.0-ratio) * vCurrOffset;
    
        nCurrSample = samples + 1;
      } else {
        nCurrSample++;
    
        fCurrRayHeight -= fStepSize;
    
        vLastOffset = vCurrOffset;
        vCurrOffset += fStepSize * vMaxOffset;
    
        fLastSampledHeight = fCurrSampledHeight;
      }
    
    }
	texcoord += vCurrOffset;
	
	
	#ifdef Instancing
		float4x4 wo = world[iid];
		float scale = sqrt(wo._11*wo._11 + wo._12*wo._12 + wo._13*wo._13);
	#else
		float scale = sqrt(tW._11*tW._11 + tW._12*tW._12 + tW._13*tW._13);
	#endif
	
	POM_Height = heightMap.SampleGrad( g_samLinear, float3(texcoord, texID), dx, dy ).r;
	
	#ifdef Deferred
		PosW.xyz -= mul(mul((float3(vCurrOffset,delta1*-fHeightMapScale)),mul(tangentToWorldSpace,(float3x3)Material_NormalMapping[texID].tTexInv)).xyz,scale);
	#else
		PosW.xyz -= mul(mul((float3(vCurrOffset,delta1*-fHeightMapScale)),mul(tangentToWorldSpace,(float3x3)Material[texID].tTexInv)).xyz,scale);
	#endif
	
	
	
}

#ifndef Instancing
static const float POM_shadow_factor = 8;
float parallaxSoftShadowMultiplier(in float3 L, in float2 initialTexCoord, float4x3 tbnh,  uint texID, uint lightID, float factor)
{
	float3x3 tangentToWorldSpace;

	tangentToWorldSpace[0] =  tbnh[0];
	tangentToWorldSpace[1] = -tbnh[1];
	tangentToWorldSpace[2] =  tbnh[2];
	
	float3x3 worldToTangentSpace = transpose(tangentToWorldSpace);

	L	=  mul(-L, worldToTangentSpace );

   float shadowMultiplier = 0;

   // calculate lighting only for surface oriented to the light source
   if(dot(float3(0, 0, 1), L) > 0)
   {
      // calculate initial parameters
      float numSamplesUnderSurface = 0;
      shadowMultiplier	= 0;
	  float	numLayers = Light[lightID].shadowPOMSamples ;
   	
      float layerHeight	= (1) / numLayers;
   	
   		#ifdef Deferred
		float fHeightMapScale = Material_NormalMapping[texID].fHeightMapScale;  
		#else
		float fHeightMapScale = Material[texID].fHeightMapScale ;  
		#endif
   	
      float2 texStep	= fHeightMapScale * L.xy / (L.z + (L.z == 0) ) / numLayers ;

      // current parameters
      float currentLayerHeight	= 1 - tbnh[3].x - layerHeight;
      float2 currentTextureCoords	= initialTexCoord + texStep;

      float heightFromTexture	= 1 - heightMap.SampleLevel(g_samLinear, currentTextureCoords,0).r;
      float stepIndex	= 1;
	  
//   	  float counter = 0;
      // while point is below depth 0.0 )
      while(currentLayerHeight > 0)
      {
//      	counter ++;
         // if point is under the surface
         if(heightFromTexture < currentLayerHeight)
         {
            // calculate partial shadowing factor
            numSamplesUnderSurface	+= 1;
            float newShadowMultiplier	= (currentLayerHeight - heightFromTexture) * (1 - stepIndex / numLayers);
			shadowMultiplier = (max(shadowMultiplier, newShadowMultiplier * POM_shadow_factor * (1 - stepIndex / numLayers)));
         }

         // offset to the next layer
         stepIndex	+= 1;
         currentLayerHeight	-= layerHeight;
         currentTextureCoords	+= texStep;
         heightFromTexture	= 1-heightMap.SampleLevel(g_samLinear, currentTextureCoords,0).r;
      }

      // Shadowing factor should be 1 if there were no points under the surface
      if(numSamplesUnderSurface < 1)
      {
         shadowMultiplier = 1;
      }
      else
      {
		 shadowMultiplier = (1.0 - shadowMultiplier * factor);
      }
   }
	return shadowMultiplier;
}
	
#endif