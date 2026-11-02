//--------------------------------------------------------------------------
//	THIS FILE IS A PRIVATE PROPERTY OF EUCLID LABS STUDIO.
//	THIS SHADER MAY NOT BE USED IN ANY PROJECTS
//	WITHOUT THE EXPLICIT PERMISSION OF THE RIGHTS HOLDER. ANY USE OF THESE FILES
//	IN YOUR PROJECTS REQUIRES PRIOR AGREEMENT WITH THE RIGHTS HOLDER.
//	YOU CAN CONTACT US BY MAILING US ON EUCLIDLABSSTUDIO@GMAIL.COM.
//--------------------------------------------------------------------------

#include "Tools.fx"

#ifdef D3D11

#define CULL_THREADS 64

uniform float4x4 GridInvViewProj;
uniform float3 GridEyePos;
uniform float4 GridScreen;
uniform float4 GridLayout;
uniform float GridLightTexelStep;

DeclareTexture(tLightData, LightData, BLITZ_FILTER_POINT, BLITZ_ADDR_CLAMP, BLITZ_ADDR_CLAMP, 0.0, 1);

inline float4 GridReadLightTexel(int index, int texel)
{
	int t = index * 4 + texel;
	return Sample2DLod0(LightData, float2((float(t) + 0.5) * GridLightTexelStep, 0.5));
}

RWTexture2D<float> g_outLightGrid : register(u0);

groupshared uint g_tileCount;
groupshared float3 g_planes[4];

float3 GridRay(float2 uv)
{
	float4 w = GetWorldPositionW(uv, 1.0, GridInvViewProj);
	return w.xyz - GridEyePos;
}

void GridPlanes(uint2 tile, out float3 planes[4])
{
	float2 invScreen = 1.0 / GridScreen.xy;
	float2 tileSize = GridScreen.zw;

	float2 uv0 = float2(tile) * tileSize * invScreen;
	float2 uv1 = min(float2(tile + 1) * tileSize * invScreen, float2(1.0, 1.0));

	float3 tl = GridRay(float2(uv0.x, uv0.y));
	float3 tr = GridRay(float2(uv1.x, uv0.y));
	float3 bl = GridRay(float2(uv0.x, uv1.y));
	float3 br = GridRay(float2(uv1.x, uv1.y));
	float3 rc = GridRay((uv0 + uv1) * 0.5);

	planes[0] = normalize(cross(tl, bl));
	planes[1] = normalize(cross(br, tr));
	planes[2] = normalize(cross(tr, tl));
	planes[3] = normalize(cross(bl, br));

	for (int i = 0; i < 4; ++i)
	{
		if (dot(planes[i], rc) < 0.0) planes[i] = -planes[i];
	}
}

[numthreads(CULL_THREADS, 1, 1)]
void CSCullLights(uint3 gid : SV_GroupID, uint3 groupThread : SV_GroupThreadID)
{
	uint tid = groupThread.x;
	uint tilesX = (uint)GridLayout.x;
	uint cap = (uint)GridLayout.z;
	uint count = (uint)GridLayout.w;

	if (gid.x >= tilesX) return;

	uint tileRow = gid.y * tilesX + gid.x;

	if (tid == 0)
	{
		g_tileCount = 0;

		float3 planes[4];
		GridPlanes(gid.xy, planes);
		g_planes[0] = planes[0];
		g_planes[1] = planes[1];
		g_planes[2] = planes[2];
		g_planes[3] = planes[3];
	}
	GroupMemoryBarrierWithGroupSync();

	for (uint l = tid; l < count; l += CULL_THREADS)
	{
		float4 lightPos = GridReadLightTexel((int)l, 0);
		float lightType = GridReadLightTexel((int)l, 1).w;

		float3 d = lightPos.xyz - GridEyePos;
		float radius = (lightType < 1.5) ? 1.0e9 : (1.0 / max(lightPos.w, 1e-5));

		bool visible = true;
		for (int p = 0; p < 4; ++p)
		{
			if (dot(g_planes[p], d) < -radius) { visible = false; break; }
		}

		if (visible)
		{
			uint slot;
			InterlockedAdd(g_tileCount, 1, slot);
			if (slot < cap) g_outLightGrid[uint2(slot + 1, tileRow)] = (float)l;
		}
	}

	GroupMemoryBarrierWithGroupSync();

	if (tid == 0)
	{
		bool truncated = g_tileCount > cap;
		g_outLightGrid[uint2(0, tileRow)] = truncated ? -(float)g_tileCount : (float)g_tileCount;
	}
}

technique Cull
{
	pass p0
	{
		Compute(CSCullLights);
	}
}

#endif
