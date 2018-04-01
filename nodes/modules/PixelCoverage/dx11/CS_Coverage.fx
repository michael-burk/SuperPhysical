//Texture is as uint
Texture2D<uint> ObjectTexture;
Texture2D<float4> texture2;
float2 mousePos;

//One element per object
RWStructuredBuffer<uint> RWHitCountBuffer : BACKBUFFER;

[numthreads(64, 1, 1)]
void CS_Clear( uint3 i : SV_DispatchThreadID)
{ 
	RWHitCountBuffer[i.x] = 0;
}

[numthreads(8, 8, 1)]
void CS( uint3 i : SV_DispatchThreadID)
{ 
	
	uint w,h, dummy;
	ObjectTexture.GetDimensions(0,w,h,dummy);
	
	//Safeguard to avoid sampling out of texture
	if (i.x >= w || i.y >= h) { return; }
	
	/*Object ID starts at 1, 0 means no object written,
	so we grab object id for this texture */
	uint objectid = ObjectTexture[i.xy];
	float4 alpha = texture2[i.xy];
//	if (objectid > 0 && alpha.r > .0)
	if (objectid > 0 && length(i.xy-mousePos) <= 1)
//	if (objectid > 0)
	{
		/*Add 1 to the object buffer,
		InterlockedAdd will guarantee the write to be atomic*/
		uint oldval;
		InterlockedAdd(RWHitCountBuffer[objectid-1],1,oldval);
	}

}

technique11 Clear
{
	pass P0
	{
		SetComputeShader( CompileShader( cs_5_0, CS_Clear() ) );
	}
}

technique11 ProcessTexture
{
	pass P0
	{
		SetComputeShader( CompileShader( cs_5_0, CS() ) );
	}
}








