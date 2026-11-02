//--------------------------------------------------------------------------
//	THIS FILE IS A PRIVATE PROPERTY OF EUCLID LABS STUDIO.
//	THIS SHADER MAY NOT BE USED IN ANY PROJECTS
//	WITHOUT THE EXPLICIT PERMISSION OF THE RIGHTS HOLDER. ANY USE OF THESE FILES
//	IN YOUR PROJECTS REQUIRES PRIOR AGREEMENT WITH THE RIGHTS HOLDER.
//	YOU CAN CONTACT US BY MAILING US AT EUCLIDLABSSTUDIO@GMAIL.COM.
//--------------------------------------------------------------------------

#include "..\Forward\Tools.fx"

uniform float4x4 InvViewProj;
uniform float3 CameraPosition;
uniform float FarClip;

uniform float3 SunDirection    = float3(0.0, -0.5, 0.5);
uniform float3 SunColor        = float3(1.0, 0.9, 0.78);

uniform float SunDiscAngle      = 0.0256;
uniform float SunDiscIntensity  = 5.5;
uniform float SunGlowAngle      = 0.0401;
uniform float SunGlowIntensity  = 0.40;
uniform float SunAuraAngle      = 0.1093;
uniform float SunAuraIntensity  = 0.015;
uniform float SunSizeScale      = 1.4;
uniform float SunShaftIntensity = 0.8;
uniform float SunShaftRadius    = 1;
uniform int   SunShaftSteps     = 24;

int Time : TIME;

DeclareSampler(DepthMap, 1, BLITZ_FILTER_POINT, BLITZ_ADDR_CLAMP, BLITZ_ADDR_CLAMP, 0.0, 1);

struct PS_INPUT
{
	float4 Pos : OUT_POSITION;
	float2 TexCoord : TEXCOORD0;
};

PS_INPUT VertexProcess(VS_INPUT input)
{
	PS_INPUT output;
	output.Pos = mul(input.Pos, ViewProj);
	output.TexCoord = GetScreenTexCoords(output.Pos) + halfPixel;
	return output;
}

static const float3 pSunColor = SRGBToLinear(SunColor);

inline float PixelAngle(float3 rayDir)
{
	return max(length(ddx(rayDir)), length(ddy(rayDir)));
}

inline float2 GetSunScreenPosition(float3 rayDir, out float sunCos)
{
	float3 R = InvViewProj[0].xyz;
	float3 U = InvViewProj[1].xyz;
	float3 F = normalize(cross(R, U));

	if (dot(F, rayDir) < 0.0) F = -F;

	float3 sunDir = normalize(-SunDirection);
	sunCos = dot(sunDir, F);

	float2 ndc = float2(0.0, 0.0);
	if (sunCos > 0.0001)
	{
		float2 invFocalSq = float2(1.0 / dot(R, R), 1.0 / dot(U, U));
		ndc = float2(dot(sunDir, R) * invFocalSq.x, dot(sunDir, U) * invFocalSq.y) / sunCos;
	}
	return 0.5 * (float2(ndc.x, -ndc.y) + 1.0);
}

inline float GetSunSkyMaskPoint(float2 uv)
{
	return IsSkyDepth(Sample2DLod0(DepthMap, uv).r);
}

inline float GetSunSkyMask(float2 uv)
{
	float2 stepUV = 1.0 / ScreenSize;

	float m = GetSunSkyMaskPoint(uv + float2(-stepUV.x, -stepUV.y));
	m += GetSunSkyMaskPoint(uv + float2( stepUV.x, -stepUV.y));
	m += GetSunSkyMaskPoint(uv + float2(-stepUV.x,  stepUV.y));
	m += GetSunSkyMaskPoint(uv + float2( stepUV.x,  stepUV.y));

	return m * 0.25;
}

inline float GetSunVisibility(float2 sunUV, float discRadiusPx)
{
	float r = max(discRadiusPx, 1.0);
	float2 offX = float2(r * 0.5, 0.0);
	float2 offY = float2(0.0, r * 0.5);

	float v = GetSunSkyMaskPoint(sunUV);
	v = max(v, GetSunSkyMaskPoint(sunUV + offX));
	v = max(v, GetSunSkyMaskPoint(sunUV - offX));
	v = max(v, GetSunSkyMaskPoint(sunUV + offY));
	v = max(v, GetSunSkyMaskPoint(sunUV - offY));

	return v;
}

inline float3 GetSunShafts(float2 texCoords, float2 sunUV, float sunCos, float3 sunColor, float2 screenSizePx, float glowRadiusPx)
{
	float3 shafts = float3(0.0, 0.0, 0.0);

	float maxDim = max(screenSizePx.x, screenSizePx.y);
	float2 delta = texCoords - sunUV;
	float distPx = length(delta * screenSizePx);
	float rayRadiusPx = SunShaftRadius * maxDim;

	if (distPx > 1.0 && distPx < rayRadiusPx)
	{
		int steps = max(SunShaftSteps, 1);
		float2 stepVec = delta / (float)steps;

		float2 sampleUV = texCoords - stepVec * (InterleavedGradientNoise(texCoords * screenSizePx) * 0.8);
		float acc = 0.0;

		float invSourceRSq = 1.0 / max(glowRadiusPx * glowRadiusPx, 1e-4);

		[loop]
		for (int i = 0; i < steps; ++i)
		{
			sampleUV -= stepVec;

			float2 dUVPx = (sampleUV - sunUV) * screenSizePx;
			float dSSq = dot(dUVPx, dUVPx) * invSourceRSq;
			float glow = exp(-2.0 * dSSq);

			acc += GetSunSkyMask(sampleUV) * glow;
		}

		float fade = pow(saturate(1.0 - distPx / rayRadiusPx), 2.0);
		float height = saturate(sunCos * 2.0);
		shafts = sunColor * (acc / (float)steps) * fade * height * SunShaftIntensity * GetSunSkyMaskPoint(texCoords);
	}
	return shafts;
}

inline float3 GetSunContribution(float2 texCoords, float3 rayDir, float pixelAngle)
{
	float3 contribution = float3(0.0, 0.0, 0.0);

	float skyMask = GetSunSkyMaskPoint(texCoords);
	if (skyMask <= 0.0) return contribution;

	float sunCos;
	float2 sunUV = GetSunScreenPosition(rayDir, sunCos);
	if (sunCos <= 0.0001) return contribution;

	float2 screenSizePx = ScreenSize;

	float discR = SunDiscAngle * SunSizeScale;
	float glowR = SunGlowAngle * SunSizeScale;
	float auraR = SunAuraAngle * SunSizeScale;

	float3 sunDir = normalize(-SunDirection);
	float3 sunUpRaw = float3(0.0, 1.0, 0.0) - sunDir * dot(sunDir, float3(0.0, 1.0, 0.0));
	float3 sunUp = (dot(sunUpRaw, sunUpRaw) > 1e-6) ? normalize(sunUpRaw) : float3(0.0, 0.0, 1.0);
	float3 sunSide = normalize(cross(sunDir, sunUp));

	float cosTheta = dot(rayDir, sunDir);
	float theta = acos(clamp(cosTheta, -1.0, 1.0));

	float3 vPerp = rayDir - sunDir * cosTheta;
	float perpLen = length(vPerp);
	float3 vFlat = (perpLen > 1e-6) ? vPerp / perpLen : float3(0.0, 0.0, 0.0);

	float angUp = dot(vFlat, sunUp) * theta;
	float angSide = dot(vFlat, sunSide) * theta;

	float edge = min(min(sunUV.x, sunUV.y), min(1.0 - sunUV.x, 1.0 - sunUV.y));
	float auraRadiusPx = auraR / max(pixelAngle, 1e-6);
	float sunRadiusUV = (auraRadiusPx / max(screenSizePx.y, 1.0)) * 1.2;
	float screenFade = smoothstep(-sunRadiusUV, 0.02, edge);

	if (screenFade <= 0.0) return contribution;

	float sunVis = GetSunVisibility(sunUV, discR / max(pixelAngle, 1e-6));
	float discVis = GetSunSkyMaskPoint(sunUV);

	float airmass = min(1.0 / max(sunCos, 0.04), 25.0);
	float3 sunColor = pSunColor * exp(-airmass * float3(0.10, 0.14, 0.20));

	float sunset = 1.0 - saturate(sunCos * 5.0);
	float glowScale = lerp(1.0, 1.35, sunset);

	float lowerLimb = saturate(0.5 - angUp / max(discR, 1e-6));
	sunColor *= lerp(float3(1.0, 1.0, 1.0), float3(1.0, 0.78, 0.50), lowerLimb * sunset);

	float tDisc = theta / max(discR, 1e-6);
	float tGlow = theta / max(glowR * glowScale, 1e-6);
	float tAura = theta / max(auraR * glowScale, 1e-6);

	float core = exp(-tDisc * tDisc * 2.5);
	float glow = exp(-tGlow * tGlow * 3.0);
	float aura = exp(-tAura * tAura * 3.5);

	float3 discTint   = lerp(float3(1.0, 0.985, 0.94), float3(1.0, 0.74, 0.38), saturate(tDisc * tDisc));
	float3 coronaTint = float3(1.0, 0.82, 0.52);
	float3 auraTint   = float3(1.0, 0.93, 0.82);

	float rayOut = smoothstep(discR * 0.9, discR * 1.2, theta);

	float falloffDist = theta / max(glowR * glowScale * 2.6, 1e-6);
	float rayFalloff = exp(-(falloffDist * falloffDist));

	float rayHorizonFade = smoothstep(0.05, 0.35, normalize(-SunDirection).y);

	float3 coronaRays = float3(0.0, 0.0, 0.0);
	float filamentFade = rayOut * rayFalloff * 0.22 * discVis * rayHorizonFade;

	if (filamentFade > 0.0005)
	{
		float ang = atan2(angUp, angSide);
		float raysT = Time * 0.00012;
		float2 dirP = float2(cos(ang), sin(ang));

		float fil1 = DustNoise(float3(dirP * 1.4, raysT * 0.6), raysT);
		float fil2 = DustNoise(float3(dirP * 4.2, raysT * 1.4), raysT * 0.9);
		float filaments = fil1 * 0.65 + fil2 * 0.35;

		coronaRays = sunColor * coronaTint * (filaments * 2.0 - 0.75) * filamentFade;
	}

	float breakup = 1.0;
	float shimmer = 1.0;

	if (core + glow + aura > 0.001)
	{
		float turb = DustNoise(float3(texCoords * screenSizePx * 0.005, Time * 0.00025), Time * 0.0004);
		breakup = 1.0 + (turb - 0.5) * 0.20 * smoothstep(0.30, 0.95, tDisc);
		shimmer = 1.0 + (turb - 0.5) * 0.08;
	}

	float3 sun = (sunColor * discTint * core * SunDiscIntensity * shimmer
	           + sunColor * coronaTint * glow * SunGlowIntensity * breakup
	           + sunColor * auraTint   * aura  * SunAuraIntensity * breakup
	           + coronaRays) * skyMask * screenFade;

	float3 shafts = float3(0.0, 0.0, 0.0);

	if (sunVis > 0.0)
	{
		float glowRadiusPx = glowR / max(pixelAngle, 1e-6);
		shafts = GetSunShafts(texCoords, sunUV, sunCos, sunColor, screenSizePx, glowRadiusPx) * screenFade * sunVis;
	}

	return sun + shafts;
}

float4 GodRaysProcess(PS_INPUT input) : OUTPUT(0)
{
	float3 rayDir = GetViewRayDir(input.TexCoord, InvViewProj);
	float pixelAngle = PixelAngle(rayDir);

	return float4(GetSunContribution(input.TexCoord, rayDir, pixelAngle), 1.0);
}

technique GodRays
{
	pass Main
	{
		Vertex(VertexProcess);
		Pixel(GodRaysProcess);
	}
}