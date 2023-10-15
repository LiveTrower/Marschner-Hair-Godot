#include "common_math.gdshaderinc"

float hairStrand(vec3 T, vec3 V, vec3 L, float specular_power, float specular_width, float specular_scale)
{
	vec3 H = normalize(V + L);

	float HdotT = dot(T, H);
	float sinTH = max(0.01, sqrt(1.0 - pow(HdotT, 2)));
	float dirAtten = smoothstep(-specular_width, 0, HdotT);

	return dirAtten * saturate(pow(sinTH, specular_power)) * specular_scale;
}

vec3 shiftTangent(vec3 T, vec3 N, float shift)
{
	return normalize(T + shift * N);
}

float HairIOF(float Eccentric) {
	float n = 1.55;
	float a = 1.0 - Eccentric;
	float ior1 = 2.0 * (n - 1.0) * (a * a) - n + 2.0;
	float ior2 = 2.0 * (n - 1.0) / (a * a) - n + 2.0;
	return 0.5f * ((ior1 + ior2) + 0.5f * (ior1 - ior2)); //assume cos2PhiH = 0.5f 
}

float Hair_G(float B, float Theta)
{
	return exp(-0.5 * square(Theta) / (B*B)) / (SQRT2PI * B);
}

vec3 SpecularFresnel(vec3 F0, float vDotH) {
	return F0 + (1.0f - F0) * pow(1.0 - vDotH, 5);
}

vec3 getAmbientAndDiffuse(vec3 albedo, float scatter, mediump vec3 N, vec3 L, vec3 V, float shadow)
{
	float KajiyaDiffuse = 1.0 - abs(dot(N, L));
	
	vec3 FakeNormal = normalize(V - N * dot(V, N));
	N = FakeNormal;
	
	// Hack approximation for multiple scattering.
	float Wrap = 1.0;
	float NoL = saturate((dot(N, L) + Wrap) / square(1.0 + Wrap));
	float DiffuseScatter = (1.0 / PI) * mix(NoL, KajiyaDiffuse, 0.33) * scatter;
	float Luma = luminance(albedo);
	vec3 ScatterTint = pow(albedo / Luma, vec3(1.0) - shadow);
	vec3 ambientDiffuse = sqrt(albedo) * DiffuseScatter * ScatterTint;
	return ambientDiffuse;
}

// From Anisotropic Rendering (2) Kajiya Kay Hair Rendering https://zhuanlan.zhihu.com/p/363829203
vec3 getSpecularKajiyaKay(float specular_shift, vec3 primaryColor, float primaryShift, vec3 secondaryColor, float secondaryShift, vec3 N, vec3 T, vec3 V, vec3 L, float specular_power, float specular_width, float specular_scale)
{
	vec3 t1 = shiftTangent(T, N, primaryShift + specular_shift);
	vec3 t2 = shiftTangent(T, N, secondaryShift + specular_shift);

	vec3 specular = vec3(0.0);
	specular += primaryColor * hairStrand(t1, V, L, specular_power, specular_width, specular_scale) * specular_scale;
	specular += secondaryColor * hairStrand(t2, V, L, specular_power, specular_width, specular_scale) * specular_scale;
    return specular;
}

vec3 getSpecularMarschner(vec3 property, vec3 L, vec3 V, vec3 N, vec3 albedo, float roughness, float specular, float eccentricity_mean, float Backlit, float Area)
{
	vec3 S = vec3(0.0);

	float VoL = dot(V, L);
	float SinThetaL = clamp(dot(N, L), -1.0, 1.0);
	float SinThetaV = clamp(dot(N, V), -1.0, 1.0);
	float CosThetaD = cos(0.5 * abs(asinFast(SinThetaV) - asinFast(SinThetaL)));

	vec3 Lp = L - SinThetaL * N;
	vec3 Vp = V - SinThetaV * N;
	float CosPhi = dot(Lp, Vp) * inversesqrt(dot(Lp, Lp) * dot(Vp, Vp) + 1e-4);
	float CosHalfPhi = sqrt(saturate(0.5 + 0.5 * CosPhi));

	float n_prime = 1.19 / CosThetaD + 0.36 * CosThetaD;

	float Shift = 0.035;
	float Alpha[] =
	{
		-Shift * 2.0, //-0.0998,
		Shift, //0.0499f,
		Shift * 4.0 // 0.1996
	};
	float roug = clamp(roughness, 1.0/255.0f, 1.0f);
	float B[] =
	{
		Area + square(roug),
		Area + square(roug) / 2.0,
		Area + square(roug) * 2.0
	};

	float eccentric = mix(0.0f, eccentricity_mean * 2.0, property.r);
	float hairIOF = HairIOF(eccentric);
	float F0 = square((1.0 - hairIOF) / (1.0 + hairIOF));

	vec3 Tp;
	float Mp, Np, Fp, a, h, f;
	float ThetaH = SinThetaL + SinThetaV;
	
	// R
	float sa = sin( Alpha[0] );
	float ca = cos( Alpha[0] );
	float Shift2 = 2.0*sa* ( ca * CosHalfPhi * sqrt( 1.0 - SinThetaV * SinThetaV ) + sa * SinThetaV ) ;
	Mp = Hair_G(B[0] * sqrt(2.0) * CosHalfPhi, ThetaH - Shift2);
	Np = 0.25 * CosHalfPhi;
	Fp = SpecularFresnel(vec3(F0), sqrt(saturate(0.5 + 0.5 * VoL))).x;
	S += Mp * Np * Fp  * (specular * 2.0) * mix(1.0, Backlit, saturate(-VoL));

	// TT
	Mp = Hair_G(B[1], ThetaH - Alpha[1] );
	a = (1.55f / hairIOF) * rcp(n_prime);
	h = CosHalfPhi * (1.0 + a * (0.6 - 0.8 * CosPhi));
	f = SpecularFresnel(vec3(F0), CosThetaD * sqrt(saturate(1.0 - h * h))).x;
	Fp = square(1.0 - f);
	Tp = pow(albedo, vec3(0.5 * sqrt(1.0 - square((h * a))) / CosThetaD));
	Np = exp(-3.65 * CosPhi - 3.98);
	S += Mp * Np * Fp * Tp * Backlit;

	// TRT
	Mp = Hair_G(B[2], ThetaH - Alpha[2]);
	f = SpecularFresnel(vec3(F0), CosThetaD * 0.5f).x;
	Fp = square(1.0 - f) * f;
	Tp = pow(albedo, vec3(0.8 / CosThetaD));
	Np = exp(17.0 * CosPhi - 16.78);

	S += Mp * Np * Fp * Tp;

	return S;
}