//--------------------------------------------------------------------------
//	THIS FILE IS A PRIVATE PROPERTY OF EUCLID LABS STUDIO.
//	THIS SHADER MAY NOT BE USED IN ANY PROJECTS
//	WITHOUT THE EXPLICIT PERMISSION OF THE RIGHTS HOLDER. ANY USE OF THESE FILES
//	IN YOUR PROJECTS REQUIRES PRIOR AGREEMENT WITH THE RIGHTS HOLDER.
//	YOU CAN CONTACT US BY MAILING US ON EUCLIDLABSSTUDIO@GMAIL.COM.
//--------------------------------------------------------------------------

#include "Tools.fx"
#include "PBR.fx"

#ifdef VOLUMETRIC_HQ
	#define RAYMARCH_STEPS 4
#elif defined(VOLUMETRIC_LOW)
	#define RAYMARCH_STEPS 1
#else
	#define RAYMARCH_STEPS 2
#endif

uniform int Time;
uniform float4 LightPos;
uniform float3 LightColor;
uniform float3 LightDirection;
uniform float2 LightCone = float2(1.0, 1.0);
uniform float LightScattering = 1.0;
uniform float ShadowIntensity;
uniform float VolumetricIntensity = 1.0;
uniform float3 EyePos;
uniform float4x4 InvViewProj;
uniform float4x4 LightViewProj : SHADOW_SPOT_MATRIX;
uniform float4x4 ShadowsAdjust;
uniform int ShadowMapAddress : SHADOW_MAP_ADDRESS = 3;
static const float3 pLightColor = SRGBToLinear(LightColor);
static const float4x4 SpotMatrix = mul(LightViewProj, ShadowsAdjust);

DeclareSampler(DepthMap, 0, BLITZ_FILTER_POINT, BLITZ_ADDR_CLAMP, BLITZ_ADDR_CLAMP, 0.0, 1);

#ifdef D3D11
	Texture2DArray tShadowSpot : SHADOW_SPOT_ARRAY;
	TextureCubeArray tShadowPoint : SHADOW_POINT_ARRAY;
	uniform float ShadowSpotSlice : SHADOW_SPOT_SLICE = 0.0;
	uniform float ShadowPointCube : SHADOW_POINT_CUBE = 0.0;

	SamplerComparisonState ShadowMapCmpSpot = sampler_state { Filter = COMPARISON_MIN_MAG_LINEAR_MIP_POINT; AddressU = ShadowMapAddress; AddressV = ShadowMapAddress; AddressW = ShadowMapAddress; BorderColor = float4(1.0, 1.0, 1.0, 1.0); ComparisonFunc = LESS_EQUAL; };
	SamplerComparisonState ShadowMapCmpPoint = sampler_state { Filter = COMPARISON_MIN_MAG_LINEAR_MIP_POINT; AddressU = Clamp; AddressV = Clamp; AddressW = Clamp; BorderColor = float4(1.0, 1.0, 1.0, 1.0); ComparisonFunc = LESS_EQUAL; };
#endif

struct PS_INPUT
{
	float4 Pos : OUT_POSITION;
	float4 ScreenPosition : TEXCOORD0;
	float3 WorldPos : TEXCOORD1;
	float3 Normal : TEXCOORD2;
};

PS_INPUT VertexProcess(VS_INPUT input)
{
	PS_INPUT output;
	output.Pos = mul(input.Pos, WorldViewProj);
	output.ScreenPosition = output.Pos;
	output.WorldPos = mul(input.Pos, World).xyz;
	output.Normal = normalize(mul(input.Normal, World).xyz);
	return output;
}

inline float GetShadowRay(float4 projCoord)
{
#ifdef D3D11
	projCoord.xyz /= projCoord.w;
	return tShadowSpot.SampleCmpLevelZero(ShadowMapCmpSpot, float3(projCoord.xy, ShadowSpotSlice), projCoord.z);
#else
	return 1.0;
#endif
}

inline float GetPointShadowRay(float3 worldPos)
{
#ifdef D3D11
	float3 d = worldPos - LightPos.xyz;
	float dist = length(d);
	float3 ndir = d / max(dist, 1e-6);

	float range = 1.0 / max(LightPos.w, 1e-6);
	float nearZ = max(0.001, 0.005 * range);
	float Qscale = range / max(range - nearZ, 1e-6);

	float depth = dist * max(abs(ndir.x), max(abs(ndir.y), abs(ndir.z)));
	float ref = Qscale - Qscale * nearZ / max(depth, nearZ);
	return tShadowPoint.SampleCmpLevelZero(ShadowMapCmpPoint, float4(ndir, ShadowPointCube), ref);
#else
	return 1.0;
#endif
}

inline float CalculateAttenuation(float3 lightVec, out float3 lightDir)
{
	float distSqr = dot(lightVec, lightVec);
	float len = sqrt(max(distSqr, 1e-6));
	lightDir = lightVec / len;

	float radiusSqr = 1.0 / max(LightPos.w * LightPos.w, 0.0001);
	float attenuation = 1.0 / (distSqr + 1.0);
	float windowing = pow(saturate(1.0 - pow(distSqr / radiusSqr, 2)), 2);

	return attenuation * windowing;
}

inline float3 CalculateScattering(float3 volumePos, float3 volumeNormal, float3 worldPos, float3 eyeDir)
{
	const float3 volumeDir = normalize(volumePos - EyePos);
	const float AttenPow = 1.0 - pow(1.0 - saturate(dot(volumeDir, volumeNormal)), 1.0);
	return float4(pLightColor, 1) * saturate(GetScattering(EyePos, eyeDir, LightPos.xyz) * LightScattering * 0.001 * AttenPow);
}

inline float3 RaymarchLight(float3 volumePos, float3 volumeNormal, float3 worldPos, float2 iScreenPos)
{
	float3 rayVec = worldPos - EyePos;
	float3 accumulated = 0.0;

	float rayLength = length(rayVec);
	float3 rayDirection = rayVec / max(rayLength, 1e-6);

	float stepSize = rayLength / RAYMARCH_STEPS;
	float3 step = rayDirection * stepSize;

	float3 currentposition = EyePos + step * DITHER_PATTERN[clamp(int(iScreenPos.x) % 4, 0, 3)][clamp(int(iScreenPos.y) % 4, 0, 3)];

	#if defined(SPOTLIGHT)
		float4 projCoord = mul(float4(currentposition, 1.0), SpotMatrix);
		float4 projStep = mul(float4(step, 0.0), SpotMatrix);
	#endif

	[loop]for (int i = 0; i < RAYMARCH_STEPS; ++i)
	{
		float3 lightDir;
		float3 intensity = CalculateAttenuation(LightPos.xyz - currentposition, lightDir);
		float shadow;

		#if defined(SPOTLIGHT)
			float coneCos = dot(-lightDir, LightDirection);
			intensity *= saturate((coneCos - LightCone.x) / max(LightCone.y - LightCone.x, 1e-4));
			shadow = GetShadowRay(projCoord);
		#else
			shadow = GetPointShadowRay(currentposition);
		#endif

		float scatteringDot = dot(rayDirection, lightDir);
		float scattering = max(ComputeScattering(0.8, 7.0, scatteringDot), 0.25) * 0.3;

		float dust = DustNoise(currentposition * 3.0, Time * 0.00035);
		dust = dust * dust * dust * 2.5;

		accumulated += intensity * shadow * scattering * (1.0 + dust);

		currentposition += step;

		#if defined(SPOTLIGHT)
			projCoord += projStep;
		#endif
	}

	accumulated *= stepSize * pLightColor * LightScattering * 0.1 * VolumetricIntensity;

	return lerp(accumulated, CalculateScattering(volumePos, volumeNormal, worldPos, rayVec), ShadowIntensity);
}

inline float3 GetVolumetricWorldPos(float3 sceneWorldPos, float3 volumeWorldPos)
{
	float3 rayDir = sceneWorldPos - EyePos;
	float sceneDist = length(rayDir);
	float volumeDist = length(volumeWorldPos - EyePos);
	return EyePos + rayDir * saturate(volumeDist / (sceneDist + 0.0001));
}

float4 VolumetricProcess(PS_INPUT input) : OUTPUT(0)
{
	float2 texCoords = GetScreenTexCoords(input.ScreenPosition);
	float3 sceneWorldPos = GetWorldPosition(texCoords, Sample2DLod0(DepthMap, texCoords).r, InvViewProj);

	float3 raymarchWorldPos = GetVolumetricWorldPos(sceneWorldPos, input.WorldPos);

	return float4(RaymarchLight(input.WorldPos, input.Normal, raymarchWorldPos, texCoords * ScreenSize), 1.0);
}

#ifdef D3D11
	DepthStencilState DepthState
	{
		DepthEnable = FALSE;
		DepthWriteMask = ZERO;
		DepthFunc = LESS_EQUAL;
	};

	RasterizerState RasterState
	{
		CullMode = FRONT;
	};
#endif

technique Volumetric
{
	pass Main
	{
		Vertex(VertexProcess);
		Pixel(VolumetricProcess);

		#ifdef D3D11
			SetDepthStencilState(DepthState, 0);
			SetRasterizerState(RasterState);
		#else
			CullMode = CW;
			ZWriteEnable = false;
			Lighting = false;
		#endif
	}
}
