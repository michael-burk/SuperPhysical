#define FORWARDPLUS_FXH 1


int NUM_LIGHTS  : NUM_LIGHTS; // should be defined by the application.

#ifndef BLOCK_SIZE
#define BLOCK_SIZE 16 // should be defined by the application.
#endif

#ifndef GEO_HAS_TBN
#define GEO_HAS_TBN 1 // should be defined by the application.
#endif



#define POINT_LIGHT 0
#define SPOT_LIGHT 1
#define DIRECTIONAL_LIGHT 2

#ifdef LIGHTCULLING
SamplerState LinearClampSampler:IMMUTABLE
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
};
#endif

#ifdef FINALSHADING
SamplerState LinearRepeatSampler:IMMUTABLE
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = WRAP;
    AddressV = WRAP;
}; 
SamplerState LinearClampSampler:IMMUTABLE
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
}; 
#endif


struct ComputeShaderInput
{
    uint3 groupID           : SV_GroupID;           // 3D index of the thread group in the dispatch.
    uint3 groupThreadID     : SV_GroupThreadID;     // 3D index of local thread ID in a thread group.
    uint3 dispatchThreadID  : SV_DispatchThreadID;  // 3D index of global thread ID in the dispatch.
    uint  groupIndex        : SV_GroupIndex;        // Flattened local index of the thread within a thread group.
};

struct Plane
{
    float3 N;   // Plane normal.
    float  d;   // Distance to origin.
};

struct Sphere
{
    float3 c;   // Center point.
    float  r;   // Radius.
};

struct Cone
{
    float3 T;   // Cone tip.
    float  h;   // Height of the cone.
    float3 d;   // Direction of the cone.
    float  r;   // bottom radius of the cone.
};

// Four planes of a view frustum (in view space).
// The planes are:
//  * Left,
//  * Right,
//  * Top,
//  * Bottom.
// The back and/or front planes can be computed from depth values in the 
// light culling compute shader.
struct Frustum
{
    Plane planes[4];   // left, right, top, bottom frustum planes.
};

// Parameters required to convert screen space coordinates to view space params.
cbuffer ScreenToViewParams
{
    float4x4 InverseProjection 	: INVERSEPROJECTION;
    float2 ScreenDimensions 	: SCREENDIMENSION;
}

// Convert clip space coordinates to view space
float4 ClipToView( float4 clip )
{
    // View space position.
	float4 view = mul( clip, InverseProjection );
    // Perspecitive projection.
    view = view / view.w;

    return view;
}

// Convert screen space coordinates to view space.
float4 ScreenToView( float4 screen )
{
    // Convert to normalized texture coordinates
    float2 texCoord = screen.xy / ScreenDimensions;

    // Convert to clip space
    float4 clip = float4( float2( texCoord.x, 1.0f - texCoord.y ) * 2.0f - 1.0f, screen.z, screen.w );

    return ClipToView( clip );
}
// Convert screen space coordinates to view space.
float4 ScreenToV4View( float4 screen )
{
    // Convert to normalized texture coordinates
    float2 texCoord = screen.xy / ScreenDimensions;

    // Convert to clip space
    float4 clip = float4( float2(1.0f - texCoord.x,  texCoord.y ) * 2.0f - 1.0f, screen.z, screen.w );

    return ClipToView( clip );
}

// Compute a plane from 3 noncollinear points that form a triangle.
// This equation assumes a right-handed (counter-clockwise winding order) 
// coordinate system to determine the direction of the plane normal.
Plane ComputePlane( float3 p0, float3 p1, float3 p2 )
{
    Plane plane;

    float3 v0 = p1 - p0;
    float3 v2 = p2 - p0;

    plane.N = normalize( cross( v0, v2 ) );

    // Compute the distance to the origin using p0.
    plane.d = dot( plane.N, p0 );

    return plane;
}


// Check to see if a sphere is fully behind (inside the negative halfspace of) a plane.
// Source: Real-time collision detection, Christer Ericson (2005)
float SpherePlaneDist( Sphere sphere, Plane plane )
{
    return dot( plane.N, sphere.c ) - plane.d ;
}

// Check to see if a sphere is fully behind (inside the negative halfspace of) a plane.
// Source: Real-time collision detection, Christer Ericson (2005)
bool SphereInsidePlane( Sphere sphere, Plane plane )
{
    return dot( plane.N, sphere.c ) - plane.d < -sphere.r;
}


// Check to see if a point is fully behind (inside the negative halfspace of) a plane.
bool PointInsidePlane( float3 p, Plane plane )
{
    return dot( plane.N, p ) - plane.d < 0;
}

// Check to see if a cone if fully behind (inside the negative halfspace of) a plane.
// Source: Real-time collision detection, Christer Ericson (2005)
bool ConeInsidePlane( Cone cone, Plane plane )
{
    // Compute the farthest point on the end of the cone to the positive space of the plane.
    float3 m = cross( cross( plane.N, cone.d ), cone.d );
    float3 Q = cone.T + cone.d * cone.h - m * cone.r;

    // The cone is in the negative halfspace of the plane if both
    // the tip of the cone and the farthest point on the end of the cone to the 
    // positive halfspace of the plane are both inside the negative halfspace 
    // of the plane.
    return PointInsidePlane( cone.T, plane ) && PointInsidePlane( Q, plane );
}

// Check to see of a light is partially contained within the frustum.
bool SphereInsideFrustum( Sphere sphere, Frustum frustum, float zNear, float zFar )
{
    bool result = true;

	#if MODE == 0
	    // First check depth
	    // Note: Here, the view vector points in the -Z axis so the 
	    // far depth value will be approaching -infinity.
		if ( sphere.c.z - sphere.r > zFar || sphere.c.z + sphere.r < zNear )
	    {
	       result = false;
	    }
		
		
		
		// Then check frustum planes
	    for ( int i = 0; i < 4 && result; i++ )
	    {
	        if ( SphereInsidePlane( sphere, frustum.planes[i] ) )
	        {
	            result = false;
	        }
	    }
	    return result;
	#endif
	#if MODE == 1
		Plane 	plane;
		float   tmp[6];
		bool 	zTestFound = false;
		int 	count = 0;
		
	    // Then check frustum planes
	    for ( int i = 0; i < 6 && result; i++ )
	    {
	    	bool 	zTest = false;
	    	switch(i)
			{
			    case 0:
					zTest 			= true;
					Plane nearPlane = { float3( 0, 0,  1 ),  zNear };
					plane 			= nearPlane;
			    break; 
			    case 1:
					zTest 			= true;
					Plane farPlane 	= { float3( 0, 0, -1 ), -zFar  };
					plane 			= farPlane;
			    break;    
			    default:
					plane 			= frustum.planes[i-2];
			    break;
			}
	    	float 	value =  SpherePlaneDist( sphere, plane);
	        if (value < 0)
	    	{
	    		if (zTest)
	    		{
	    			zTestFound = true;
	    		}
		    	if ( value < -sphere.r )
		        {
		            return false;
		        }
	    		tmp[count] = value;
	    		count++;
	    	}
	    	if (i == 5)
	    	{
	    		if (count == 2)
	    		{
	    			return !(length(float2(tmp[0], tmp[1])) >= sphere.r);
	    		}
	    		else if (count == 3 && zTestFound)
	    		{
	    			return !(length(float3(tmp[0], tmp[1], tmp[2])) >= sphere.r);
	    		}
	    	}
	    }
	    return result;
	#endif
}

bool ConeInsideFrustum( Cone cone, Frustum frustum, float zNear, float zFar )
{
    bool result = true;

    Plane nearPlane = { float3( 0, 0, -1 ), -zNear };
    Plane farPlane = { float3( 0, 0, 1 ), zFar };

    // First check the near and far clipping planes.
    //if ( ConeInsidePlane( cone, nearPlane ) || ConeInsidePlane( cone, farPlane ) )
    //{
    //    result = false;
    //}

    // Then check frustum planes
    for ( int i = 0; i < 4 && result; i++ )
    {
        if ( ConeInsidePlane( cone, frustum.planes[i] ) )
        {
            result = false;
        }
    }

    return result;
}

struct Light_FWP
{
    float4   color;
    float4   position;
	
	float    range;
	float	 lAtt0;
	float	 lAtt1;
	float	 type;
};