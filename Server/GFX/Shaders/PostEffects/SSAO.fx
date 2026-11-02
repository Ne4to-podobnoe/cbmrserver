//--------------------------------------------------------------------------
//	THIS FILE IS A PRIVATE PROPERTY OF EUCLID LABS STUDIO.
//	THIS SHADER MAY NOT BE USED IN ANY PROJECTS
//	WITHOUT THE EXPLICIT PERMISSION OF THE RIGHTS HOLDER. ANY USE OF THESE FILES
//	IN YOUR PROJECTS REQUIRES PRIOR AGREEMENT WITH THE RIGHTS HOLDER.
//	YOU CAN CONTACT US BY MAILING US ON EUCLIDLABSSTUDIO@GMAIL.COM.
//--------------------------------------------------------------------------

#include "..\Forward\Tools.fx"

#define NUM_SAMPLES 4
static const float INV_SAMPLES = 1.0 / (NUM_SAMPLES * 4);

uniform float SSAOStrength = 1.f;
uniform float SSAORadius = 0.15f;
uniform float SSAOBias = 0.1f;
uniform float SSAOMaxDistance = 1.5f;
uniform float BloomThreshold;
uniform float4x4 InvViewProj;
uniform float3 CameraPosition;
uniform float FarClip;
float2 FogPlane : FOG_PLANE;
static const float FarClipSqr = FarClip * FarClip;

static const float2 SSAOSamples[NUM_SAMPLES] =
{
	float2(1,0),
	float2(-1,0), 
	float2(0,1),
	float2(0,-1)
};

DeclareSampler(ColorMap, 0, BLITZ_FILTER_LINEAR, BLITZ_ADDR_CLAMP, BLITZ_ADDR_CLAMP, 0.0, 1);
DeclareSampler(DepthMap, 1, BLITZ_FILTER_POINT, BLITZ_ADDR_CLAMP, BLITZ_ADDR_CLAMP, 0.0, 1);

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

inline float3 GetPosition(in float2 uv)
{
	return GetWorldPosition(uv, Sample2D(DepthMap, uv).r, InvViewProj);
}

inline float3 GetNormal(float2 uv)
{
    float2 TexelSize = 1.0 / ScreenSize;
    float2 uvMin = TexelSize * 0.5;
    float2 uvMax = 1.0 - uvMin;

    float3 pC = GetPosition(uv);

    float2 uvL = clamp(uv + float2(-TexelSize.x, 0), uvMin, uvMax);
    float2 uvR = clamp(uv + float2( TexelSize.x, 0), uvMin, uvMax);
    float2 uvD = clamp(uv + float2(0, -TexelSize.y), uvMin, uvMax);
    float2 uvU = clamp(uv + float2(0,  TexelSize.y), uvMin, uvMax);

    float sL = Sample2D(DepthMap, uvL).r;
    float sR = Sample2D(DepthMap, uvR).r;
    float sD = Sample2D(DepthMap, uvD).r;
    float sU = Sample2D(DepthMap, uvU).r;

    bool skyL = IsSkyDepth(sL) > 0.5;
    bool skyR = IsSkyDepth(sR) > 0.5;
    bool skyD = IsSkyDepth(sD) > 0.5;
    bool skyU = IsSkyDepth(sU) > 0.5;

    float3 pL = skyL ? pC : GetWorldPosition(uvL, sL, InvViewProj);
    float3 pR = skyR ? pC : GetWorldPosition(uvR, sR, InvViewProj);
    float3 pD = skyD ? pC : GetWorldPosition(uvD, sD, InvViewProj);
    float3 pU = skyU ? pC : GetWorldPosition(uvU, sU, InvViewProj);

    float dC = length(pC - CameraPosition);
    float dL = length(pL - CameraPosition);
    float dR = length(pR - CameraPosition);
    float dD = length(pD - CameraPosition);
    float dU = length(pU - CameraPosition);

    float tol = 0.02 * dC + 0.05;
    bool vL = !skyL && abs(dL - dC) <= tol;
    bool vR = !skyR && abs(dR - dC) <= tol;
    bool vD = !skyD && abs(dD - dC) <= tol;
    bool vU = !skyU && abs(dU - dC) <= tol;

    float3 dx;
    if (vL && vR)      dx = (pR - pL) * 0.5;
    else if (vL)       dx = pC - pL;
    else if (vR)       dx = pR - pC;
    else               dx = abs(dR - dC) < abs(dL - dC) ? pR - pC : pC - pL;

    float3 dy;
    if (vD && vU)      dy = (pU - pD) * 0.5;
    else if (vU)       dy = pU - pC;
    else if (vD)       dy = pC - pD;
    else               dy = abs(dU - dC) < abs(dD - dC) ? pU - pC : pC - pD;

    float3 n = cross(dx, dy);
    float l = length(n);
    if (l < 1e-10) return normalize(CameraPosition - pC);
    n /= l;

    return dot(n, CameraPosition - pC) < 0.0 ? -n : n;
}

inline float GetLength(float3 src, float3 dest)
{
	const float3 diff = src - dest;
    return dot(diff, diff); 
}

inline float CalculateAO(in float2 centerUV, in float2 uv, in float3 position, in float3 normal) 
{
	float2 sampleUV = centerUV + uv;
	if (any(sampleUV < 0.0) || any(sampleUV > 1.0)) return 0.0;

	float3 diff = GetPosition(sampleUV) - position;
	float scale = length(diff);
	float falloff = smoothstep(SSAOMaxDistance, 0.0, scale);
	float3 nd = diff / scale;
	return saturate(dot(normal, nd) - SSAOBias) * falloff * SSAOStrength;
}

float4 SSAOProcess(PS_INPUT input) : OUTPUT(0)
{ 
	float3 position = GetWorldPosition(input.TexCoord, Sample2D(DepthMap, input.TexCoord).r, InvViewProj);
	float len = GetLength(CameraPosition, position);
	if(len > FarClipSqr) return 1.0;

	float3 normal = GetNormal(input.TexCoord);
	float noise = InterleavedGradientNoise(input.TexCoord * (ScreenSize / 8));
	float2 randomNormal;
	sincos(noise * 6.283185, randomNormal.y, randomNormal.x);

	float radius = max(SSAORadius / sqrt(len), 8.0 / ScreenSize.y);
	
	float ao = 0.0f; 

	[unroll]for (int j = 0; j < NUM_SAMPLES; ++j) 
	{
		float2 coord1 = reflect(SSAOSamples[j], randomNormal) * radius; 
		float2 coord2 = float2(coord1.x * 0.7 - coord1.y * 0.7, coord1.x * 0.7 + coord1.y * 0.7); 

		ao += CalculateAO(input.TexCoord, coord1 * 0.25, position, normal); 
		ao += CalculateAO(input.TexCoord, coord2 * 0.5, position, normal); 
		ao += CalculateAO(input.TexCoord, coord1 * 0.75, position, normal); 
		ao += CalculateAO(input.TexCoord, coord2, position, normal);
	}

	float dist = sqrt(len);
	float fog = saturate((dist - FogPlane.x) / max(FogPlane.y - FogPlane.x, 0.0001));
	float farFade = 1.0 - GetFade(len, FarClipSqr * 0.8, FarClipSqr);

	return lerp(1.0 - ao * INV_SAMPLES, 1.0, max(fog, farFade));
}

technique SSAO
{
	pass p0
	{
		Vertex(VertexProcess);
		Pixel(SSAOProcess);
	}
}
