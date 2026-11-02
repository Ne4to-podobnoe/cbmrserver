//--------------------------------------------------------------------------
//	THIS FILE IS A PRIVATE PROPERTY OF EUCLID LABS STUDIO.
//	THIS SHADER MAY NOT BE USED IN ANY PROJECTS
//	WITHOUT THE EXPLICIT PERMISSION OF THE RIGHTS HOLDER. ANY USE OF THESE FILES
//	IN YOUR PROJECTS REQUIRES PRIOR AGREEMENT WITH THE RIGHTS HOLDER.
//	YOU CAN CONTACT US BY MAILING US ON EUCLIDLABSSTUDIO@GMAIL.COM.
//--------------------------------------------------------------------------

#define LIGHT_TEXELS 4

#define SHADOW_FILTER_REFERENCE 2048.0

#if defined(VERTEXLIT)
	#define SHADOW_TAPS 1
#else
	#define SHADOW_TAPS 4
#endif

#if !defined(D3D11) || defined(LOW)
	#define WALK_MAX 8
#endif

uniform float LightCount;
uniform float LightTexelStep;
uniform float TileSizeX;
uniform float TileSizeY;
uniform float TilesX;
uniform float TilesY;
uniform float GridInvWidth;
uniform float GridInvHeight;
uniform float GridDecode;

DeclareTexture(tLightGrid, LightGrid, BLITZ_FILTER_POINT, BLITZ_ADDR_CLAMP, BLITZ_ADDR_CLAMP, 0.0, 1);
DeclareTexture(tLightData, LightData, BLITZ_FILTER_POINT, BLITZ_ADDR_CLAMP, BLITZ_ADDR_CLAMP, 0.0, 1);

#ifdef D3D11
	#define SampleLight(t) tLightData.Load(int3((int)(t), 0, 0))
	#define SampleShadowTexel(t) tShadowData.Load(int3((int)(t), 0, 0))
	#define SampleLightGrid(x, y) tLightGrid.Load(int3((int)(x), (int)(y), 0))
#else
	#define SampleLight(t)  Sample2DLod0(LightData, float2(((float)(t) + 0.5) * LightTexelStep, 0.5))
	#define SampleShadowTexel(t)  Sample2DLod0(ShadowData, float2(((float)(t) + 0.5) * ShadowDataInvTexels, 0.5))
	#define SampleLightGrid(x, y)  Sample2DLod0(LightGrid, (float2((float)(x), (float)(y)) + 0.5) * float2(GridInvWidth, GridInvHeight))
#endif

inline float4 ReadLightTexel(int index, int texel)
{
	int t = index * LIGHT_TEXELS + texel;
	return SampleLight(t);
}

struct Light
{
	float3 position;
	float3 direction;
	float3 color;
	float coneCos;
	float invRange;
	float type;
	float shadow;
};

inline Light ReadLight(int index)
{
	float4 t0 = ReadLightTexel(index, 0);
	float4 t1 = ReadLightTexel(index, 1);
	float4 t2 = ReadLightTexel(index, 2);
	float4 t3 = ReadLightTexel(index, 3);

	Light l;
	l.position = t0.xyz;
	l.invRange = t0.w;
	l.color    = t1.rgb;
	l.type     = t1.w;
	l.direction = t2.xyz;
	l.coneCos  = t3.x;
	l.shadow   = t3.z;
	return l;
}

inline bool IsDirectional(Light l)
{
	return l.type < 1.5;
}

inline bool IsSpot(Light l)
{
	return l.type > 2.5;
}

inline float SpotConeAttenuation(Light light, float coneDot)
{
    float outer = light.coneCos;
    float spot = saturate((coneDot - outer) / max(1.0 - outer, 1e-4));
    return spot * spot * (3.0 - 2.0 * spot);
}

// ========================================================================== SHADOWS

#ifndef LOW

uniform float ShadowFadeInv = 0.0;
uniform float NormalOffset = 0.05;
uniform float4x4 ShadowsAdjust;

#define SLOT_TEXELS 24

uniform float ShadowDataInvTexels : SHADOW_DATA_INV_TEXELS;

texture2D tShadowData : SHADOW_DATA;
SamplerState ShadowData = sampler_state { Filter = BLITZ_FILTER_POINT; AddressU = BLITZ_ADDR_CLAMP; AddressV = BLITZ_ADDR_CLAMP; MipLODBias = 0.0; MaxAnisotropy = 1; };

uniform float4x4 CascadeView : SHADOW_CASCADE_VIEW;

Texture2D tShadowDir : SHADOW_DIR_MAP; // one shadowed dirlight
Texture2DArray tShadowSpot : SHADOW_SPOT_ARRAY;
TextureCubeArray tShadowPoint : SHADOW_POINT_ARRAY;

uniform int ShadowDirAddress : SHADOW_DIR_ADDRESS = 4;     // D3DTADDRESS_BORDER
uniform int ShadowSpotAddress : SHADOW_SPOT_ADDRESS = 3;   // D3DTADDRESS_CLAMP
uniform int ShadowPointAddress : SHADOW_POINT_ADDRESS = 3; // D3DTADDRESS_CLAMP

SamplerComparisonState ShadowMapCmpDir = sampler_state { Filter = COMPARISON_MIN_MAG_LINEAR_MIP_POINT; AddressU = ShadowDirAddress; AddressV = ShadowDirAddress; BorderColor = float4(1.0, 1.0, 1.0, 1.0); ComparisonFunc = LESS_EQUAL; };
SamplerComparisonState ShadowMapCmpSpot = sampler_state { Filter = COMPARISON_MIN_MAG_LINEAR_MIP_POINT; AddressU = ShadowSpotAddress; AddressV = ShadowSpotAddress; AddressW = ShadowSpotAddress; BorderColor = float4(1.0, 1.0, 1.0, 1.0); ComparisonFunc = LESS_EQUAL; };
SamplerComparisonState ShadowMapCmpPoint = sampler_state { Filter = COMPARISON_MIN_MAG_LINEAR_MIP_POINT; AddressU = ShadowPointAddress; AddressV = ShadowPointAddress; AddressW = ShadowPointAddress; BorderColor = float4(1.0, 1.0, 1.0, 1.0); ComparisonFunc = LESS_EQUAL; };

inline float4 ShadowTexel(int slot, int texel)
{
	int t = slot * SLOT_TEXELS + texel;
	return SampleShadowTexel(t);
}

inline float4x4 ShadowMatrix(int slot, int cascade)
{
	int t = cascade * 4;
	float4 r0 = ShadowTexel(slot, t + 0);
	float4 r1 = ShadowTexel(slot, t + 1);
	float4 r2 = ShadowTexel(slot, t + 2);
	float4 r3 = ShadowTexel(slot, t + 3);
	return float4x4(r0, r1, r2, r3);
}

inline float4 ShadowProj(float3 worldPos, int slot, int cascade)
{
	return mul(mul(float4(worldPos, 1.0), ShadowMatrix(slot, cascade)), ShadowsAdjust);
}

inline float3 ShadowUVZ(float4 proj)
{
	float w = max(proj.w, 1e-6);
	return float3(proj.xy / w, proj.z / w);
}

inline float ShadowPCFDir(float4 proj, float2 invRef, float2 cellMin, float2 cellMax)
{
	float3 uvz = ShadowUVZ(proj);
	float2 offsets = invRef;
	float tap = max(offsets.x, offsets.y);
	uvz.xy = clamp(uvz.xy, cellMin + tap, cellMax - tap);

#if SHADOW_TAPS == 1
	return tShadowDir.SampleCmpLevelZero(ShadowMapCmpDir, uvz.xy, uvz.z);
#elif SHADOW_TAPS == 4
	offsets *= 0.5;
	float sum = 0.0;
#define PCF_DIR(DX, DY) sum += tShadowDir.SampleCmpLevelZero(ShadowMapCmpDir, uvz.xy + float2(DX, DY) * offsets, uvz.z);
	PCF_DIR(-1, -1)
	PCF_DIR( 1, -1)
	PCF_DIR(-1,  1)
	PCF_DIR( 1,  1)
	return sum * 0.25;
#else
	float sum = 0.0;
#define PCF_DIR(DX, DY) sum += tShadowDir.SampleCmpLevelZero(ShadowMapCmpDir, uvz.xy + float2(DX, DY) * offsets, uvz.z);
	PCF_DIR(-1, -1)
	PCF_DIR(-1,  0)
	PCF_DIR(-1,  1)
	PCF_DIR( 0, -1)
	PCF_DIR( 0,  0)
	PCF_DIR( 0,  1)
	PCF_DIR( 1, -1)
	PCF_DIR( 1,  0)
	PCF_DIR( 1,  1)
	return sum / 9.0;
#endif
}

inline float ShadowPCF(int slot, float4 proj, float2 invRef)
{
	float3 uvz = ShadowUVZ(proj);
	float slice = ShadowTexel(slot, 19).x;
	float3 base = float3(uvz.xy, slice);

#if SHADOW_TAPS == 1
	return tShadowSpot.SampleCmpLevelZero(ShadowMapCmpSpot, base, uvz.z);
#elif SHADOW_TAPS == 4
#define PCF_SPOT_BLUR 1.5
	float2 offsets = clamp(uvz.z, 1.0, 3.0) * PCF_SPOT_BLUR * invRef * 0.5;

	float sum = 0.0;
#define PCF_SPOT(DX, DY) sum += tShadowSpot.SampleCmpLevelZero(ShadowMapCmpSpot, base + float3(float2(DX, DY) * offsets, 0.0), uvz.z);
	PCF_SPOT(-1, -1)
	PCF_SPOT( 1, -1)
	PCF_SPOT(-1,  1)
	PCF_SPOT( 1,  1)
	return sum * 0.25;
#else
#define PCF_SPOT_BLUR 1.5
	float2 offsets = clamp(uvz.z, 1.0, 3.0) * PCF_SPOT_BLUR * invRef;

	float sum = 0.0;
#define PCF_SPOT(DX, DY) sum += tShadowSpot.SampleCmpLevelZero(ShadowMapCmpSpot, base + float3(float2(DX, DY) * offsets, 0.0), uvz.z);
	PCF_SPOT(-1, -1)
	PCF_SPOT(-1,  0)
	PCF_SPOT(-1,  1)
	PCF_SPOT( 0, -1)
	PCF_SPOT( 0,  0)
	PCF_SPOT( 0,  1)
	PCF_SPOT( 1, -1)
	PCF_SPOT( 1,  0)
	PCF_SPOT( 1,  1)
	return sum / 9.0;
#endif
}

inline float ShadowDirSlot(int slot, float3 worldPos)
{
	float4 v = mul(float4(worldPos, 1.0), CascadeView);
	float viewDepth = v.z / max(v.w, 1e-6);

	float4 counts = ShadowTexel(slot, 17);   // x = cascades, y = cascade width
	float4 splits = ShadowTexel(slot, 16);

	int cascades = clamp((int)counts.x, 1, 4);
	int ci = cascades - 1;
	for (int k = 0; k < 3; ++k)
	{
		if (k < cascades - 1 && viewDepth <= splits[k]) { ci = k; break; }
	}

	float blend = 0.0;
	if (ci + 1 < cascades)
	{
		float boundary = splits[ci];
		float halfBand = max(splits[ci + 1] - boundary, 0.001) * 0.25;
		blend = saturate(((viewDepth - boundary) + halfBand) / (2.0 * halfBand));
	}

	float2 invRef = 1.0 / float2(SHADOW_FILTER_REFERENCE * cascades, SHADOW_FILTER_REFERENCE);

	float invCascades = 1.0 / cascades;
	float4 p = ShadowProj(worldPos, slot, ci);
	p.x = (p.x / p.w + ci) / cascades * p.w;
	float2 cellMin = float2(ci * invCascades, 0.0);
	float2 cellMax = float2((ci + 1) * invCascades, 1.0);
	float shadow = ShadowPCFDir(p, invRef, cellMin, cellMax);

	if (blend > 0.0 && ci + 1 < cascades)
	{
		int ci2 = ci + 1;
		float4 p2 = ShadowProj(worldPos, slot, ci2);
		p2.x = (p2.x / p2.w + ci2) / cascades * p2.w;
		float2 cellMin2 = float2(ci2 * invCascades, 0.0);
		float2 cellMax2 = float2((ci2 + 1) * invCascades, 1.0);
		shadow = lerp(shadow, ShadowPCFDir(p2, invRef, cellMin2, cellMax2), blend);
	}

	return shadow;
}

inline float ShadowSpotSlot(int slot, float3 worldPos)
{
	float4 proj = ShadowProj(worldPos, slot, 0);
	float shadow = ShadowPCF(slot, proj, 1.0 / float2(SHADOW_FILTER_REFERENCE, SHADOW_FILTER_REFERENCE));
	return shadow;
}

inline float ShadowPointSlot(int slot, float3 worldPos)
{
	float4 pointPos = ShadowTexel(slot, 18);
	float4 cubeInfo = ShadowTexel(slot, 20);

	float3 d = worldPos - pointPos.xyz;
	float dist = length(d);
	float3 ndir = d / max(dist, 1e-6);

	float range = 1.0 / max(pointPos.w, 1e-6);
	float nearZ = max(0.001, 0.005 * range);
	float Qscale = range / max(range - nearZ, 1e-6);

	float cube = cubeInfo.x;
#define PCF_POINT_BLUR 1.5
	float texelAng = (3.14159265 * 0.5) / SHADOW_FILTER_REFERENCE * PCF_POINT_BLUR;

	float3 up = abs(ndir.y) < 0.99 ? float3(0.0, 1.0, 0.0) : float3(1.0, 0.0, 0.0);
	float3 T = normalize(cross(up, ndir));
	float3 B = cross(ndir, T);

	float sum = 0.0;
	float3 tap;
	float ref;
#if SHADOW_TAPS == 1
	tap = ndir;
	ref = Qscale - Qscale * nearZ / max(dist * max(abs(tap.x), max(abs(tap.y), abs(tap.z))), nearZ);
	sum = tShadowPoint.SampleCmpLevelZero(ShadowMapCmpPoint, float4(tap, cube), ref);
#elif SHADOW_TAPS == 4
#define PCF_POINT(DIR) \
	tap = normalize(DIR); \
	ref = Qscale - Qscale * nearZ / max(dist * max(abs(tap.x), max(abs(tap.y), abs(tap.z))), nearZ); \
	sum += tShadowPoint.SampleCmpLevelZero(ShadowMapCmpPoint, float4(tap, cube), ref);

	float pointBlur = texelAng * 0.5;
	PCF_POINT(ndir + (-T - B) * pointBlur)
	PCF_POINT(ndir + (-T + B) * pointBlur)
	PCF_POINT(ndir + ( T - B) * pointBlur)
	PCF_POINT(ndir + ( T + B) * pointBlur)
	sum *= 0.25;
#else
#define PCF_POINT(DIR) \
	tap = normalize(DIR); \
	ref = Qscale - Qscale * nearZ / max(dist * max(abs(tap.x), max(abs(tap.y), abs(tap.z))), nearZ); \
	sum += tShadowPoint.SampleCmpLevelZero(ShadowMapCmpPoint, float4(tap, cube), ref);

	PCF_POINT(ndir + (-T - B) * texelAng)
	PCF_POINT(ndir - T * texelAng)
	PCF_POINT(ndir + (-T + B) * texelAng)
	PCF_POINT(ndir - B * texelAng)
	PCF_POINT(ndir)
	PCF_POINT(ndir + B * texelAng)
	PCF_POINT(ndir + (T - B) * texelAng)
	PCF_POINT(ndir + T * texelAng)
	PCF_POINT(ndir + (T + B) * texelAng)
	sum /= 9.0;
#endif

	return sum;
}

inline float3 ShadowPos(Light light, float3 worldPos, float3 normal)
{
	float3 toLight = IsDirectional(light) ? light.direction : light.position - worldPos;
	float3 L = normalize(toLight);
	return worldPos + saturate(1.0 - dot(normal, L)) * NormalOffset * normal;
}

inline float ShadowFadeOut(Light light)
{
	if (IsDirectional(light)) return 0.0;
	float range = 1.0 / max(light.invRange, 1e-6);
	float dist = length(light.position - EyePos);
	return saturate(max(dist - range, 0.0) * ShadowFadeInv);
}

inline float GetShadowAt(Light light, float3 worldPos, float3 normal)
{
	int slot = (int)light.shadow;
	if (slot < 0) return 1.0;

	float3 wp = ShadowPos(light, worldPos, normal);
	float shadow;
	if (light.type < 1.5) shadow = ShadowDirSlot(slot, wp);
	else if (light.type < 2.5) shadow = ShadowPointSlot(slot, wp);
	else shadow = ShadowSpotSlot(slot, wp);
	return lerp(shadow, 1.0, ShadowFadeOut(light));
}

inline float GetShadowFor(int index, Light light, float3 worldPos, float3 normal)
{
	return GetShadowAt(light, worldPos, normal);
}

#else

inline float GetShadowFor(int index, Light light, float3 worldPos, float3 normal)
{
	return 1.0;
}

#endif

// ========================================================================== LIGHTING
inline LightOutput ShadeLight(Light light, float3 worldPos, float3 normal, float3 eyeVector, float3 diffuseColor, float3 F0, float roughness, float shadow)
{
    float3 lightVec;
    float attenuation;

    if (IsDirectional(light))
    {
        lightVec = light.direction;
        attenuation = 1.0;
    }
    else
    {
        lightVec = light.position - worldPos;
        float distSqr = dot(lightVec, lightVec);
        float len = sqrt(max(distSqr, 1e-6));

        float nr = distSqr * light.invRange * light.invRange;
        float t = saturate(1.0 - nr * nr);

        attenuation = (1.0 / (distSqr + 1.0)) * (t * t);

        if (IsSpot(light))
        {
            attenuation *= SpotConeAttenuation(light, dot(lightVec / len, light.direction));
        }
    }

    return CalculatePBRLight(lightVec, light.color * attenuation * shadow, eyeVector, normal, diffuseColor, F0, roughness);
}

inline LightOutput GetForwardLight(float3 worldPos, float3 normal, float3 geoNormal, float3 eyeVector, float3 diffuseColor, float3 F0, float roughness, float2 screenPx)
{
	int tilesX = (int)TilesX;
	int tilesY = (int)TilesY;

	int2 tile = int2(screenPx.x / max(TileSizeX, 1.0), screenPx.y / max(TileSizeY, 1.0));
	tile = clamp(tile, int2(0, 0), int2(tilesX - 1, tilesY - 1));

	int tileRow = tile.y * tilesX + tile.x;

	LightOutput result;
	result.diffuse = 0.0;
	result.specular = 0.0;

	int count = (int)LightCount;
	int entries;
	bool walkAll;

#ifdef LOW
	count = min(count, WALK_MAX);
	entries = count;
	walkAll = true;
#else
	int tileCount = (int)floor(SampleLightGrid(0, tileRow).r * GridDecode + 0.5);
	walkAll = tileCount < 0;
	entries = walkAll ? count : tileCount;
#endif

	[loop]for (int i = 0; i < entries; ++i)
	{
		int index = i;

		if (!walkAll)
		{
			index = (int)floor(SampleLightGrid(i + 1, tileRow).r * GridDecode + 0.5);
		}

		Light lt = ReadLight(index);
		LightOutput light = ShadeLight(lt, worldPos, normal, eyeVector, diffuseColor, F0, roughness, GetShadowFor(index, lt, worldPos, geoNormal));
		result.diffuse += light.diffuse;
		result.specular += light.specular;
	}

	return result;
}

// ========================================================================== VERTEX LIGHTING

#ifdef VERTEXLIT
inline float3 ShadeLightVertex(Light light, float3 worldPos, float3 normal, float shadow)
{
    float3 toLight;
    float attenuation;

    if (IsDirectional(light))
    {
        toLight = light.direction;
        attenuation = 1.0;
    }
    else
    {
        float3 delta = light.position - worldPos;
        float distSqr = dot(delta, delta);
        float len = sqrt(max(distSqr, 1e-6));

        float nr = distSqr * light.invRange * light.invRange;
        float t = saturate(1.0 - nr * nr);
        attenuation = (1.0 / (distSqr + 1.0)) * (t * t);

        if (IsSpot(light))
        {
            attenuation *= SpotConeAttenuation(light, dot(delta / len, light.direction));
        }

        toLight = delta / len;
    }

    float NdotL = dot(normal, toLight);
    float softNdotL = saturate((NdotL + 0.15) / 1.15);
    softNdotL = softNdotL * saturate(NdotL * 4.0);

    return light.color * (attenuation * shadow * softNdotL * 0.31830989);
}

inline float3 GetVertexLight(float3 worldPos, float3 normal, float2 screenPx)
{
	int tilesX = (int)TilesX;
	int tilesY = (int)TilesY;

	int2 tile = int2(screenPx.x / max(TileSizeX, 1.0), screenPx.y / max(TileSizeY, 1.0));
	tile = clamp(tile, int2(0, 0), int2(tilesX - 1, tilesY - 1));

	int tileRow = tile.y * tilesX + tile.x;

	float3 result = 0.0;

	int count = (int)LightCount;
	int entries;
	bool walkAll;

#ifdef LOW
	count = min(count, WALK_MAX);
	entries = count;
	walkAll = true;
#else
	int tileCount = (int)floor(SampleLightGrid(0, tileRow).r * GridDecode + 0.5);
	walkAll = tileCount < 0;
	entries = walkAll ? count : tileCount;
#endif

	[loop]for (int i = 0; i < entries; ++i)
	{
		int index = i;

		if (!walkAll)
		{
			index = (int)floor(SampleLightGrid(i + 1, tileRow).r * GridDecode + 0.5);
		}

		Light lt = ReadLight(index);
		result += ShadeLightVertex(lt, worldPos, normal, GetShadowFor(index, lt, worldPos, normal));
	}

	return result;
}
#endif