
float4x4 tW : WORLD;
float4x4 tVP: VIEWPROJECTION;
float4x4 tV:  VIEW;

float4 cAmb <bool color=true;>;
StructuredBuffer<float4x4> world;
uint IntanceStartIndex = 0;
int oid : DRAWINDEX;

struct VS_IN
{
	uint ii : SV_InstanceID;
	float4 PosO : POSITION;
	float3 NormO : NORMAL;
};

struct vs2ps
{
	uint ii : SV_InstanceID;
    float4 PosWVP: SV_POSITION;
	uint id : TEXCOORD0;
};

struct PS_OUT
{
//	float4 color :SV_Target0;
	uint id : SV_Target0;
};

vs2ps VS(VS_IN input)
{
    //inititalize all fields of output struct with 0
    vs2ps Out = (vs2ps)0;
	
	
	/*Here we look up for local world transform using
	the object instance id and start offset*/
	float4x4 wo = world[input.ii + IntanceStartIndex];
	
	/* the WORLD transform applies to the 
	whole batch in case of instancing, so we can transform 
	all the batch at once using it */
	wo = mul(world[input.ii + IntanceStartIndex],tW);
	
	
	float4x4 wvp = mul(wo,tVP);

    //position (projected)
    Out.PosWVP  = mul(input.PosO,wvp);
	Out.id = oid + 1;
	Out.ii = (input.ii + IntanceStartIndex + 1);
    return Out;
}


PS_OUT PS_MRT(vs2ps In)
{
	PS_OUT res;
	
//    res.color = cAmb;
	res.id = (int)In.ii;

    return  res;
}

technique10 RenderMRT
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetPixelShader( CompileShader( ps_4_0, PS_MRT() ) );
	}
}






