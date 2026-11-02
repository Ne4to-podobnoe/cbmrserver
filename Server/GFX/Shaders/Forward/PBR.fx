static const float PI = 3.14159265358979323846;
static const float INV_PI = 0.31830988618379067154;
static const float Epsilon = 1e-5;

struct IBLContext
{
    float3 reflectDir;
    float  mipSelect;
    float3 envBRDF;
};

float D_GGX(float NdotH, float a2)
{
    float d = 1.0 - NdotH * NdotH * (1.0 - a2);
    return a2 / max(PI * d * d, 1e-7);
}

float3 F_Schlick(float VdotH, float3 F0)
{
    float x = saturate(1.0 - VdotH);
    float x2 = x * x;
    float fc = x2 * x2 * x;
    return F0 + (1.0 - F0) * fc;
}

float V_SmithJointApprox(float NdotL, float NdotV, float a)
{
    float k = 1.0 - a;
    float vis = 2.0 * k * NdotL * NdotV + a * (NdotL + NdotV);
    return 0.5 / max(vis, 1e-5);
}

float DisneyDiffuse(float NdotV, float NdotL, float LdotH, float perceptualRoughness)
{
    float fd90 = 0.5 + 2.0 * LdotH * LdotH * perceptualRoughness;
    float xl = saturate(1.0 - NdotL);
    float xv = saturate(1.0 - NdotV);
    float xl2 = xl * xl;
    float xv2 = xv * xv;
    float lightScatter = 1.0 + (fd90 - 1.0) * (xl2 * xl2 * xl);
    float viewScatter  = 1.0 + (fd90 - 1.0) * (xv2 * xv2 * xv);
    return lightScatter * viewScatter;
}

struct LightOutput
{
    float3 diffuse;
    float3 specular;
};

LightOutput CalculatePBRLight(float3 lightVec, float3 lightColor, float3 viewDir, float3 normal,
                              float3 diffuseColor, float3 F0, float roughness)
{
    float3 lightDir = normalize(lightVec);
    float ndl = dot(normal, lightDir);
    #ifdef MASKED // Usually, masked surfaces is two sided, so lit two sides
    float NdotL = abs(ndl); 
    #else
    float NdotL = saturate(ndl);
    #endif
    float NdotV = max(saturate(dot(normal, viewDir)), 1e-4);

    float3 H;
    float  specNdotL  = NdotL;
    float  energyNorm = 1.0;

    float a  = roughness * roughness;
    float a2 = a * a;
    float specA  = a;
    float specA2 = a2;

    #ifdef TUBE
        float3 R = reflect(-viewDir, normal);
        float RdotTube = dot(R, tubeDir);
        float LdotTube = dot(lightVec, tubeDir);
        float RdotL    = dot(R, lightVec);

        float denom = 1.0 - RdotTube * RdotTube + 1e-5;
        float t = clamp((RdotTube * RdotL - LdotTube) / denom,
                        -tubeLength, tubeLength);
        float3 specLightDir = normalize(lightVec + tubeDir * t);

        H = normalize(viewDir + specLightDir);

        float lightDist = length(lightVec);
        energyNorm = 1.0 / (1.0 + (tubeLength * 2.0) / (lightDist + 1e-5));

        float tubeRadius = tubeLength * 0.1;
        float specRough  = saturate(roughness + tubeRadius / (lightDist + 1e-5));
        specA  = specRough * specRough;
        specA2 = specA * specA;

        specNdotL = saturate(dot(normal, specLightDir));
    #else
        H = normalize(viewDir + lightDir);
    #endif

    float NdotH = saturate(dot(normal, H));
    float VdotH = saturate(dot(viewDir, H));
    float LdotH = saturate(dot(lightDir, H));

    float  D = D_GGX(NdotH, specA2);
    float  V = V_SmithJointApprox(specNdotL, NdotV, specA);
    float3 F = F_Schlick(VdotH, F0);

    float  disney   = DisneyDiffuse(NdotV, NdotL, LdotH, roughness);
    float3 diffuse  = (1.0 - F) * (diffuseColor * (INV_PI * disney));
    float3 specular = F * (D * V) * energyNorm;

    LightOutput output;
    output.diffuse  = diffuse  * (NdotL     * lightColor);
    output.specular = specular * (specNdotL * lightColor);
    return output;
}

float3 EnvBRDFApprox(float3 specColor, float roughness, float ndv)
{
    const float4 c0 = float4(-1, -0.0275, -0.572, 0.022);
    const float4 c1 = float4( 1,  0.0425,  1.0,  -0.04);
    float4 r = roughness * c0 + c1;
    float a004 = min(r.x * r.x, exp2(-9.28 * ndv)) * r.x + r.y;
    float2 AB = float2(-1.04, 1.04) * a004 + r.zw;
    return max(specColor * AB.x + AB.y, 0.0);
}

float3 GetSpecularDominantDir(float3 normal, float3 reflection, float roughness)
{
    float smoothness = 1.0 - roughness;
    float lerpFactor = smoothness * (sqrt(smoothness) + roughness);
    return lerp(normal, reflection, lerpFactor);
}

inline IBLContext PrepareIBL(float3 reflectVec, float3 normal, float3 viewDir,
                             float3 F0, float roughness, float maxMip)
{
    IBLContext ctx;
    float NdotV = max(saturate(dot(normal, viewDir)), 1e-4);

    ctx.envBRDF = EnvBRDFApprox(F0, roughness, NdotV);
    ctx.reflectDir = GetSpecularDominantDir(normal, reflectVec, roughness);

    float mipCurve = roughness * (1.7 - 0.7 * roughness)
                   + 0.67 * roughness * (1.0 - roughness)
                   - 0.25 * pow(1.0 - roughness, 6.0);
    ctx.mipSelect  = saturate(mipCurve) * maxMip;

    return ctx;
}

#ifdef D3D11
float3 SampleIBL(TextureCube tcubeMap, SamplerState cubeMap, IBLContext ctx, float3 projReflect, float3 intensity)
#else
float3 SampleIBL(samplerCUBE cubeMap, IBLContext ctx, float3 projReflect, float3 intensity)
#endif
{
    float3 cubeSpec = SampleCubeLOD(cubeMap, float4(projReflect, ctx.mipSelect)).rgb * intensity;
    return cubeSpec * ctx.envBRDF;
}