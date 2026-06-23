#include "Tools.fx" // Took from GFX\Shaders\Deferred

#ifdef D3D11
	#define point_clamp_sampler sampler_state{Filter=MIN_MAG_MIP_POINT;AddressU=Clamp;AddressV=Clamp;}
	
	texture2D tColorMap : register(t0); // RGBA16F (main color)
	sampler ColorMap = point_clamp_sampler;
	
	texture2D tAlbedoMap : register(t1); // RGBA16F (diffuse.rgb, fogFactor)
	sampler AlbedoMap = point_clamp_sampler;
	
	texture2D tNormalMap : register(t2); // RGBA16F (normalized normal * roughness, metallic)
	sampler NormalMap = point_clamp_sampler;
	
	texture2D tDepthMap : register(t3); // R32F (depth z/w)
	sampler DepthMap = point_clamp_sampler;
#else
	#define point_clamp_sampler sampler_state{MinFilter=None;MagFilter=None;MipFilter=None;AddressU=Clamp;AddressV=Clamp;AddressW=Clamp;}

	sampler ColorMap : register(s0) = point_clamp_sampler; // RGBA16F (main color)
	sampler AlbedoMap : register(s1) = point_clamp_sampler; // RGBA16F (diffuse.rgb, fogFactor)
	sampler NormalMap : register(s2) = point_clamp_sampler; // RGBA16F (normalized normal * roughness, metallic)
	sampler DepthMap : register(s3) = point_clamp_sampler; // R32F (depth z/w)
#endif

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