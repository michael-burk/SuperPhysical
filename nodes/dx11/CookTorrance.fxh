
static const float PI = 3.14159265359;

float3 fresnelSchlick(float cosTheta, float3 F0)
{
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}  

float3 fresnelSchlickRoughness(float cosTheta, float3 F0, float roughness)
{
    return F0 + (max(float3(1.0 - roughness,1.0 - roughness,1.0 - roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
}   

float DistributionGGX(float3 N, float3 H, float roughness)
{
    float a      = roughness*roughness;
    float a2     = a*a;
    float NdotH  = max(dot(N, H), 0.0);
    float NdotH2 = NdotH*NdotH;
    
    float nom   = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;
    
    return nom / denom;
}

float GeometrySchlickGGX(float NdotV, float roughness)
{
    float r = (roughness + 1.0);
    float k = (r*r) / 8.0;

    float nom   = NdotV;
    float denom = NdotV * (1.0 - k) + k;
    
    return nom / denom;
}

float GeometrySmith(float3 N, float3 V, float3 L, float roughness)
{
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2  = GeometrySchlickGGX(NdotV, roughness);
    float ggx1  = GeometrySchlickGGX(NdotL, roughness);
    
    return ggx1 * ggx2;
}

float3 cookTorrance(float3 V, float3 L, float3 N, float3 albedo, float3 lDiff,
                    float shadow, float3 projectionColor,
                    float lightDist, float sss, float sssFalloff, float3 F0,
                    float attenuation, float roughness, float metallic, float ao,float3 iridescenceColor, uint texID){
    roughness = clamp(roughness,0.0500,1);
    float3 H = normalize(V + L);
    float3 radiance   = lDiff * attenuation * shadow * projectionColor;      
    // cook-torrance brdf
    float NDF = DistributionGGX(N, H,roughness);        
    float G   = GeometrySmith(N, V, L,roughness);      
    float3 F  = fresnelSchlick(max(dot(H, V), 0.0), F0);                                
    float3 kS = F;
    float3 kD = 1.0 - kS;
    kD *= 1.0 - metallic;                               
    float3 nominator  = NDF * G * F;
    float denominator = 4 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0) + 0.001; 
    float3 specular   = nominator / denominator;
    specular *= lPower;
    specular *= iridescenceColor;

    if(Material[texID].Refraction.x) radiance *= roughness;
                    	
    float NdotL = max(dot(N, L), 0.0);
                    
	return ( ( (kD * albedo.xyz / PI + specular) * radiance * NdotL) + saturate(albedo * lDiff * attenuation * projectionColor / pow(lightDist,sssFalloff) * sss)  ) * ao * 3 /*because*/ ;
}