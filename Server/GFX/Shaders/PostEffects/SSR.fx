//--------------------------------------------------------------------------
//	THIS FILE IS A PRIVATE PROPERTY OF EUCLID LABS STUDIO.
//	THIS SHADER MAY NOT BE USED IN ANY PROJECTS
//	WITHOUT THE EXPLICIT PERMISSION OF THE RIGHTS HOLDER. ANY USE OF THESE FILES
//	IN YOUR PROJECTS REQUIRES PRIOR AGREEMENT WITH THE RIGHTS HOLDER.
//	YOU CAN CONTACT US BY MAILING US ON EUCLIDLABSSTUDIO@GMAIL.COM.
//--------------------------------------------------------------------------

#include "..\Forward\Tools.fx"
#include "..\Forward\PBR.fx"

#ifdef D3D11

uniform float4x4 InvViewProj;
uniform float4x4 SSRViewProj;
uniform float3 CameraPosition;

uniform float4 SSRScreen;
uniform float4 SSRTraceSize;

uniform float SSRRayLength         = 30.0;
uniform float SSRPixelStride       = 1.0;
uniform float SSRThickness         = 0.1;
uniform float SSRBias              = 0.02;
uniform float SSRStrength          = 1.0;
uniform float SSRRoughnessCutoff   = 0.8;
uniform float SSRResolveRadius     = 10.0;

static const int   SSRMaxSteps     = 64;
static const int   SSRRefineSteps  = 9;
static const int   SSRBlurTaps     = 12;
static const float SSRNormalSpread  = 8.0;
static const float SSRThicknessCap = 8;
static const float SSRGOLDEN       = 2.39996323;
static const float SSRBG           = 0.999;

DeclareSampler(ColorMap, 0, BLITZ_FILTER_POINT,  BLITZ_ADDR_CLAMP, BLITZ_ADDR_CLAMP, 0.0, 1);
DeclareSampler(DepthMap, 1, BLITZ_FILTER_POINT,  BLITZ_ADDR_CLAMP, BLITZ_ADDR_CLAMP, 0.0, 1);
DeclareSampler(SSRMap,   2, BLITZ_FILTER_LINEAR, BLITZ_ADDR_CLAMP, BLITZ_ADDR_CLAMP, 0.0, 1);

RWTexture2D<float4> g_outSSR : register(u0);

inline float SampleDepth(float2 uv)
{
	return Sample2DLod0(DepthMap, uv).r;
}

inline float SampleDistance(float2 uv)
{
	return GetEyeDistance(uv, SampleDepth(uv), InvViewProj, CameraPosition);
}

inline float3 SampleWorld(float2 uv)
{
	return GetWorldPosition(uv, SampleDepth(uv), InvViewProj);
}

inline float3 SampleNormal(float2 uv, float2 texel, out float confidence)
{
	float2 e  = texel * SSRNormalSpread;

	float2 ul = uv - float2(e.x, 0.0);
	float2 ur = uv + float2(e.x, 0.0);
	float2 ud = uv - float2(0.0, e.y);
	float2 uu = uv + float2(0.0, e.y);

	float  dc = SampleDistance(uv);
	float  dl = SampleDistance(ul);
	float  dr = SampleDistance(ur);
	float  dD = SampleDistance(ud);
	float  dU = SampleDistance(uu);

	float3 pc = SampleWorld(uv);
	float3 pl = SampleWorld(ul);
	float3 pr = SampleWorld(ur);
	float3 pd = SampleWorld(ud);
	float3 pu = SampleWorld(uu);

	float3 ddx = length(pl - pc) < length(pr - pc) ? pl - pc : pr - pc;
	float3 ddy = length(pd - pc) < length(pu - pc) ? pd - pc : pu - pc;

	float hi = max(max(dl, dr), max(dU, dD));
	float lo = min(min(dl, dr), min(dU, dD));
	confidence = 1.0 - smoothstep(0.5, 1.5, (hi - lo) / max(dc, 0.05));

	return NormalFromDepth(pc, pc + ddx, pc + ddy, CameraPosition);
}

inline float GetRoughFade(float roughness)
{
	return 1.0 - smoothstep(SSRRoughnessCutoff * 0.45, SSRRoughnessCutoff, roughness);
}

inline float SSRClipPlane(float p, float q, float tMax)
{
	return (q < -1e-6 && p > 0.0) ? min(tMax, -p / q) : tMax;
}

inline float SSRClipRay(float4 sc, float4 rc, float tMax)
{
	tMax = SSRClipPlane(sc.w - sc.x, rc.w - rc.x, tMax);
	tMax = SSRClipPlane(sc.w + sc.x, rc.w + rc.x, tMax);
	tMax = SSRClipPlane(sc.w - sc.y, rc.w - rc.y, tMax);
	tMax = SSRClipPlane(sc.w + sc.y, rc.w + rc.y, tMax);
	if (rc.w < -1e-6) tMax = min(tMax, -sc.w / rc.w);
	return max(tMax, 0.0);
}

inline float SSRRayT(float2 suv, float4 sc, float4 rc)
{
	float mx = 2.0 * suv.x - 1.0;
	float my = 1.0 - 2.0 * suv.y;

	float dx = mx * rc.w - rc.x;
	float dy = my * rc.w - rc.y;

	if (abs(dx) < 1e-9 && abs(dy) < 1e-9) return 0.0;
	return abs(dx) > abs(dy) ? (sc.x - mx * sc.w) / dx : (sc.y - my * sc.w) / dy;
}

inline bool IgnoreHit(float dist)
{
	return IsSkyDepth(dist) > 0.0;
}

[numthreads(8, 8, 1)]
void CSSTrace(uint3 tid : SV_DispatchThreadID)
{
	uint2 dim = (uint2)SSRTraceSize.xy;
	if (tid.x >= dim.x || tid.y >= dim.y) return;

	float4 result = 0.0;

	float2 uv    = (float2(tid.xy) + 0.5) * SSRTraceSize.zw;
	float2 texel = SSRScreen.zw;

	float4 surface   = Sample2DLod0(DepthMap, uv);
	float centerDist = SampleDistance(uv);

	float roughness = clamp(surface.b, 0.02, 1.0);
	float roughFade = GetRoughFade(roughness);

	if (roughFade > 0.001)
	{
		float  normalConf = 0.0;
		float3 worldPos = SampleWorld(uv);
		float3 normal   = SampleNormal(uv, texel, normalConf);

		float3 viewDelta = worldPos - CameraPosition;
		float3 viewDir   = normalize(viewDelta);
		float3 R         = reflect(viewDir, normal);

		float4 startClip = mul(float4(worldPos, 1.0), SSRViewProj);
		float4 rayClip   = mul(float4(R, 0.0), SSRViewProj);

		float tEnd = SSRClipRay(startClip, rayClip, SSRRayLength);

		if (tEnd > 1e-3)
		{
			float2 uvEnd = GetScreenTexCoords(startClip + rayClip * tEnd);
			float2 dPix  = (uvEnd - uv) * SSRScreen.xy;
			float  L     = length(dPix);

			if (L > 1.0)
			{
				float2 dirPix = dPix / L;

				float s0 = max(SSRPixelStride, 0.5);
				float s1 = max(s0, 2.0 * L / (float)SSRMaxSteps - s0);

				float  travel   = 0.0;
				float  tPrev    = 0.0;
				float  hitFound = 0.0;
				float  hitT     = 0.0;
				float2 hitUV    = uv;

				[loop]
				for (int i = 0; i < SSRMaxSteps; ++i)
				{
					float stride = s0 + (s1 - s0) * ((float)i / (float)(SSRMaxSteps - 1));
					travel += stride;
					if (travel > L) break;

					float2 suv = uv + dirPix * travel * texel;
					if (suv.x < 0.0 || suv.x > 1.0 || suv.y < 0.0 || suv.y > 1.0) break;

					float tCur = SSRRayT(suv, startClip, rayClip);
					if (tCur <= tPrev) { tPrev = tCur; continue; }

					float worldStep   = tCur - tPrev;
					float surfaceDist = SampleDistance(suv);
					
					float rayDist = length(viewDelta + R * tCur);
					float thickness = max(SSRThickness, min(worldStep * 2.0, SSRThicknessCap));

					if (rayDist >= surfaceDist + SSRBias && rayDist < surfaceDist + thickness)
					{
						float dummy = 0.0;
						float3 hitN = SampleNormal(suv, texel, dummy);

						if (dot(R, hitN) < -0.1)
						{
							float a = tPrev;
							float b = tCur;

							[unroll]
							for (int j = 0; j < SSRRefineSteps; ++j)
							{
								float mid = (a + b) * 0.5;
								float2 pm = GetScreenTexCoords(startClip + rayClip * mid);
								float  rm = length(viewDelta + R * mid);
								if (rm >= SampleDistance(pm) + SSRBias) b = mid; else a = mid;
							}

							hitT     = b;
							hitUV    = GetScreenTexCoords(startClip + rayClip * b);
							float hitDist = SampleDistance(hitUV);
							if (!IgnoreHit(hitDist))
							{
								hitFound = 1.0;
								break;
							}
							break;
						}
					}

					tPrev = tCur;
				}

				if (hitFound > 0.0)
				{
					float  distFade = 1.0 - smoothstep(SSRRayLength * 0.5, SSRRayLength, hitT);
					float2 e        = min(hitUV, 1.0 - hitUV);
					float  edgeFade = smoothstep(0.0, 0.15, min(e.x, e.y));

					float a = distFade * edgeFade * roughFade * normalConf;
					result = float4(Sample2DLod0(ColorMap, hitUV).rgb, a);
				}
			}
		}
	}

	g_outSSR[tid.xy] = result;
}

[numthreads(8, 8, 1)]
void CSSClear(uint3 tid : SV_DispatchThreadID)
{
	uint2 dim = (uint2)SSRTraceSize.xy;
	if (tid.x >= dim.x || tid.y >= dim.y) return;
	g_outSSR[tid.xy] = 0.0;
}

struct PS_INPUT
{
	float4 Pos      : OUT_POSITION;
	float2 TexCoord : TEXCOORD0;
};

PS_INPUT VertexProcess(VS_INPUT input)
{
	PS_INPUT output;
	output.Pos      = mul(input.Pos, ViewProj);
	output.TexCoord = GetScreenTexCoords(output.Pos) + halfPixel;
	return output;
}

float4 SSRResolve(PS_INPUT input) : OUTPUT(0)
{
	const float2 uv = input.TexCoord;

	float4 surface = Sample2DLod0(DepthMap, uv);
	float dist     = SampleDistance(uv);

	float roughness = clamp(surface.b, 0.02, 1.0);
	float roughFade = GetRoughFade(roughness);

	float  dummy = 0.0;
	float3 worldPos = SampleWorld(uv);
	float3 normal   = SampleNormal(uv, SSRScreen.zw, dummy);
	float3 viewDir  = normalize(worldPos - CameraPosition);
	float  ndv      = saturate(dot(normal, -viewDir)) + 1e-5;

	float3 sceneColor = Sample2DLod0(ColorMap, uv).rgb;
	float3 F0         = lerp(0.04, max(0.04, sceneColor), surface.a);
	float3 specColor  = EnvBRDFApprox(F0, roughness, ndv);

	float traceScale = SSRTraceSize.x / max(SSRScreen.x, 1.0);
	float radius     = roughness * SSRResolveRadius * traceScale;

	float4 s0 = Sample2DLod0(SSRMap, uv);
	if (radius < 0.75)
		return float4(s0.rgb * specColor * SSRStrength * s0.a, s0.a);

	float rot = InterleavedGradientNoise(uv * SSRScreen.xy) * 6.2831853;

	float3 sum  = 0.0;
	float  wsum = 0.0;

	[loop]
	for (int i = 0; i <= SSRBlurTaps; ++i)
	{
		float2 off = 0.0;

		if (i > 0)
		{
			float r = sqrt(((float)i - 0.5) / (float)SSRBlurTaps) * radius;
			float a = rot + (float)i * SSRGOLDEN;
			off = float2(cos(a), sin(a)) * r * SSRTraceSize.zw;
		}

		float2 tuv = uv + off;
		float4 s   = Sample2DLod0(SSRMap, tuv);

		float2 snap = (floor(tuv * SSRTraceSize.xy) + 0.5) * SSRTraceSize.zw;
		float  dTap = SampleDistance(snap);
		float  rel  = abs(dTap - dist) / max(dist, 0.25);
		float  dW   = saturate(1.0 - rel * 4.0);

		float w = s.a * dW;
		sum  += s.rgb * w;
		wsum += w;
	}

	float3 reflected = sum / max(wsum, 1e-4);
	float  coverage  = saturate(wsum / (float)(SSRBlurTaps + 1));

	return float4(reflected * specColor * SSRStrength * coverage, coverage);
}

float4 SSRAdd(PS_INPUT input) : OUTPUT(0)
{
	return Sample2DLod0(ColorMap, input.TexCoord);
}

technique Trace
{
	pass p0
	{
		Compute(CSSTrace);
	}
}

technique Clear
{
	pass p0
	{
		Compute(CSSClear);
	}
}

technique Resolve
{
	pass p0
	{
		Vertex(VertexProcess);
		Pixel(SSRResolve);
	}
}

technique Add
{
	pass p0
	{
		Vertex(VertexProcess);
		Pixel(SSRAdd);
	}
}

#endif
