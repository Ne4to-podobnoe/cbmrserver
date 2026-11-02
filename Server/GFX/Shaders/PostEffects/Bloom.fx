//--------------------------------------------------------------------------
//	THIS FILE IS A PRIVATE PROPERTY OF EUCLID LABS STUDIO.
//	THIS SHADER MAY NOT BE USED IN ANY PROJECTS
//	WITHOUT THE EXPLICIT PERMISSION OF THE RIGHTS HOLDER. ANY USE OF THESE FILES
//	IN YOUR PROJECTS REQUIRES PRIOR AGREEMENT WITH THE RIGHTS HOLDER.
//	YOU CAN CONTACT US BY MAILING US ON EUCLIDLABSSTUDIO@GMAIL.COM.
//--------------------------------------------------------------------------

#include "..\Forward\Tools.fx"

#define BLOOM_SAMPLES 8

uniform float BloomIntensity = 0.2f;
uniform float BloomSensitivity = 1.0f;
uniform float BloomCurve = 3.23f;
uniform float BloomSpread = 0.5f;
uniform float BloomExposure = 0.5f;
uniform float BloomSaturation = 0.7f;

uniform float BlurSize;
uniform float2 BlurInvSize;
uniform float2 HighestSize;

static const float2 BufferSize = 1.0 / HighestSize;

DeclareSampler(ColorMap, 0, BLITZ_FILTER_LINEAR, BLITZ_ADDR_CLAMP, BLITZ_ADDR_CLAMP, 0.0, 1);
DeclareSampler(BloomMap, 1, BLITZ_FILTER_LINEAR, BLITZ_ADDR_CLAMP, BLITZ_ADDR_CLAMP, 0.0, 1);
DeclareSampler(sBloomV_A, 2, BLITZ_FILTER_LINEAR, BLITZ_ADDR_CLAMP, BLITZ_ADDR_CLAMP, 0.0, 1);
DeclareSampler(sBloomH_B, 3, BLITZ_FILTER_LINEAR, BLITZ_ADDR_CLAMP, BLITZ_ADDR_CLAMP, 0.0, 1);
DeclareSampler(sBloomV_B, 4, BLITZ_FILTER_LINEAR, BLITZ_ADDR_CLAMP, BLITZ_ADDR_CLAMP, 0.0, 1);
DeclareSampler(sBloomH_C, 5, BLITZ_FILTER_LINEAR, BLITZ_ADDR_CLAMP, BLITZ_ADDR_CLAMP, 0.0, 1);
DeclareSampler(sBloomV_C, 6, BLITZ_FILTER_LINEAR, BLITZ_ADDR_CLAMP, BLITZ_ADDR_CLAMP, 0.0, 1);

struct PS_INPUT
{
    float4 Pos       : OUT_POSITION;
    float2 TexCoord  : TEXCOORD0;
};

PS_INPUT VertexProcess(VS_INPUT input)
{
    PS_INPUT output;

    output.Pos = mul(input.Pos, ViewProj);
	#ifdef D3D11
		output.TexCoord = GetScreenTexCoords(output.Pos);
	#else
		output.TexCoord = GetScreenTexCoords(output.Pos) + BlurInvSize;
	#endif
    return output;
}

#ifdef D3D11
float4 SampleBlur(texture2D ttex, sampler tex, float2 texcoords, float2 pixelsize)
#else
float4 SampleBlur(sampler2D tex, float2 texcoords, float2 pixelsize)
#endif
{
    return (Sample2D(tex, texcoords + float2(pixelsize.x, pixelsize.y)) +
		Sample2D(tex, texcoords + float2(-pixelsize.x, pixelsize.y)) +
		Sample2D(tex, texcoords + float2(pixelsize.x, -pixelsize.y)) +
		Sample2D(tex, texcoords + float2(-pixelsize.x, -pixelsize.y))) * 0.25f;
}

float4 CalculateBloom(float2 texcoord, float size, float2 dir)
{
    const float2 pixelSize = BufferSize * size;
    float offset = BloomSpread;

    float centerWeight = pow((float)BLOOM_SAMPLES, BloomCurve);
    float4 blur = Sample2DLod0(BloomMap, texcoord) * centerWeight;
    float totalWeight = centerWeight;

    for (int i = 1; i < BLOOM_SAMPLES; i++)
    {
        float2 d = float2(offset * pixelSize.x, offset * pixelSize.y) * dir;
        float weight = pow(abs((float)BLOOM_SAMPLES - (float)i), BloomCurve);

        blur += Sample2DLod0(BloomMap, texcoord + d) * weight;
        blur += Sample2DLod0(BloomMap, texcoord - d) * weight;

        offset += BloomSpread;
        totalWeight += weight * 2.0f;
    }

    return blur / totalWeight;
}

float3 ApplySaturation(float3 color, float saturation)
{
    float luma = dot(color, float3(0.299, 0.587, 0.114));
    return lerp(float3(luma, luma, luma), color, saturation);
}

float KarisWeight(float3 color)
{
    float luma = dot(color, float3(0.2126f, 0.7152f, 0.0722f));
    return 1.0f / (1.0f + luma);
}

float4 PS_Luma(PS_INPUT input) : OUTPUT(0)
{
    float2 uv = input.TexCoord;
    float2 ts = BufferSize;

    float3 A = Sample2DLod0(ColorMap, uv + float2(-2.0, -2.0) * ts).rgb;
    float3 B = Sample2DLod0(ColorMap, uv + float2( 0.0, -2.0) * ts).rgb;
    float3 C = Sample2DLod0(ColorMap, uv + float2( 2.0, -2.0) * ts).rgb;

    float3 D = Sample2DLod0(ColorMap, uv + float2(-2.0,  0.0) * ts).rgb;
    float3 E = Sample2DLod0(ColorMap, uv).rgb;
    float3 F = Sample2DLod0(ColorMap, uv + float2( 2.0,  0.0) * ts).rgb;

    float3 G = Sample2DLod0(ColorMap, uv + float2(-2.0,  2.0) * ts).rgb;
    float3 H = Sample2DLod0(ColorMap, uv + float2( 0.0,  2.0) * ts).rgb;
    float3 I = Sample2DLod0(ColorMap, uv + float2( 2.0,  2.0) * ts).rgb;

    float3 J = Sample2DLod0(ColorMap, uv + float2(-1.0, -1.0) * ts).rgb;
    float3 K = Sample2DLod0(ColorMap, uv + float2( 1.0, -1.0) * ts).rgb;
    float3 L = Sample2DLod0(ColorMap, uv + float2(-1.0,  1.0) * ts).rgb;
    float3 M = Sample2DLod0(ColorMap, uv + float2( 1.0,  1.0) * ts).rgb;

    float3 box0 = (J + K + L + M) * 0.25f;
    float3 box1 = (A + B + D + E) * 0.25f;
    float3 box2 = (B + C + E + F) * 0.25f;
    float3 box3 = (D + E + G + H) * 0.25f;
    float3 box4 = (E + F + H + I) * 0.25f;

    float w0 = 0.500f * KarisWeight(box0);
    float w1 = 0.125f * KarisWeight(box1);
    float w2 = 0.125f * KarisWeight(box2);
    float w3 = 0.125f * KarisWeight(box3);
    float w4 = 0.125f * KarisWeight(box4);

    float3 stableColor = (box0 * w0 + box1 * w1 + box2 * w2 + box3 * w3 + box4 * w4) / (w0 + w1 + w2 + w3 + w4 + 1e-5f);

    return float4(GetBloomLuma(stableColor, BloomSensitivity), 1.0f);
}

float4 PS_BloomH(PS_INPUT input) : OUTPUT(0)
{
    return CalculateBloom(input.TexCoord, BlurSize, float2(1, 0));
}

float4 PS_BloomV(PS_INPUT input) : OUTPUT(0)
{
    return CalculateBloom(input.TexCoord, BlurSize, float2(0, 1));
}

float4 PS_BlurBloom(PS_INPUT input) : OUTPUT(0)
{
	float3 LP = Sample2D(ColorMap, input.TexCoord).rgb;
	#ifdef D3D11
	    float4 Bloom  = SampleBlur(tBloomMap, BloomMap, input.TexCoord, BufferSize * 2);
           Bloom += SampleBlur(tsBloomV_A, sBloomV_A, input.TexCoord, BufferSize * 2);
           Bloom += SampleBlur(tsBloomH_B, sBloomH_B, input.TexCoord, BufferSize * 4);
           Bloom += SampleBlur(tsBloomV_B, sBloomV_B, input.TexCoord, BufferSize * 4);
           Bloom += SampleBlur(tsBloomH_C, sBloomH_C, input.TexCoord, BufferSize * 8);
           Bloom += SampleBlur(tsBloomV_C, sBloomV_C, input.TexCoord, BufferSize * 8);
	#else
    float4 Bloom  = SampleBlur(BloomMap, input.TexCoord, BufferSize * 2);
           Bloom += SampleBlur(sBloomV_A, input.TexCoord, BufferSize * 2);
           Bloom += SampleBlur(sBloomH_B, input.TexCoord, BufferSize * 4);
           Bloom += SampleBlur(sBloomV_B, input.TexCoord, BufferSize * 4);
           Bloom += SampleBlur(sBloomH_C, input.TexCoord, BufferSize * 8);
           Bloom += SampleBlur(sBloomV_C, input.TexCoord, BufferSize * 8);
	#endif
           Bloom *= lerp(0, 10, BloomIntensity) / 6;
    return float4(lerp(Bloom.rgb, max(Bloom.rgb - LP, 0.0), 0),0);
}

float4 PS_FinalBloom(PS_INPUT input) : OUTPUT(0)
{
	#ifdef D3D11
		float4 Bloom = SampleBlur(tBloomMap, BloomMap, input.TexCoord, BufferSize);
    #else
		float4 Bloom = SampleBlur(BloomMap, input.TexCoord, BufferSize);
	#endif
	
    Bloom.rgb = ApplySaturation(Bloom.rgb, BloomSaturation);
    
	return float4(Bloom.rgb * BloomExposure, 1.0f);
}

technique Luma
{
	pass p0
	{
		Vertex(VertexProcess);
		Pixel(PS_Luma);
	}
}

technique BloomH
{
	pass p0
	{
		Vertex(VertexProcess);
		Pixel(PS_BloomH);
	}
}

technique BloomV
{
	pass p0
	{
		Vertex(VertexProcess);
		Pixel(PS_BloomV);
	}
}

technique Blur
{
	pass p0
	{
		Vertex(VertexProcess);
		Pixel(PS_BlurBloom);
	}
}

technique Final
{
	pass p0
	{
		Vertex(VertexProcess);
		Pixel(PS_FinalBloom);
	}
}