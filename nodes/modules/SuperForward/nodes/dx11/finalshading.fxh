//@author: Johannes Schmidt || Kopffarben GbR
//@help: FinalShading.fxh
//@tags: forwardPlus
//@credits: Jeremiah van Oosten

#define FINALSHADING_FXH 1


#ifdef FINALSHADING
struct Material
{
    float4  GlobalAmbient;
    //-------------------------- ( 16 bytes )
    float4  AmbientColor;
    //-------------------------- ( 16 bytes )
    float4  EmissiveColor;
    //-------------------------- ( 16 bytes )
    float4  DiffuseColor;
    //-------------------------- ( 16 bytes )
    float4  SpecularColor;
    //-------------------------- ( 16 bytes )
    // Reflective value.
    float4  Reflectance;
    //-------------------------- ( 16 bytes )
    float   Opacity;
    float   SpecularPower;
    // For transparent materials, IOR > 0.
    float	IndexOfRefraction;
    int		HasAmbientTexture;
    //-------------------------- ( 16 bytes )
    int		HasEmissiveTexture;
    int		HasDiffuseTexture;
    int		HasSpecularTexture;
    int		HasSpecularPowerTexture;
    //-------------------------- ( 16 bytes )
    int		HasNormalTexture;
    int		HasBumpTexture;
    int		HasOpacityTexture;
    float	BumpIntensity;
    //-------------------------- ( 16 bytes )
    float   SpecularScale;
    float   AlphaThreshold;
    float2  Padding;
    //--------------------------- ( 16 bytes )
};  //--------------------------- ( 16 * 10 = 160 bytes )

struct VertexShaderOutput
{	
	float4 position     : SV_POSITION;  // Clip space position.
    float3 positionVS   : TEXCOORD0;    // View space position.
    float3 tangentVS    : TANGENT;      // View space tangent.
    float3 binormalVS   : BINORMAL;     // View space binormal.
	float3 normalVS     : NORMAL;       // View space normal.
	float2 texCoord		: TEXCOORD1;   	// Texture coordinate
};

#if GEO_HAS_TBN==1
	struct AppData
	{
	    float3 position : POSITION;
	    float3 tangent  : TANGENT;
	    float3 binormal : BINORMAL;
	    float3 normal   : NORMAL;
	    float2 texCoord : TEXCOORD0;
	};
	
	VertexShaderOutput vs( AppData IN , float4x4 tW, float4x4 tV, float4x4 tVP)
	{
		VertexShaderOutput OUT;
		// Clip space
	    OUT.position 	= mul(  float4( IN.position, 1.0f ), mul(tW,tVP) );
		// ViewSpace
		float4x4 tWV 	= mul(tW,tV);
	    OUT.positionVS 	= mul( float4( IN.position, 1.0f ), tWV ).xyz;
	    OUT.tangentVS 	= mul( IN.tangent, 	(float3x3)tWV );
	    OUT.binormalVS 	= mul( IN.binormal,	(float3x3)tWV );
	    OUT.normalVS 	= mul( IN.normal, 	(float3x3)tWV );
		// Texture coordinate
	    OUT.texCoord 	= IN.texCoord;
		return OUT;
	}
#else
	struct AppData
	{
	    float3 position : POSITION; 
	    float3 normal   : NORMAL;
	    float2 texCoord : TEXCOORD0;
	};
	struct TBN
	{
	    float3 tangent 	: TANGENT; 
	    float3 binormal : BINORMAL;
	    float3 normal 	: NORMAL;
	};
	TBN ComputeTBN(AppData IN, float4x4 tW)
	{
		TBN OUT;
		/*
		// compute derivations of the world position
		float3 p_dx = ddx(mul( IN.position, (float3x3)tW ));
		float3 p_dy = ddy(mul( IN.position, (float3x3)tW ));
		// compute derivations of the texture coordinate
		float2 tc_dx = ddx(IN.texCoord);
		float2 tc_dy = ddy(IN.texCoord);
		// compute initial tangent and bi-tangent
		float3 t = normalize( tc_dy.y * p_dx - tc_dx.y * p_dy );
		float3 b = normalize( tc_dy.x * p_dx - tc_dx.x * p_dy ); // sign inversion
		// get new tangent from a given mesh normal
		float3 n = normalize(IN.normal);
		float3 x = cross(n, t);
		t = cross(x, n);
		t = normalize(t);
		// get updated bi-tangent
		x = cross(b, n);
		b = cross(n, x);
		b = normalize(b);
		*/
		float3 tangent;
		float3 binormal;
		
		float3 c1 = cross(IN.normal, float3(0.0, 0.0, 1.0));
		float3 c2 = cross(IN.normal, float3(0.0, 1.0, 0.0));
		
		if (length(c1)>length(c2))
		{
		    tangent = c1;
		}
		else
		{
		    tangent = c2;
		}
		
		tangent = normalize(tangent);
		
		binormal = cross(IN.normal, tangent);
		binormal = normalize(binormal);
		
		OUT.tangent 	= tangent;
		OUT.binormal 	= binormal;
		OUT.normal 		= IN.normal;
		return OUT;
	}
	
	VertexShaderOutput vs( AppData IN , float4x4 tW, float4x4 tV, float4x4 tVP)
	{
		VertexShaderOutput OUT = (VertexShaderOutput)0;
		TBN tbn =  ComputeTBN( IN, tW);
		
		// Clip space
	    OUT.position 	= mul(  float4( IN.position, 1.0f ), mul(tW,tVP) );
		// ViewSpace
		float4x4 tWV 	= mul(tW,tV);
	    OUT.positionVS 	= mul( float4( IN.position, 1.0f ), tWV ).xyz;
	    
		OUT.tangentVS 	= mul( tbn.tangent, (float3x3)tWV );
	    OUT.binormalVS 	= mul( tbn.binormal,(float3x3)tWV );
	    OUT.normalVS 	= mul( tbn.normal, 	(float3x3)tWV );
		// Texture coordinate
	    OUT.texCoord 	= IN.texCoord;
		return OUT;
	}
#endif



// This lighting result is returned by the 
// lighting functions for each light type.
struct LightingResult
{
    float4 Diffuse;
    float4 Specular;
};



Texture2D AmbientTexture        : register( t0 );
Texture2D EmissiveTexture       : register( t1 );
Texture2D DiffuseTexture        : register( t2 );
Texture2D SpecularTexture       : register( t3 );
Texture2D SpecularPowerTexture  : register( t4 );
Texture2D NormalTexture         : register( t5 );
Texture2D BumpTexture           : register( t6 );
Texture2D OpacityTexture        : register( t7 );

float3 ExpandNormal( float3 n )
{
    return n * 2.0f - 1.0f;
}

float4 DoNormalMapping( float3x3 TBN, Texture2D tex, sampler s, float2 uv )
{
    float3 normal = tex.Sample( s, uv ).xyz;
    normal = ExpandNormal( normal );

    // Transform normal from tangent space to view space.
    normal = mul( normal, TBN );
    return normalize( float4( normal, 0 ) );
}

float4 DoBumpMapping( float3x3 TBN, Texture2D tex, sampler s, float2 uv, float bumpScale )
{
    // Sample the heightmap at the current texture coordinate.
    float height_00 = tex.Sample( s, uv ).r * bumpScale;
    // Sample the heightmap in the U texture coordinate direction.
    float height_10 = tex.Sample( s, uv, int2( 1, 0 ) ).r * bumpScale;
    // Sample the heightmap in the V texture coordinate direction.
    float height_01 = tex.Sample( s, uv, int2( 0, 1 ) ).r * bumpScale;

    float3 p_00 = { 0, 0, height_00 };
    float3 p_10 = { 1, 0, height_10 };
    float3 p_01 = { 0, 1, height_01 };

    // normal = tangent x bitangent
    float3 normal = cross( normalize(p_10 - p_00), normalize(p_01 - p_00) );

    // Transform normal from tangent space to view space.
    normal = mul( normal, TBN );

    return float4( normal, 0 );
}

float4 DoDiffuse( Light light, float4 L, float4 N )
{
    float NdotL = max( dot( N, L ), 0 );
    return light.Color * NdotL;
}

float4 DoSpecular( Light light, Material material, float4 V, float4 L, float4 N )
{
    float4 R = normalize( reflect( -L, N ) );
    float RdotV = max( dot( R, V ), 0 );

    return light.Color * pow( RdotV, material.SpecularPower );
}

// Compute the attenuation based on the range of the light.
float DoAttenuation( Light light, float d )
{
    return 1.0f - smoothstep( light.Range * 0.75f, light.Range, d );
}

float DoSpotCone( Light light, float4 L )
{
    // If the cosine angle of the light's direction 
    // vector and the vector from the light source to the point being 
    // shaded is less than minCos, then the spotlight contribution will be 0.
    float minCos = cos( radians( light.SpotlightAngle ) );
    // If the cosine angle of the light's direction vector
    // and the vector from the light source to the point being shaded
    // is greater than maxCos, then the spotlight contribution will be 1.
    float maxCos = lerp( minCos, 1, 0.5f );
    float cosAngle = dot( light.DirectionVS, -L );
    // Blend between the maxixmum and minimum cosine angles.
    return smoothstep( minCos, maxCos, cosAngle );
}

LightingResult DoPointLight( Light light, Material mat, float4 V, float4 P, float4 N )
{
    LightingResult result;

    float4 L = light.PositionVS - P;
    float distance = length( L );
    L = L / distance;

    float attenuation = DoAttenuation( light, distance );

    result.Diffuse = DoDiffuse( light, L, N ) * attenuation * light.Intensity;
    result.Specular = DoSpecular( light, mat, V, L, N ) * attenuation * light.Intensity;

    return result;
}

LightingResult DoDirectionalLight( Light light, Material mat, float4 V, float4 P, float4 N )
{
    LightingResult result;

    float4 L = normalize( -light.DirectionVS );

    result.Diffuse = DoDiffuse( light, L, N ) * light.Intensity;
    result.Specular = DoSpecular( light, mat, V, L, N ) * light.Intensity;

    return result;
}

LightingResult DoSpotLight( Light light, Material mat, float4 V, float4 P, float4 N )
{
    LightingResult result;

    float4 L = light.PositionVS - P;
    float distance = length( L );
    L = L / distance;

    float attenuation = DoAttenuation( light, distance );
    float spotIntensity = DoSpotCone( light, L );

    result.Diffuse = DoDiffuse( light, L, N ) * attenuation * spotIntensity * light.Intensity;
    result.Specular = DoSpecular( light, mat, V, L, N ) * attenuation * spotIntensity * light.Intensity;

    return result;
}

LightingResult DoLighting( StructuredBuffer<Light> lights, Material mat, float4 eyePos, float4 P, float4 N )
{
    float4 V = normalize( eyePos - P );

    LightingResult totalResult = (LightingResult)0;

    for ( int i = 0; i < NUM_LIGHTS; ++i )
    {
        LightingResult result = (LightingResult)0;

        // Skip lights that are not enabled.
        //if ( !lights[i].Enabled ) continue;
        // Skip point and spot lights that are out of range of the point being shaded.
        if ( lights[i].Type != DIRECTIONAL_LIGHT && length( lights[i].PositionVS - P ) > lights[i].Range ) continue;

        switch ( lights[i].Type )
        {
        case DIRECTIONAL_LIGHT:
        {
            result = DoDirectionalLight( lights[i], mat, V, P, N );
        }
        break;
        case POINT_LIGHT:
        {
            result = DoPointLight( lights[i], mat, V, P, N );
        }
        break;
        case SPOT_LIGHT:
        {
            result = DoSpotLight( lights[i], mat, V, P, N );
        }
        break;
        }
        totalResult.Diffuse += result.Diffuse;
        totalResult.Specular += result.Specular;
    }

    return totalResult;
}

#endif