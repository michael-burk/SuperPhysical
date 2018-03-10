/**
 * The SSLRConstantBuffer.
 * Defines constants used to implement SSLR cone traced screen-space reflections.
 */

cbuffer cbSSLR : register(b0)
{
    float2 cb_depthBufferSize; // dimensions of the z-buffer
    float cb_zThickness; // thickness to ascribe to each pixel in the depth buffer
    float cb_nearPlaneZ; // the camera's near z plane

    float cb_stride; // Step in horizontal or vertical pixels between samples. This is a float
    // because integer math is slow on GPUs, but should be set to an integer >= 1.
    float cb_maxSteps; // Maximum number of iterations. Higher gives better images but may be slow.
    float cb_maxDistance; // Maximum camera-space distance to trace before returning a miss.
    float cb_strideZCutoff; // More distant pixels are smaller in screen space. This value tells at what point to
    // start relaxing the stride to give higher quality reflections for objects far from
    // the camera.

    float cb_numMips; // the number of mip levels in the convolved color buffer
    float cb_fadeStart; // determines where to start screen edge fading of effect
    float cb_fadeEnd; // determines where to end screen edge fading of effect
//    float cb_sslr_padding0; // padding for alignment
	
	float texelWidth;
	float texelHeight;
};

static const float4x4 viewToTextureSpaceMatrix = 
{ 	0.5f, 0.0f, 0.0f, 0.5f,
	0.0f, -0.5f, 0.0f, 0.5f,
	0.0f, 0.0f, 1.0f, 0.0f,
	0.0f, 0.0f, 0.0f, 1.0f
	
};