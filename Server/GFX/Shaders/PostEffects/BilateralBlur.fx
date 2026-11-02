//--------------------------------------------------------------------------
//	THIS FILE IS A PRIVATE PROPERTY OF EUCLID LABS STUDIO.
//	THIS SHADER MAY NOT BE USED IN ANY PROJECTS
//	WITHOUT THE EXPLICIT PERMISSION OF THE RIGHTS HOLDER. ANY USE OF THESE FILES
//	IN YOUR PROJECTS REQUIRES PRIOR AGREEMENT WITH THE RIGHTS HOLDER.
//	YOU CAN CONTACT US BY MAILING US ON EUCLIDLABSSTUDIO@GMAIL.COM.
//--------------------------------------------------------------------------

#include "..\Forward\Tools.fx"

uniform float2 BlurInvSize;
uniform float FarClip;
uniform float4x4 InvViewProj;
uniform float3 CameraPosition;
uniform float2 LowResTexelSize;

static const int MAX_WEIGHTS = 9;
static const float offsets[MAX_WEIGHTS] = {
    4.0, 3.0, 2.0, 1.0, 0.0, -1.0, -2.0, -3.0, -4.0
};
static const float weights[MAX_WEIGHTS] = {
    0.052, 0.092, 0.122, 0.152, 0.162, 0.152, 0.122, 0.092, 0.052
};
	
static const float DEPTH_FALLOFF = 2.f;
static const float BLUR_SHARPNESS = 500.0f;

DeclareSampler(ColorMap, 0, BLITZ_FILTER_LINEAR, BLITZ_ADDR_CLAMP, BLITZ_ADDR_CLAMP, 0.0, 1);
DeclareSampler(DepthMap, 1, BLITZ_FILTER_POINT, BLITZ_ADDR_CLAMP, BLITZ_ADDR_CLAMP, 0.0, 1);
DeclareSampler(DepthMapLow, 2, BLITZ_FILTER_POINT, BLITZ_ADDR_CLAMP, BLITZ_ADDR_CLAMP, 0.0, 1);

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

inline float LinearDepth(float2 uv)
{
	return GetEyeDistance(uv, Sample2D(DepthMap, uv).r, InvViewProj, CameraPosition);
}

float4 BilateralProcess(PS_INPUT input) : OUTPUT(0)
{
	return float4(LinearDepth(input.TexCoord), 0, 0, 1);
}

float4 BlurProcess(PS_INPUT input) : OUTPUT(0)
{
    float centerDepth = LinearDepth(input.TexCoord);

    float3 accColor = Sample2D(ColorMap, input.TexCoord).rgb * weights[4];
    float totalWeight = weights[4];
    
    float far = step(FarClip * 0.9, centerDepth);

    [unroll]
    for (int i = 0; i < MAX_WEIGHTS; i++)
    {
        if (i == 4) continue;

        float2 tex = input.TexCoord + BlurInvSize * offsets[i];
        float neighborDepth = LinearDepth(tex);

        float depthDiff = centerDepth - neighborDepth;

        float rangeWeight = exp(-(depthDiff * depthDiff) * BLUR_SHARPNESS);
        
        float neighborfar = step(FarClip * 0.9, neighborDepth);
        float weight = weights[i] * lerp(rangeWeight, neighborfar, far);
        
        accColor += weight * Sample2D(ColorMap, tex).rgb;
        totalWeight += weight;
    }

    return float4(accColor / totalWeight, 1.0);
}

float4 FinalProcess(PS_INPUT input) : OUTPUT(0)
{
    float fullResDepth = LinearDepth(input.TexCoord);

    float3 centerColor = Sample2D(ColorMap, input.TexCoord).rgb;
    
    float2 lowResUV = input.TexCoord;
    float2 base_uv = floor(lowResUV / LowResTexelSize - 0.5) * LowResTexelSize + 0.5 * LowResTexelSize;

    float3 totalColor = float3(0, 0, 0);
    float totalWeight = 0.00001f;

    float minDepthDiff = 99999.0f;
    float3 closestColor = centerColor;

    [unroll]
    for(int i = 0; i < 4; i++)
    {
        float2 offset = float2(i % 2, i / 2) * LowResTexelSize;
        float2 sampleUV = base_uv + offset;

        float3 low = Sample2D(ColorMap, sampleUV).rgb;
        float depthLow = Sample2D(DepthMapLow, sampleUV).r;

        float depthDiff = abs(fullResDepth - depthLow);

        if (depthDiff < minDepthDiff)
        {
            minDepthDiff = depthDiff;
            closestColor = low;
        }

        float weight = exp(-(depthDiff * depthDiff) * BLUR_SHARPNESS); 

        totalColor += low * weight;
        totalWeight += weight;
    }

    float3 finalColor;

    if (totalWeight < 0.01f) 
    {
        finalColor = closestColor;
    }
    else 
    {
        finalColor = totalColor / totalWeight;
    }

    float far = step(fullResDepth, FarClip - 0.01);
    return float4(lerp(centerColor, finalColor, far), 1.0);
}

float4 FinalSimpleProcess(PS_INPUT input) : OUTPUT(0)
{
    return float4(Sample2D(ColorMap, input.TexCoord).rgb, 1.0);
}

technique Bilateral
{
	pass p0
	{
		Vertex(VertexProcess);
		Pixel(BilateralProcess);
	}
}

technique Blur
{
	pass p0
	{
		Vertex(VertexProcess);
		Pixel(BlurProcess);
	}
}

technique Final
{
	pass p0
	{
		Vertex(VertexProcess);
		Pixel(FinalProcess);
	}
}

technique FinalSimple
{
	pass p0
	{
		Vertex(VertexProcess);
		Pixel(FinalSimpleProcess);
	}
}
