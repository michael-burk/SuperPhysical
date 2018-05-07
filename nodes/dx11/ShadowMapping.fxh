SamplerState shadowSampler : immutable
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = BORDER;
    AddressV = BORDER;
	AddressW = BORDER;
	BorderColor = float4(1,1,1,0);

};

static const float minVariance = 0.0;

float4 calcShadowVSM(float worldSpaceDistance, float lightRange, float2 projectTexCoord, int shadowCounter, int lightCounter){
	
	 float currentDistanceToLight = clamp((worldSpaceDistance - 0 /*nearPlane*/) 
     / (lightRange /*farPlane*/ - 0 /*nearPlane*/), 0, 1);
	
    /////////////////////////////////////////////////////////

    // get blured and blured squared distance to light
	
	float4 shadowCol = shadowMap.SampleLevel(shadowSampler, float3(projectTexCoord, shadowCounter), 0);
	float2 depths = shadowCol.xy;
	
    float M1 = depths.x;
    float M2 = depths.y;
    float M12 = M1 * M1;

    float p = 0.0;
    float lightIntensity = 1;
	float alpha = 0;
    if(currentDistanceToLight >= M1)
    {
        // standard deviation
        float sigma2 = M2 - M12;

        // when standard deviation is smaller than epsilon
        if(sigma2 < minVariance)
        {
            sigma2 = minVariance;
        }

        // chebyshev inequality - upper bound on the 
        // probability that fragment is occluded
        float intensity = sigma2 / (sigma2 + pow(currentDistanceToLight - M1, 2));

        // reduce light bleeding
        lightIntensity = clamp((intensity-Light[lightCounter].lightBleedingLimit)/ (1.0-Light[lightCounter].lightBleedingLimit), 0.0, 1.0);
    	
    	alpha +=  (1 - saturate(shadowCol.a));
    }

    /////////////////////////////////////////////////////////

    float4 resultingColor = float4(float3(lightIntensity,lightIntensity,lightIntensity),1);
	
	return resultingColor+alpha;
	
}

float Linstep(float a, float b, float v)
{
    return saturate((v - a) / (b - a));
}

float ReduceLightBleeding(float pMax, float amount)
{
  // Remove the [0, amount] tail and linearly rescale (amount, 1].
   return Linstep(amount, 1.0f, pMax);
}

float ChebyshevUpperBound(float2 moments, float mean, float minVariance,
                          float lightBleedingReduction)
{
    // Compute variance
    float variance = moments.y - (moments.x * moments.x);
    variance = max(variance, minVariance);

    // Compute probabilistic upper bound
    float d = mean - moments.x;
    float pMax = variance / (variance + (d * d));

    pMax = ReduceLightBleeding(pMax, lightBleedingReduction);

    // One-tailed Chebyshev
    return (mean <= moments.x ? 1.0f : pMax);
}


/////////////////////////////////////////////////////////////////////////////////
//  “Post-filtered” Soft Variance Shadow Mapping for Varying Penumbra Sizes
// http://www.derschmale.com/2014/07/24/faster-variance-soft-shadow-mapping-for-varying-penumbra-sizes/
/////////////////////////////////////////////////////////////////////////////////


	static float2 poissonDisk[16] =
	{
		float2(0.2770745f, 0.6951455f),
		float2(0.1874257f, -0.02561589f),
		float2(-0.3381929f, 0.8713168f),
		float2(0.5867746f, 0.1087471f),
		float2(-0.3078699f, 0.188545f),
		float2(0.7993396f, 0.4595091f),
		float2(-0.09242552f, 0.5260149f),
		float2(0.3657553f, -0.5329605f),
		float2(-0.3829718f, -0.2476171f),
		float2(-0.01085108f, -0.6966301f),
		float2(0.8404155f, -0.3543923f),
		float2(-0.5186161f, -0.7624033f),
		float2(-0.8135794f, 0.2328489f),
		float2(-0.784665f, -0.2434929f),
		float2(0.9920505f, 0.0855163f),
		float2(-0.687256f, 0.6711345f)
	};


//float lightSize;
//float shadowMapSize;
//float penumbraScale;
//Texture2D ditherTexture;
static const float poissonRadius = .5;
//uint numShadowSamples;

// moments contains float2(E(x), E(x^2))
// reference contains the depth value of the point to be compared
float UpperBoundShadow(float2 moments, float referenceDepth, float lightBleedingReduction)
{
    float variance = moments.y - moments.x * moments.x;
    // clamp to some minimum small variance value for numerical stability
    variance = max(variance, minVariance);
    float diff = referenceDepth - moments.x;

	
	
    // Chebyshev's inequality theorem
    float upperBound = variance / (variance + diff*diff);
	
	upperBound = ReduceLightBleeding(upperBound, lightBleedingReduction);
	
    // The upper bound is only correct when referenceDepth < moments.x (if not, return 1.0, ie: fully lit)
    return max(upperBound, referenceDepth < moments.x);
}


// searchAreaSize is expressed in shadow map UV coords (0 - 1)
// shadowMapSize is the size of the shadow map in texels
// shadowMapCoord is the shadow map coord projected into directional light space (so z contains its depth)
float GetAverageOccluderDepth(float searchAreaSize, int shadowMapSize, float4 shadowMapCoord, int shadowCounter, int lightCounter) 
{
    // calculate the mip level corresponding to the search area
    // Really, mipLevel would be a passed in as a constant.
    float mipLevel = log2(searchAreaSize * shadowMapSize);

    // retrieve the distribution's moments for the entire area
    // shadowMapSampler is a trilinear sampler, not a comparison sampler
	float4 moments = shadowMap.SampleLevel(shadowSampler, float3(shadowMapCoord.xy, shadowCounter), mipLevel);
    float averageTotalDepth = moments.x;        // assign for semantic clarity
	
	
    float probability = UpperBoundShadow(moments.xy, shadowMapCoord.z, Light[lightCounter].lightBleedingLimit);    
    
    // prevent numerical issues
    if (probability > .99) return 0.0;

    // calculate the average occluder depth
    return (averageTotalDepth - probability * shadowMapCoord.z) / (1.0 - probability);
}


// softness is the light size expressed in shadow map UV coords (0 - 1)
// shadowMapSize is the size of the shadow map in texels
// shadowMapCoord is the shadow map coord projected into directional light space (so z contains its depth)
// penumbraScale is a value describing how fast the penumbra should go soft. It can also be used to control the world space fall-off (by projecting world space distances to depth values)
float EstimatePenumbraSize(float lightSize, int shadowMapSize, float4 shadowMapCoord, int shadowCounter, int lightCounter, float penumbraScale)
{
    // the search area covers twice the light size
    float averageOccluderDepth = GetAverageOccluderDepth(lightSize, shadowMapSize, shadowMapCoord, shadowCounter, lightCounter);
    float penumbraSize = lightSize * (shadowMapCoord.z - averageOccluderDepth) * penumbraScale;
    // clamp to the maximum softness, which matches the search area
    return min(penumbraSize, lightSize);
}


float4 calcShadow_VSM_PCSS(float worldSpaceDistance, float lightRange, float4 shadowMapCoord, int shadowCounter, int lightCounter, /*float3 screenUV,*/ float2 shadowMapSize, float lightSize, float penumbraScale, uint numShadowSamples){

	
		 float currentDistanceToLight = clamp((worldSpaceDistance - 0 /*nearPlane*/) 
    	 / (lightRange /*farPlane*/ - 0 /*nearPlane*/), 0, 1);
		shadowMapCoord.z = currentDistanceToLight;
		
//	
		float penumbraSize = EstimatePenumbraSize(lightSize/100, shadowMapSize.x, shadowMapCoord, shadowCounter, lightCounter, penumbraScale);
		float2 moments = 0.0;
		// ditherTexture contains 2d rotation matrix (cos, -sin, sin, cos), this will tile the texture across the screen
//		float4 rotation = ditherTexture.SampleLevel(shadowSampler, screenUV * R / 256, 0) * 2.0 - 1.0;
		float4 rotation = float4(1,1,1,0);
		// calculate the mip level for the disk sample's area
		// Sample points are expected to be penumbraSize * poissonRadius * shadowMapSize texels apart
		// poissonRadius is half the minimum distance in the disk distribution
		float mipLevel = log2(penumbraSize * poissonRadius * shadowMapSize.x); 
		
		for (uint i = 0; i < numShadowSamples; ++i) {
		    // poissonDiskValues contain the sampling offsets in the unit circle
		    // scale by penumbraSize / 2 to get samples within the penumbra radius (penumbraSize is diameter)
		    float2 sampleOffset = poissonDisk[i%numShadowSamples] * penumbraSize / 2;
		    float4 coord = shadowMapCoord;

		    // add rotated sample offset using dithered sample
		    coord.x += sampleOffset.x * rotation.x + sampleOffset.y * rotation.y;
		    coord.y += sampleOffset.x * rotation.z + sampleOffset.y * rotation.w;
		
		    // shadowMapSampler is a trilinear sampler, not a comparison sampler
		    moments += shadowMap.SampleLevel(shadowSampler, float3(coord.xy, shadowCounter), mipLevel).rg;
		}
		moments /= numShadowSamples;
	

		return (float4)UpperBoundShadow(moments, shadowMapCoord.z, Light[lightCounter].lightBleedingLimit).xxxx;

}

static float u_depthMultiplier = 30;

//layout(location = 0) out vec4 resultingColor;

/////////////////////////////////////////////////

float4 calcShadowESM(float worldSpaceDistance, float lightRange, float2 projectTexCoord, int shadowCounter, int lightCounter){

    /////////////////////////////////////////////////

    // current distance to light
//    float3 fromLightToFragment = u_lightPosition - o_worldPos.xyz;
//    float worldSpaceDistance = length(fromLightToFragment);
	 float currentDistanceToLight = clamp((worldSpaceDistance - 0 /*nearPlane*/) 
     / (lightRange /*farPlane*/ - 0 /*nearPlane*/), 0, 1);

    /////////////////////////////////////////////////

    // get blured exp of depth
  //  float3 projectedCoords = o_shadowCoord.xyz / o_shadowCoord.w;
  //  float depthCExpBlured = texture(u_textureShadowMap, projectedCoords.xy).r;
	float depthCExpBlured = shadowMap.SampleLevel(shadowSampler, float3(projectTexCoord, shadowCounter), 0).r;

    // current exp of depth
    float depthCExpActual = exp(- (u_depthMultiplier * currentDistanceToLight));
    float expFactor = depthCExpBlured * depthCExpActual;
	
	expFactor = ReduceLightBleeding(expFactor, Light[lightCounter].lightBleedingLimit);

    // Threshold classification for high frequency artifacts
    if(expFactor > 1.0 + Light[lightCounter].lightBleedingLimit)
    {
        expFactor = 1.0;
    }

    /////////////////////////////////////////////////

    float4 resultingColor = float4(expFactor,expFactor,expFactor,1);
	return resultingColor;
	
}


float4 doShadow(inout float4 shadow, int shadowType, float lightDist, float lightRange, float4 projectTexCoord, float4 viewPosition, uint i, uint shadowCounter, float3 N, float3 L){
			switch(shadowType){
			case 0:
				shadow += saturate(calcShadowVSM(lightDist,lightRange,projectTexCoord.xy,shadowCounter, i));
				break;
			case 1:
				uint a;
				float b,c;
				shadowMap.GetDimensions(a,b,c);
				float2 shadowTexSize = float2(b,c);
				
				shadow += calcShadow_VSM_PCSS( lightDist, lightRange, float4(projectTexCoord.x,projectTexCoord.y,projectTexCoord.z,viewPosition.w),shadowCounter,i,shadowTexSize,Light[i].lightSize,Light[i].penumbraScale,Light[i].numShadowSamples);
				break;
			case 2:
				shadow += saturate(calcShadowESM(lightDist, lightRange,projectTexCoord.xy,shadowCounter,i));
				break;	
			}
	
	// Reduce projective aliasing
	shadow = min(dot(N,L) * 2, shadow);
	
	return shadow;
}