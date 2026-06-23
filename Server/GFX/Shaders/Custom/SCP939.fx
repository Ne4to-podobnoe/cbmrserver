#include "..\Deferred\Tools.fx"

#ifdef D3D11
	#define point_clamp_sampler sampler_state{Filter=MIN_MAG_MIP_POINT;AddressU=Clamp;AddressV=Clamp;}
	texture2D tColorMap : register(t0);
	sampler ColorMap = point_clamp_sampler;
#else
	#define point_clamp_sampler sampler_state{MinFilter=None;MagFilter=None;MipFilter=None;AddressU=Clamp;AddressV=Clamp;AddressW=Clamp;}
	sampler ColorMap : register(s0) = point_clamp_sampler;
#endif

float NPixels = 1.2f;      
float EdgeStrength = 1.5f;
float Threshold = 0.01f;
float GrayPower = 0.7f;

struct PS_INPUT
{ 
	float4 Pos 				: OUT_POSITION; 
	float2 TexCoord 		: TEXCOORD0;
}; 

float GetGray(float4 c)
{
	return dot(c.rgb, float3(0.2126, 0.7152, 0.0722));
}

PS_INPUT VS_EdgeDetect(VS_INPUT input)
{ 
	PS_INPUT output; 
	output.Pos = mul(input.Pos, ViewProj); 
	output.TexCoord = GetScreenTexCoords(output.Pos) + halfPixel;
	return output;
}

float4 PS_EdgeDetect(PS_INPUT input) : OUTPUT(0)
{
	float2 ox = float2(NPixels / ScreenSize.x, 0.0);
	float2 oy = float2(0.0, NPixels / ScreenSize.y);
	float2 ctr = input.TexCoord;

	float g00 = GetGray(Sample2D(ColorMap, ctr - ox - oy));
	float g01 = GetGray(Sample2D(ColorMap, ctr - oy));
	float g02 = GetGray(Sample2D(ColorMap, ctr + ox - oy));
	float g10 = GetGray(Sample2D(ColorMap, ctr - ox));
	float g12 = GetGray(Sample2D(ColorMap, ctr + ox));
	float g20 = GetGray(Sample2D(ColorMap, ctr - ox + oy));
	float g21 = GetGray(Sample2D(ColorMap, ctr + oy));
	float g22 = GetGray(Sample2D(ColorMap, ctr + ox + oy));

	float sx = -g00 - 2.0 * g01 - g02 + g20 + 2.0 * g21 + g22;
	float sy = -g00 + g02 - 2.0 * g10 + 2.0 * g12 - g20 + g22;

	float dist = sqrt(sx * sx + sy * sy);

	float edges = max(0.0, dist - Threshold);

	edges *= EdgeStrength;

	edges = pow(edges, GrayPower);

	float finalEdges = edges / (1.0 + edges);

	float vignet = saturate(1.2 - distance(ctr, float2(0.5, 0.5)) * 1.6);
	finalEdges *= vignet;

	return float4(finalEdges.xxx, 1.0);
}

technique Main
{
	pass p0
	{
		Vertex(VS_EdgeDetect);
		Pixel(PS_EdgeDetect);
		
		#ifndef D3D11
			ZWriteEnable = false;
			ClipPlaneEnable = false;
			Lighting = false;
		#endif
	}
}