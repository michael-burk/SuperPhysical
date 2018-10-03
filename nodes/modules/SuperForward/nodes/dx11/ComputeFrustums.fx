//@author: Johannes Schmidt || Kopffarben GbR
//@help: ComputeFrustrum
//@tags: forwardPlus
//@credits: Jeremiah van Oosten

#ifndef FRUSTRUM
#define FRUSTRUM 1
#endif

#ifndef FORWARDPLUS_FXH
#include "forwardplus.fxh"
#endif
  

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

// View space frustums for the grid cells.
RWStructuredBuffer<Frustum> out_Frustums : BACKBUFFER;

// A kernel to compute frustums for the grid
// This kernel is executed once per grid cell. Each thread
// computes a frustum for a grid cell.
[numthreads( BLOCK_SIZE, BLOCK_SIZE, 1 )]
void CS_ComputeFrustums( ComputeShaderInput IN )
{ 
    // View space eye position is always at the origin.
    const float3 eyePos = float3( 0, 0, 0 );

    // Compute 4 points on the far clipping plane to use as the 
    // frustum vertices.
    float4 screenSpace[4];
    // Top left point
    screenSpace[0] = float4( IN.dispatchThreadID.xy * BLOCK_SIZE,  1.0f, 1.0f );
    // Top right point
    screenSpace[1] = float4( float2( IN.dispatchThreadID.x + 1, IN.dispatchThreadID.y ) * BLOCK_SIZE,  1.0f, 1.0f );
    // Bottom left point
    screenSpace[2] = float4( float2( IN.dispatchThreadID.x, IN.dispatchThreadID.y + 1 ) * BLOCK_SIZE,  1.0f, 1.0f );
    // Bottom right point
    screenSpace[3] = float4( float2( IN.dispatchThreadID.x + 1, IN.dispatchThreadID.y + 1 ) * BLOCK_SIZE,  1.0f, 1.0f );

    float3 viewSpace[4];
    // Now convert the screen space points to view space
    for ( int i = 0; i < 4; i++ )
    {
        viewSpace[i] = ScreenToV4View( screenSpace[i] ).xyz;
    }

    // Now build the frustum planes from the view space points
    Frustum frustum;

    // Left plane
    frustum.planes[0] = ComputePlane( eyePos, viewSpace[0], viewSpace[2] );
    // Right plane
    frustum.planes[1] = ComputePlane( eyePos, viewSpace[3], viewSpace[1] );
    // Top plane
    frustum.planes[2] = ComputePlane( eyePos, viewSpace[1], viewSpace[0] );
    // Bottom plane
    frustum.planes[3] = ComputePlane( eyePos, viewSpace[2], viewSpace[3] );

    // Store the computed frustum in global memory (if our thread ID is in bounds of the grid).
    if ( IN.dispatchThreadID.x < numThreads.x && IN.dispatchThreadID.y < numThreads.y )
    {
        uint index = IN.dispatchThreadID.x + ( IN.dispatchThreadID.y * numThreads.x );
        out_Frustums[index] = frustum;
    }
}

technique11 Process
{
	pass P0
	{
		SetComputeShader( CompileShader( cs_5_0, CS_ComputeFrustums() ) );
	}
}