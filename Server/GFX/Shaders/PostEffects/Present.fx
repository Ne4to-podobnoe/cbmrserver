//--------------------------------------------------------------------------
//	THIS FILE IS A PRIVATE PROPERTY OF EUCLID LABS STUDIO.
//	THIS SHADER MAY NOT BE USED IN ANY PROJECTS
//	WITHOUT THE EXPLICIT PERMISSION OF THE RIGHTS HOLDER. ANY USE OF THESE FILES
//	IN YOUR PROJECTS REQUIRES PRIOR AGREEMENT WITH THE RIGHTS HOLDER.
//	YOU CAN CONTACT US BY MAILING US ON EUCLIDLABSSTUDIO@GMAIL.COM.
//--------------------------------------------------------------------------

#include "..\Forward\Tools.fx"

DeclareSampler(ColorMap, 0, BLITZ_FILTER_LINEAR, BLITZ_ADDR_CLAMP, BLITZ_ADDR_CLAMP, 0.0, 1);

struct PS_INPUT
{ 
	float4 Pos 				: OUT_POSITION; 
	float2 TexCoord 		: TEXCOORD0;
}; 

PS_INPUT VertexProcess(VS_INPUT input)
{ 
	PS_INPUT output; 
	output.Pos = mul(input.Pos, ViewProj); 
	output.TexCoord = GetScreenTexCoords(output.Pos) + halfPixel;
	return output;
}

static const float AgXExposure = 0.83;
static const float AgXOutputGamma = 0.67;
static const float AgXLift = 0;

static const float3x3 AgXInsetMatrix = float3x3(
	0.856627153315983, 0.137318972929847, 0.11189821299995,
	0.0951212405381588, 0.761241990602591, 0.0767994186031903,
	0.0482516061458583, 0.101439036467562, 0.811302368396859);

static const float3x3 AgXOutsetMatrix = float3x3(
	1.1271005818144368, -0.1413297634984383, -0.14132976349843826,
	-0.11060664309660323, 1.157823702216272, -0.11060664309660294,
	-0.016493938717834573, -0.016493938717834257, 1.2519364065950405);

static const float3x3 LinearSRGBToLinearRec2020 = float3x3(
	0.6274, 0.0691, 0.0164,
	0.3293, 0.9195, 0.0880,
	0.0433, 0.0113, 0.8956);

static const float3x3 LinearRec2020ToLinearSRGB = float3x3(
	1.6605, -0.1246, -0.0182,
	-0.5876, 1.1329, -0.1006,
	-0.0728, -0.0083, 1.1187);

inline float3 AgXDefaultContrastApprox(float3 x)
{
	float3 x2 = x * x;
	float3 x4 = x2 * x2;
	return 15.5 * x4 * x2 - 40.14 * x4 * x + 31.96 * x4 - 6.868 * x2 * x + 0.4298 * x2 + 0.1191 * x - 0.00232;
}

inline float3 AgXTonemap(float3 color)
{
	const float AgxMinEv = -12.47393;
	const float AgxMaxEv = 4.026069;
	color *= AgXExposure;
	color = mul(color, LinearSRGBToLinearRec2020);
	color = mul(color, AgXInsetMatrix);
	color = max(color, 1e-10);
	color = log2(color);
	color = (color - AgxMinEv) / (AgxMaxEv - AgxMinEv);
	color = saturate(color);
	color = AgXDefaultContrastApprox(color);
	color = mul(color, AgXOutsetMatrix);
	color = pow(max(color, 0.0), 2.2);
	color = mul(color, LinearRec2020ToLinearSRGB);
	color = saturate(color);
	color = pow(max(color, 0.0) + AgXLift, AgXOutputGamma);
	return color;
}

float4 Present(PS_INPUT input) : OUTPUT(0)
{
    return float4(Sample2DLod0(ColorMap, input.TexCoord).rgb, 1.0);
}

float4 PresentACES(PS_INPUT input) : OUTPUT(0)
{
    float3 color = Sample2DLod0(ColorMap, input.TexCoord).rgb;
    color = pow(max(ACESFilm(color), 0.0), 0.707);
    return float4(LinearToSRGB(color), 1.0);
}

float4 PresentAgX(PS_INPUT input) : OUTPUT(0)
{
    float3 color = Sample2DLod0(ColorMap, input.TexCoord).rgb;
    return float4(LinearToSRGB(AgXTonemap(color)), 1.0);
}

float4 PresentPow(PS_INPUT input) : OUTPUT(0)
{
    float3 color = Sample2DLod0(ColorMap, input.TexCoord).rgb;
    color = pow(color, 0.85);
    return float4(LinearToSRGB(color), 1.0);
}

technique Main
{
	pass p0
	{
		Vertex(VertexProcess);
		Pixel(Present);
	}
}

technique ACES
{
	pass p0
	{
		Vertex(VertexProcess);
		Pixel(PresentACES);
	}
}

technique AgX
{
	pass p0
	{
		Vertex(VertexProcess);
		Pixel(PresentAgX);
	}
}

technique Pow
{
	pass p0
	{
		Vertex(VertexProcess);
		Pixel(PresentPow);
	}
}
