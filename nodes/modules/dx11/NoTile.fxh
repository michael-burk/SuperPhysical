// Shader code by Inigo Quilez
//http://www.iquilezles.org/www/articles/texturerepetition/texturerepetition.htm
float4 hash4( float2 p ) { return frac(sin(float4( 1.0+dot(p,float2(37.0,17.0)), 
                                              		2.0+dot(p,float2(11.0,47.0)),
                                              		3.0+dot(p,float2(41.0,29.0)),
                                             		4.0+dot(p,float2(23.0,31.0))))*103.0); }


float4 textureNoTile(Texture2D tex, in float2 uv )
{
    float2 p = floor( uv );
    float2 f = frac( uv );
	
    // derivatives (for correct mipmapping)
    float2 myddx = ddx( uv );
    float2 myddy = ddy( uv );
    
    // voronoi contribution
    float4 va = 0.0;
    float wt = 0.0;
    for( int j=-1; j<=1; j++ )
    for( int i=-1; i<=1; i++ )
    {
        float2 g = float2( float(i), float(j) );
        float4 o = hash4( p + g );
        float2 r = g - f + o.xy;
        float d = dot(r,r);
        float w = exp(-5.0*d );
        float4 c = tex.SampleGrad( g_samLinear, uv + o.zw, myddx, myddy );
        va += w*c;
        wt += w;
    }
	
    // normalization
    return va/wt;
}

float4 getTexel( float3 p, Texture2DArray tex )
{
    p.xy = p.xy*R + 0.5;

    float2 i = floor( p.xy);
    float2 f =  p.xy - i;
    f = f*f*f*(f*(f*6.0-15.0)+10.0);
      p.xy.xy = i + f;

     p.xy = ( p.xy - 0.5)/R;
    return tex.SampleLevel(shadowSampler, p, 0);
}