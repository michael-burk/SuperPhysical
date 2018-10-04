float2 r2d(float2 x,float a){a*=acos(-1)*2;return float2(cos(a)*x.x+sin(a)*x.y,cos(a)*x.y-sin(a)*x.x);}

float4x4 tPI:PROJECTIONINVERSE;
float3 UVtoEYE(float2 UV){return normalize(mul(float4(mul(float4((UV.xy*2-1)*float2(1,-1),0,1),tPI).xy,1,0),tVI).xyz);}

float sdBox( float3 p, float3 b )
{
  float3 d = abs(p) - b;
  return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

float sdTorus( float3 p, float2 t )
{
  float2 q = float2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}

float4x4 transform;


float sceneSDF (float3 p)
{	
	p = mul(float4(p,1), transform);
	return sdTorus(p, float2(1,.1));
//	return sdBox(p+float3(0,0,0),float3(10,.2,5) * .1);
}


static const float MAX_DIST = 10.0;
static const float EPSILON = .001;


float raymarch (in float3 eye, in float3 dir, uint steps)
{
	float t = 0.0;
	float dist = .01;
	for (uint i = 0 ; i < steps ; i++)
	{	
		if(dist < EPSILON || dist > MAX_DIST) break;
		dist = sceneSDF (eye + dir*t);
		t += dist * 0.5;
	}
	return t;

}

float3 calcNormal( in float3 pos )
{
	float3 eps = float3( 0.1, 0.0, 0.0 );
	float3 nor = float3(
	    sceneSDF(pos+eps.xyy) - sceneSDF(pos-eps.xyy),
	    sceneSDF(pos+eps.yxy) - sceneSDF(pos-eps.yxy),
	    sceneSDF(pos+eps.yyx) - sceneSDF(pos-eps.yyx) );
	return normalize(nor);
}
