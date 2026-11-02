//--------------------------------------------------------------------------
//	THIS FILE IS A PRIVATE PROPERTY OF EUCLID LABS STUDIO.
//	THIS SHADER MAY NOT BE USED IN ANY PROJECTS
//	WITHOUT THE EXPLICIT PERMISSION OF THE RIGHTS HOLDER. ANY USE OF THESE FILES
//	IN YOUR PROJECTS REQUIRES PRIOR AGREEMENT WITH THE RIGHTS HOLDER.
//	YOU CAN CONTACT US BY MAILING US ON EUCLIDLABSSTUDIO@GMAIL.COM.
//--------------------------------------------------------------------------

#define GOLDEN_ANGLE 2.39996323
#define MAX_BLUR_TAPS 192

uniform float BLUR_SPREAD = 16.0;
uniform float BLUR_TAPS = 64.0;

DeclareSampler(Diffuse, 0, BLITZ_FILTER_LINEAR, BLITZ_ADDR_CLAMP, BLITZ_ADDR_CLAMP, 0.0, 1);

float4 PS_MenuBlur(float4 Pos : OUT_POSITION, float2 uv : TEXCOORD0, float2 puv : TEXCOORD1, float2 size : TEXCOORD2, float4 col : COLOR) : OUTPUT(0)
{
	float2 stepX = ddx(uv) * BLUR_SPREAD;
	float2 stepY = ddy(uv) * BLUR_SPREAD;
	int taps = (int)clamp(BLUR_TAPS, 1.0, float(MAX_BLUR_TAPS));
	float ftaps = float(taps);

	float4 c = Sample2DLod0(Diffuse, uv);
	float total = 1.0;

	for (int i = 0; i < taps; ++i)
	{
		float fi = (float(i) + 0.5) / ftaps;
		float radius = sqrt(fi);
		float angle = float(i) * GOLDEN_ANGLE;
		float2 offset = stepX * (cos(angle) * radius) + stepY * (sin(angle) * radius);
		float weight = exp(-2.0 * fi);

		c += Sample2DLod0(Diffuse, uv + offset) * weight;
		total += weight;
	}

	return (c / total) * col;
}

technique Main
{
	pass p0
	{
		Pixel(PS_MenuBlur);
	}
}
