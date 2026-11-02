//--------------------------------------------------------------------------
//	THIS FILE IS A PRIVATE PROPERTY OF EUCLID LABS STUDIO.
//	THIS SHADER MAY NOT BE USED IN ANY PROJECTS
//	WITHOUT THE EXPLICIT PERMISSION OF THE RIGHTS HOLDER. ANY USE OF THESE FILES
//	IN YOUR PROJECTS REQUIRES PRIOR AGREEMENT WITH THE RIGHTS HOLDER.
//	YOU CAN CONTACT US BY MAILING US ON EUCLIDLABSSTUDIO@GMAIL.COM.
//--------------------------------------------------------------------------

#include "..\Forward\Tools.fx"
#include "..\Forward\PBR.fx"

float3 cFogColor			: FOG_COLOR;
float4 cEntityColor 		: ENTITY_COLOR;
float3 cAmbientColor 	: AMBIENT_COLOR;
float2 FogPlane			: FOG_PLANE;
uniform float FogBaseY;
uniform float FogFall;
uniform float FogDepth;
uniform float FogTime;
uniform float FogPatch;
uniform float FogPatchScale;
float4 Material			: ENTITY_MATERIAL;
float3 EyePos			: EYE_POSITION;
float4 BonesMatrices[MAX_BONES * 3] : BONE_MATRICES;
bool Transparent : ALPHABLENDENABLE;

static const float4 EntityColor = float4(SRGBToLinear(cEntityColor.rgb), cEntityColor.a);
static const float3 FogColor = round(cFogColor * 255.0) / 255.0;
static const float3 AmbientColor = SRGBToLinear(cAmbientColor);

static float3 HSkyColor  = AmbientColor * float3(0.85, 1.00, 1.25) * 1.35;
static float3 HMidColor    = AmbientColor * float3(1.00, 1.00, 1.00) * 0.85;
static float3 HGroundColor = AmbientColor * float3(1.15, 0.95, 0.75) * 0.45;

float3x2 TextureMatrix : MATRIX_TEXTURE0;

float4x4 Proj			: MATRIX_PROJECTION;

DeclareSampler(DiffuseMap, 0, BLITZ_FILTER_ANISOTROPY, BLITZ_ADDR_WRAP, BLITZ_ADDR_WRAP, TextureLodBias, Anisotropy);

#ifdef NORMALMAP
	DeclareSampler(NormalMap, 1, BLITZ_FILTER_ANISOTROPY, BLITZ_ADDR_WRAP, BLITZ_ADDR_WRAP, TextureLodBias, Anisotropy);
#endif

#ifdef ORM
	DeclareSampler(MaterialMap, 2, BLITZ_FILTER_ANISOTROPY, BLITZ_ADDR_WRAP, BLITZ_ADDR_WRAP, TextureLodBias, Anisotropy);
#endif

#ifdef EMISSIVEMAP
	DeclareSampler(EmissiveMap, 3, BLITZ_FILTER_ANISOTROPY, BLITZ_ADDR_WRAP, BLITZ_ADDR_WRAP, TextureLodBias, Anisotropy);
#endif

#ifdef HEIGHTMAP
	DeclareSampler(HeightMap, 4, BLITZ_FILTER_ANISOTROPY, BLITZ_ADDR_WRAP, BLITZ_ADDR_WRAP, TextureLodBias, Anisotropy);
#endif

#define PROBE_COUNT 4

DeclareCubeTexture(tProbeEnvMap0, ProbeEnvMap0, BLITZ_FILTER_LINEAR, BLITZ_ADDR_WRAP, BLITZ_ADDR_WRAP, 0.0, 1);
DeclareCubeTexture(tProbeEnvMap1, ProbeEnvMap1, BLITZ_FILTER_LINEAR, BLITZ_ADDR_WRAP, BLITZ_ADDR_WRAP, 0.0, 1);
DeclareCubeTexture(tProbeEnvMap2, ProbeEnvMap2, BLITZ_FILTER_LINEAR, BLITZ_ADDR_WRAP, BLITZ_ADDR_WRAP, 0.0, 1);
DeclareCubeTexture(tProbeEnvMap3, ProbeEnvMap3, BLITZ_FILTER_LINEAR, BLITZ_ADDR_WRAP, BLITZ_ADDR_WRAP, 0.0, 1);
#ifdef D3D11
	#define PROBE_ENV_ARGS(i) tProbeEnvMap##i, ProbeEnvMap0
#else
	#define PROBE_ENV_ARGS(i) ProbeEnvMap##i
#endif

#ifdef TERRAIN
	DeclareSampler(PathMap, 1, BLITZ_FILTER_ANISOTROPY, BLITZ_ADDR_WRAP, BLITZ_ADDR_WRAP, TextureLodBias, Anisotropy);
	DeclareSampler(MaskMap, 2, BLITZ_FILTER_LINEAR, BLITZ_ADDR_CLAMP, BLITZ_ADDR_CLAMP, 0.0, 1);
#endif

#ifdef VEGETATION
	int Time : TIME;
	uniform float WindPower;
	uniform float WindFreq;
#endif

uniform float EmissiveMultiplier = 1.0;
uniform float FogMultiplier = 1.0;

uniform float ProbeMaxMip = 7.0;
uniform float4 ProbeIntensity[PROBE_COUNT];
uniform float4 ProbeBoxCenter[PROBE_COUNT];
uniform float4 ProbeBoxExtent[PROBE_COUNT];
uniform float4 ProbeBlends[PROBE_COUNT];

uniform bool Reflections = true;


#ifdef TERRAIN
uniform float4 TerrainMaskUV;
#endif

#include "Shading.fx"

// ==================================================== INPUT

struct VS_INPUT_F
{ 
	float4 Pos : POSITION; 
	float3 Normal : NORMAL;
	float2 TexCoords : TEXCOORD0;
	
	#if defined(NORMALMAP) || defined(HEIGHTMAP)
		float3 Tangent : TEXCOORD2;
		float3 Binormal : TEXCOORD3;
	#endif
	
	float4 BlendWeights : BLENDWEIGHT;
	uint4 BlendIndices : BLENDINDICES;
	float4 VertexColor : COLOR0;

	float4 IM1 : TEXCOORD4;
	float4 IM2 	: TEXCOORD5;
	float4 IM3 	: TEXCOORD6;
	float4 Color : COLOR1;
};

struct VS_OUTPUT
{
	float4 Pos : OUT_POSITION; 
	float3 Normal : NORMAL;
	float2 TexCoords : TEXCOORD0;
	float3 WorldPos : TEXCOORD1;
	#if defined(NORMALMAP) || defined(HEIGHTMAP)
		float3 Tangent : TEXCOORD3;
		float3 Binormal : TEXCOORD4;
	#endif
	float4 Color : COLOR0;
	
	#ifdef EMISSIVECOLOR
	float4 EmissiveColor : COLOR1;
	#endif
	
	float4 ScreenPosition : TEXCOORD5;

	#ifdef VERTEXLIT
	float3 LightTerm : TEXCOORD6;
	#endif
};

// ===================================================================================== TECHNIQUES

inline void GetVertexData(in VS_INPUT_F input, inout VS_OUTPUT output, float4x3 WorldTransform)
{
	output.WorldPos = mul(input.Pos, WorldTransform);
	
	#ifdef VEGETATION
		float3 vTop = output.WorldPos;
		float3 vBase = mul(float4(0, 0, 0, 1), WorldTransform);
		float vHigh = max(0.0, vTop.y - vBase.y);
		float vPhase = vBase.x * 0.42 + vBase.z * 0.37;
		float vTime = float(Time % 262144) * 0.001;
		float vPower = WindPower;
		float vFreq = WindFreq;
		float vGust = 0.72 + 0.28 * sin(vTime * 0.11 + vPhase * 0.05);
		float vSway = sin(vTime * 6.283185 * vFreq + vPhase)
		            + sin(vTime * 6.283185 * vFreq * 2.17 + vPhase * 1.3 + 1.3) * 0.12;
		float vAmp = vSway * vGust * vHigh * vPower;
		output.WorldPos += float3(vAmp, 0.0, vAmp * 0.55);
	#endif
	
	output.Pos = mul(float4(output.WorldPos, 1), ViewProj);

	output.TexCoords = mul(float3(input.TexCoords, 1.0), TextureMatrix);

	output.Normal = normalize(mul(input.Normal, WorldTransform));
	#if defined(NORMALMAP) || defined(HEIGHTMAP)
		output.Tangent = normalize(mul(input.Tangent, WorldTransform));
		output.Binormal = normalize(mul(input.Binormal, WorldTransform));
	#endif

	output.ScreenPosition = output.Pos;
	
	#ifdef VERTEXLIT
		#ifndef FULLBRIGHT
			float2 vLightPx = GetScreenTexCoords(output.ScreenPosition) * ScreenSize;
			output.LightTerm = GetVertexLight(output.WorldPos, normalize(output.Normal), vLightPx);
		#else
			output.LightTerm = 0.0;
		#endif
	#endif
}

VS_OUTPUT VS_Base(VS_INPUT_F input)
{
	VS_OUTPUT output;
	
	#ifndef EMISSIVECOLOR
		output.Color = input.VertexColor * EntityColor;
	#else
		output.Color = input.VertexColor;
		output.EmissiveColor = EntityColor;
	#endif
	
	GetVertexData(input, output, World);
	return output;
}

VS_OUTPUT VS_Instanced(VS_INPUT_F input)
{
	VS_OUTPUT output;
	#ifndef EMISSIVECOLOR
		output.Color = input.VertexColor * input.Color;
	#else
		output.Color = input.VertexColor;
		output.EmissiveColor = input.Color;
	#endif
	
	GetVertexData(input, output, GetInstanceTransform(input.IM1, input.IM2, input.IM3));
	return output;
}

VS_OUTPUT VS_Skinned(VS_INPUT_F input)
{ 
	VS_OUTPUT output;
	
	#ifndef EMISSIVECOLOR
		output.Color = input.VertexColor * EntityColor;
	#else
		output.Color = input.VertexColor;
		output.EmissiveColor = EntityColor;
	#endif
	
	GetVertexData(input, output, GetSkinTransform(World, BonesMatrices, input.BlendIndices, input.BlendWeights));
	return output;
}

inline float FogAmount(float3 worldPos, float near)
{
	float d = distance(EyePos, worldPos);
	return saturate((d - near) / max(FogPlane.y - near, 0.0001));
}

inline void GetMaterial(in VS_OUTPUT input, out float4 color, out float fogFactor)
{
	float4 diffuse;
	float3 normal;
	float3 material;
	float3 additive = 0.0;
    float2 texCoords = input.TexCoords;
	
    #ifdef HEIGHTMAP
        float2 dx = ddx(texCoords);
        float2 dy = ddy(texCoords);
        
        #define SampleTexture(tex, uv) Sample2DGrad(tex, uv, dx, dy)

        float3 N = normalize(input.Normal);
        float3 T = normalize(input.Tangent);
        float3 B = normalize(input.Binormal);

        T = normalize(T - dot(T, N) * N);
        B = normalize(B - dot(B, N) * N - dot(B, T) * T);
        
        float3x3 TBN = float3x3(T, B, N);

        float3 viewDirP = normalize(EyePos - input.WorldPos);
        float VdotN = dot(viewDirP, N);
        float3 viewDirM = mul(TBN, viewDirP);

        #ifdef D3D11
            texCoords = ParallaxOcclusionMapping(tHeightMap, HeightMap, texCoords, viewDirM, VdotN, 0.025, dx, dy);
        #else
            texCoords = ParallaxOcclusionMapping(HeightMap, texCoords, viewDirM, VdotN, 0.025, dx, dy);
        #endif
    #else
        #define SampleTexture(tex, uv) Sample2D(tex, uv)
    #endif
    
    diffuse = SRGBToLinear(SampleTexture(DiffuseMap, texCoords));

    #ifdef TERRAIN
        float4 pathColor = SRGBToLinear(SampleTexture(PathMap, texCoords));
        float terrainMask = Sample2D(MaskMap, texCoords * TerrainMaskUV.xy + TerrainMaskUV.zw).a;
        diffuse = float4(lerp(diffuse.rgb, pathColor.rgb, terrainMask), diffuse.a);
    #endif

    #ifdef ORM
        // Standard ORM: R - AO, G - Roughness, B - Metalness
        float4 MaterialData = SampleTexture(MaterialMap, texCoords);
        material.x = MaterialData.g + Material.b; // Roughness
        material.y = MaterialData.b + Material.a; // Metalness
		material.z = MaterialData.r;
    #else
        material.x = Material.b;
        material.y = Material.a;
		material.z = 1.0;
    #endif

    #if defined(D3D11) && defined(MASKED)
        clip(diffuse.a - 0.5f);
    #endif
    
    diffuse *= input.Color;

	float3 geoNormal = normalize(input.Normal);
	
    #ifdef NORMALMAP
        float3 bump = SampleTexture(NormalMap, texCoords).rgb * 2.0 - 1.0;
        normal = normalize((bump.x * input.Tangent) + (bump.y * input.Binormal) + (bump.z * input.Normal));
    #else
        normal = geoNormal;
    #endif

    material.x = clamp(material.x, 0.04, 1.0);
    material.y = clamp(material.y, 0.0, 1.0);

    float3 diffColor = diffuse.rgb * (1.0 - material.y);
    float3 F0 = lerp(float3(0.04, 0.04, 0.04), diffuse.rgb, material.y);
	
	#ifndef FULLBRIGHT
		float3 ambient = (HSkyColor * saturate(normal.y) + HGroundColor * saturate(-normal.y) + HMidColor * (1.0 - abs(normal.y))) * material.z;
    #else
        float3 ambient = float3(1, 1, 1) * material.z;
    #endif

    #if defined(EMISSIVEMAP)
        float3 emissive = SampleTexture(EmissiveMap, texCoords).rgb;
		
        #ifdef EMISSIVECOLOR
        emissive *= input.EmissiveColor.rgb;
        #endif
		
        emissive = SRGBToLinear(emissive) * EmissiveMultiplier;

        color = float4(diffColor * ambient, diffuse.a) + float4(emissive, 0.0);
        float near = lerp(FogPlane.x, FogPlane.y, GetIntensity(emissive) * 0.95);
        fogFactor = FogAmount(input.WorldPos, near) * FogMultiplier;
    #else
        color = float4(diffColor * ambient, diffuse.a);
        fogFactor = FogAmount(input.WorldPos, FogPlane.x) * FogMultiplier;
    #endif
    
    #if !defined(FULLBRIGHT)
        #if defined(VERTEXLIT)
            color.rgb += input.LightTerm * diffColor;
        #else
			const float3 eyeVector = normalize(EyePos - input.WorldPos);
            float2 screenPx = GetScreenTexCoords(input.ScreenPosition) * ViewportSize.zw;
			LightOutput light = GetForwardLight(input.WorldPos, normal, geoNormal, eyeVector, diffColor, F0, material.x, screenPx);
			
            color.rgb += light.diffuse;
			additive += light.specular;
        #endif

        [branch]if (Reflections)
        {
            float3 iblEyeVector = normalize(EyePos - input.WorldPos);
            float3 iblReflectDir = reflect(-iblEyeVector, normal);

            IBLContext iblCtx = PrepareIBL(iblReflectDir, normal, iblEyeVector, F0, material.x, ProbeMaxMip);
            
            float3 iblSum = 0.0;
            float iblWeightSum = 0.0;
            [unroll]
            for (int i = 0; i < PROBE_COUNT; ++i)
            {
                float3 iblBox = 0.5 - abs((input.WorldPos - ProbeBoxCenter[i].xyz) / max(2.0 * ProbeBoxExtent[i].xyz, 1e-4));

                float boxFade = saturate(min(min(iblBox.x, iblBox.y), iblBox.z) / 0.05);
                boxFade = boxFade * boxFade * (3.0 - 2.0 * boxFade);

                float iblWeight = boxFade * saturate(ProbeBlends[i].x);
                iblWeightSum += iblWeight;

                if (iblWeight > 0.0)
                {
                    const float3 projReflect = BoxProject(iblCtx.reflectDir, input.WorldPos, ProbeBoxCenter[i].xyz, ProbeBoxExtent[i].xyz);
                    const float3 intensity = ProbeIntensity[i].rrr;
                    
                    float3 probeRefl = 0.0;
                    switch (i)
                    {
                        case 0: probeRefl = SampleIBL(PROBE_ENV_ARGS(0), iblCtx, projReflect, intensity); break;
                        case 1: probeRefl = SampleIBL(PROBE_ENV_ARGS(1), iblCtx, projReflect, intensity); break;
                        case 2: probeRefl = SampleIBL(PROBE_ENV_ARGS(2), iblCtx, projReflect, intensity); break;
                        case 3: probeRefl = SampleIBL(PROBE_ENV_ARGS(3), iblCtx, projReflect, intensity); break;
                    }
                    iblSum += probeRefl * iblWeight;
                }
            }

            float iblCoverage = saturate(iblWeightSum);
            iblCoverage = iblCoverage * iblCoverage * (3.0 - 2.0 * iblCoverage);
            float3 iblColor = (iblSum / max(iblWeightSum, 1e-4)) * iblCoverage * material.z;
            additive += iblColor;
        }
    #endif

    color.rgb = color.rgb * color.a + additive;
}

float4 PS_Forward(VS_OUTPUT input) : OUTPUT(0)
{
	float4 color;
	float fogFactor;
	GetMaterial(input, color, fogFactor);

	color.rgb = lerp(color.rgb, FogColor * color.a, fogFactor);
	
	return color;
}

technique Forward
{
	pass Input
	{
		Vertex(VS_Base);
		Pixel(PS_Forward);
	}
}

technique Forward::Instanced
{
	pass Input
	{
		Vertex(VS_Instanced);
		#ifndef D3D11
		Pixel(PS_Forward);
		#endif
	}
}

technique Forward::Skinned
{
	pass Input
	{
		Vertex(VS_Skinned);
		#ifndef D3D11
		Pixel(PS_Forward);
		#endif
	}
}