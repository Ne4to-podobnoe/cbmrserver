#include "Tools.fx" // Took from GFX\Shaders\Forward

DeclareSampler(ColorMap, 0, BLITZ_FILTER_POINT, BLITZ_ADDR_CLAMP, BLITZ_ADDR_CLAMP, 0.0, 1);
DeclareSampler(DepthMap, 1, BLITZ_FILTER_POINT, BLITZ_ADDR_CLAMP, BLITZ_ADDR_CLAMP, 0.0, 1);

/* Every available semantics
float4x4(MAT_VIEW)
float4x4(MAT_PROJ)
float4x4(MAT_VIEWPROJ)
float4x4(MAT_INVVIEWPROJ)
float4x4(MAT_INVVIEW)
float4x4(MAT_INVPROJ)
float4x4(MAT_PREVVIEWPROJ)
float3(AMBIENT_COLOR) r, g, b (HDR)
float3(FOG_COLOR) r, g, b (HDR)
float2(FOG_PLANE) near, far
float2(CLIP_PLANE) near, far
float3(CAMERA_POSITION) x, y, z
float2(VIEWPORT_SIZE) width, height
int(TIME) GetTickCount()
*/

int Time : TIME;

struct PS_INPUT
{ 
	float4 Pos 				: OUT_POSITION; 
	float2 TexCoord 		: TEXCOORD0;
}; 

PS_INPUT VS_Test(VS_INPUT input)
{ 
	PS_INPUT output; 
	output.Pos = mul(input.Pos, ViewProj); 
	output.TexCoord = GetScreenTexCoords(output.Pos) + halfPixel;
	return output;
}

float4 PS_Test(PS_INPUT input) : OUTPUT(0)
{
	// Time-dependent channel offset strength
	float time = Time * 0.001;
	
    float shift = 0.005 * sin(time * 2.0);
    
    // Sample three color channels with a slight offset along the axes
    float r = Sample2D(ColorMap, input.TexCoord + float2(shift, 0)).r;
    float g = Sample2D(ColorMap, input.TexCoord).g;
    float b = Sample2D(ColorMap, input.TexCoord - float2(shift, 0)).b;
    
    float3 finalColor = float3(r, g, b);
    
    // Add a slight vignetting for the math test
    float dist = distance(input.TexCoord, float2(0.5, 0.5));
    finalColor *= saturate(1.0 - dist * 0.7);

    return float4(finalColor, 1.0);
}

technique Main
{
	pass p0
	{
		Vertex(VS_Test);
		Pixel(PS_Test);
		
		#ifndef D3D11
			ZWriteEnable = false;
			ClipPlaneEnable = false;
			Lighting = false;
		#endif
	}
}