//@author: Johannes Schmidt || Kopffarben GbR
//@help: ComputeLightCullings
//@tags: forwardPlus
//@credits: Jeremiah van Oosten

#ifndef LIGHTCULLING
#define LIGHTCULLING 1
#endif

#ifndef MODE	
#define MODE 1
#endif

#ifndef FORWARDPLUS_FXH
#include "forwardplus.fxh"
#endif

cbuffer cbPerDraw : register(b0)
{
	float4x4 tV: VIEW;
	float4x4 tP: PROJECTION;
	float4x4 tVP: VIEWPROJECTION;
};

// Global variables
cbuffer DispatchParams
{
    // Number of groups dispatched. (This parameter is not available as an HLSL system value!)
    uint3   numThreadGroups;
    // uint padding // implicit padding to 16 bytes.
    // Total number of threads dispatched. (Also not available as an HLSL system value!)
    // Note: This value may be less than the actual number of threads executed 
    // if the screen size is not evenly divisible by the block size.
    uint3   numThreads;
    // uint padding // implicit padding to 16 bytes.
}

// The depth from the screen space texture.
Texture2D DepthTextureVS : OPAQUEDEPTH;

// Precomputed frustums for the grid.
StructuredBuffer<Frustum> in_Frustums;

// Debug texture for debugging purposes.
//Texture2D LightCountHeatMap;
//RWTexture2D<float4> DebugTexture;

// Global counter for current index into the light index list.
// "o_" prefix indicates light lists for opaque geometry while 
// "t_" prefix indicates light lists for transparent geometry.
globallycoherent RWStructuredBuffer<uint> o_LightIndexCounter 	: O_LIGHTINDEXCOUNTER;;
globallycoherent RWStructuredBuffer<uint> t_LightIndexCounter	: T_LIGHTINDEXCOUNTER;;

// Light index lists and light grids.
RWStructuredBuffer<uint> o_LightIndexList 	: O_LIGHTINDEXLIST;
RWStructuredBuffer<uint> t_LightIndexList 	: T_LIGHTINDEXLIST;
RWStructuredBuffer<uint2> o_LightGridBuffer	: O_LIGHTGRIDBUFFER;
RWStructuredBuffer<uint2> t_LightGridBuffer	: T_LIGHTGRIDBUFFER;

RWStructuredBuffer<float> DebugBuffer	: DEBUGBUFFER;

//RWTexture2D<uint2> o_LightGrid : O_LIGHTGRID;
//RWTexture2D<uint2> t_LightGrid : T_LIGHTGRID;

StructuredBuffer<Light_FWP> Lights : LIGHTS;

// Group shared variables.
groupshared uint uMinDepth;
groupshared uint uMaxDepth;
groupshared Frustum GroupFrustum;

// Opaque geometry light lists.
groupshared uint o_LightCount;
groupshared uint o_LightIndexStartOffset;
groupshared uint o_LightList[1024];

// Transparent geometry light lists.
groupshared uint t_LightCount;
groupshared uint t_LightIndexStartOffset;
groupshared uint t_LightList[1024];

// Add the light to the visible light list for opaque geometry.
void o_AppendLight( uint lightIndex )
{
    uint index; // Index into the visible lights array.
    InterlockedAdd( o_LightCount, 1, index );
    if ( index < 1024 )
    {
        o_LightList[index] = lightIndex;
    }
}

// Add the light to the visible light list for transparent geometry.
void t_AppendLight( uint lightIndex )
{
    uint index; // Index into the visible lights array.
    InterlockedAdd( t_LightCount, 1, index );
    if ( index < 1024 )
    {
        t_LightList[index] = lightIndex;
    }
}

// Implementation of light culling compute shader is based on the presentation
// "DirectX 11 Rendering in Battlefield 3" (2011) by Johan Andersson, DICE.
// Retrieved from: http://www.slideshare.net/DICEStudio/directx-11-rendering-in-battlefield-3
// Retrieved: July 13, 2015
// And "Forward+: A Step Toward Film-Style Shading in Real Time", Takahiro Harada (2012)
// published in "GPU Pro 4", Chapter 5 (2013) Taylor & Francis Group, LLC.
[numthreads( BLOCK_SIZE, BLOCK_SIZE, 1 )]
void CS_ComputeLightCullings( ComputeShaderInput IN )
{
    // Calculate min & max depth in threadgroup / tile.
    int2 texCoord = ScreenDimensions - int2(1,1) - IN.dispatchThreadID.xy ;
    float fDepth = DepthTextureVS.Load( int3( texCoord, 0 ) ).r;

    uint uDepth = asuint( fDepth );

    if ( IN.groupIndex == 0 ) // Avoid contention by other threads in the group.
    {
    	if (IN.dispatchThreadID.x == 0 && IN.dispatchThreadID.y == 0 && IN.dispatchThreadID.z == 0)
		{
			//uint tmp;
	    	//InterlockedExchange(o_LightIndexCounter[0],0,tmp);
	    	//InterlockedExchange(t_LightIndexCounter[0],0,tmp);
			o_LightIndexCounter[0] = 0;
			t_LightIndexCounter[0] = 0;
		}
        uMinDepth = 0xffffffff;
        uMaxDepth = 0;
        o_LightCount = 0;
        t_LightCount = 0;
        GroupFrustum = in_Frustums[IN.groupID.x + ( IN.groupID.y * numThreadGroups.x )];
    }

    GroupMemoryBarrierWithGroupSync();

    InterlockedMin( uMinDepth, uDepth );
    InterlockedMax( uMaxDepth, uDepth );
	 
    GroupMemoryBarrierWithGroupSync();

    float fMinDepth = asfloat( uMinDepth );
    float fMaxDepth = asfloat( uMaxDepth );
	
    // Convert depth values to view space.
    float minDepthVS = ScreenToV4View( float4( 0, 0, fMinDepth, 1 ) ).z;
    float maxDepthVS = ScreenToV4View( float4( 0, 0, 1 /*fMaxDepth*/, 1 ) ).z;
    float nearClipVS = ScreenToV4View( float4( 0, 0, 0, 1 ) ).z;
	
    // Clipping plane for minimum depth value 
    // (used for testing lights within the bounds of opaque geometry).
    Plane minPlane = { float3( 0, 0, 1 ), minDepthVS };

	if ( IN.groupIndex == 0 )
    {
    	float4 view = mul(  float4(0,0,1,1),InverseProjection );
    	view = view / view.w;
    	
    	DebugBuffer[IN.groupID.x + (IN.groupID.y * numThreadGroups.x)] = IN.dispatchThreadID.x ;
    }
	
	
    // Cull lights
    // Each thread in a group will cull 1 light until all lights have been culled.
    for ( uint i = IN.groupIndex; i < (uint)NUM_LIGHTS; i += BLOCK_SIZE * BLOCK_SIZE )
    {
        Light_FWP light = Lights[i];

        switch ( light.type )
        {
        case 2:
        {	
			//mul(light.position, tV).xyz //light.range
            Sphere sphere = {mul(light.position, tV).xyz , light.range};
            if ( SphereInsideFrustum( sphere, GroupFrustum, nearClipVS, maxDepthVS ) )
            {
                // Add light to light list for transparent geometry.
                t_AppendLight( i );

                if ( !SphereInsidePlane( sphere, minPlane ) )
                {
                    // Add light to light list for opaque geometry.
                    o_AppendLight( i );
                }
            	
            }
        }
        break;
        	
        }
//        case SPOT_LIGHT:
//        {
//            float coneRadius = tan( radians( light.SpotlightAngle ) ) * light.Range;
//            Cone cone = { light.PositionVS.xyz, light.Range, light.DirectionVS.xyz, coneRadius };
//            if ( ConeInsideFrustum( cone, GroupFrustum, nearClipVS, maxDepthVS ) )
//            {
//                // Add light to light list for transparent geometry.
//                t_AppendLight( i );
//
//                if ( !ConeInsidePlane( cone, minPlane ) )
//                {
//                    // Add light to light list for opaque geometry.
//                    o_AppendLight( i );
//                }
//            }
//        }
//        break;
//        case DIRECTIONAL_LIGHT:
//        {
//            // Directional lights always get added to our light list.
//            // (Hopefully there are not too many directional lights!)
//            t_AppendLight( i );
//            o_AppendLight( i );
//        }
//        break;
//        }
    }

    // Wait till all threads in group have caught up.
    GroupMemoryBarrierWithGroupSync();

    // Update global memory with visible light buffer.
    // First update the light grid (only thread 0 in group needs to do this)
    if ( IN.groupIndex == 0 )
    {
    	
    	uint flatindex = (numThreadGroups.x-IN.groupID.x-1) + ((numThreadGroups.y -IN.groupID.y-1) * numThreadGroups.x);
        // Update light grid for opaque geometry.
        InterlockedAdd( o_LightIndexCounter[0], o_LightCount, o_LightIndexStartOffset );
    	o_LightGridBuffer[flatindex] = uint2( o_LightIndexStartOffset, o_LightCount );
    	
        // Update light grid for transparent geometry.
        InterlockedAdd( t_LightIndexCounter[0], t_LightCount, t_LightIndexStartOffset );
    	t_LightGridBuffer[flatindex] = uint2( t_LightIndexStartOffset, t_LightCount );
	}
	
    GroupMemoryBarrierWithGroupSync();

    // Now update the light index list (all threads).
    // For opaque goemetry.
    for ( i = IN.groupIndex; i < o_LightCount; i += BLOCK_SIZE * BLOCK_SIZE )
    {
        o_LightIndexList[o_LightIndexStartOffset + i] = o_LightList[i];
    }
	
    // For transparent geometry.
    for ( i = IN.groupIndex; i < t_LightCount; i += BLOCK_SIZE * BLOCK_SIZE )
    {
        t_LightIndexList[t_LightIndexStartOffset + i] = t_LightList[i];
    }
}

technique11 Process
{
	pass P0
	{
		SetComputeShader( CompileShader( cs_5_0, CS_ComputeLightCullings() ) );
	}
}