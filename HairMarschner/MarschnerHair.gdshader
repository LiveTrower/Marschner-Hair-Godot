shader_type spatial;
//Credits
//https://github.com/maajor/Marschner-Hair-Unity
render_mode cull_disabled;

#include "HairBxDF.gdshaderinc"

uniform sampler2D _MainTex : hint_default_white;
uniform sampler2D _Flowmap : hint_default_white;
uniform vec4 _RootColor : source_color = vec4(0,0,0,1);
uniform vec4 _TipColor : source_color = vec4(0,0,0,1);
uniform vec4 _ColorVariationRange = vec4(0,0,0,1);
uniform float _EccentricityMean = 0.07;
uniform float _Roughness : hint_range(0.0, 1.0, 0.01);
uniform vec3 diffuseColor : source_color = vec3(1.0);
uniform float scatter = 1.0;

varying vec3 binormal;

vec3 getAmbientAndDiffuse(vec3 lightColor, mediump vec3 N, vec3 L, vec3 V, float attenuation)
{
	vec3 albedo = lightColor * diffuseColor;
	float KajiyaDiffuse = 1.0 - abs(dot(N, L));
	
	vec3 FakeNormal = normalize(V - N * dot(V, N));
	N = FakeNormal;
	
	// Hack approximation for multiple scattering.
	float Wrap = 1.0;
	float NoL = saturate((dot(N, L) + Wrap) / square(1.0 + Wrap));
	float DiffuseScatter = (1.0 / PI) * mix(NoL, KajiyaDiffuse, 0.33) * scatter;
	float Luma = luminance(albedo);
	vec3 ScatterTint = pow(albedo / Luma, vec3(1.0));
	vec3 ambientDiffuse = sqrt(albedo) * DiffuseScatter * ScatterTint * attenuation;
	return ambientDiffuse;
}

vec3 getSpecularMarschner(vec3 L, vec3 V, vec3 N, vec3 albedo, float Backlit, float Area, vec2 uv)
{
	vec3 S = vec3(0.0);
	vec4 property = texture(_MainTex, uv);

	float VoL = dot(V, L);
	float SinThetaL = dot(N, L);
	float SinThetaV = dot(N, V);
	float cosThetaL = sqrt(max(0, 1.0 - SinThetaL * SinThetaL));
	float cosThetaV = sqrt(max(0, 1.0 - SinThetaV * SinThetaV));
	float CosThetaD = sqrt((1.0 + cosThetaL * cosThetaV + SinThetaV * SinThetaL) / 2.0);

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
	float roughness = clamp(_Roughness, 1.0/255.0f, 1.0f);
	float B[] =
	{
		Area + square(roughness),
		Area + square(roughness) / 2.0,
		Area + square(roughness) * 2.0
	};

	float eccentric = mix(0.0f, _EccentricityMean * 2.0, property.r);
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
	S += (Mp * Np) * (Fp * mix(1.0, Backlit, saturate(-VoL)));

	// TT
	Mp = Hair_G(B[1], ThetaH - Alpha[1] );
	a = (1.55f / hairIOF) * rcp(n_prime);
	h = CosHalfPhi * (1.0 + a * (0.6 - 0.8 * CosPhi));
	f = SpecularFresnel(vec3(F0), CosThetaD * sqrt(saturate(1.0 - h * h))).x;
	Fp = square(1.0 - f);
	Tp = pow(albedo, vec3(0.5 * sqrt(1.0 - square((h * a))) / CosThetaD));
	Np = exp(-3.65 * CosPhi - 3.98);
	S += (Mp * Np) * (Fp * Tp) * Backlit;

	// TRT
	Mp = Hair_G(B[2], ThetaH - Alpha[2]);
	f = SpecularFresnel(vec3(F0), CosThetaD * 0.5f).x;
	Fp = square(1.0 - f) * f;
	Tp = pow(albedo, vec3(0.8 / CosThetaD));
	Np = exp(17.0 * CosPhi - 16.78);

	S += (Mp * Np) * (Fp * Tp);

	return S;
}

void fragment(){
	mediump vec4 flowmap = texture(_Flowmap, UV);
	mediump vec4 property = texture(_MainTex, UV);
	vec3 basecolor = mix(_RootColor.rgb, _TipColor.rgb, property.b);
	vec3 basecolorHSV = rgb2hsv(basecolor);
	basecolorHSV += (property.g - 0.5) * _ColorVariationRange.rgb * _ColorVariationRange.a;
	ALBEDO = hsv2rgb(basecolorHSV);
	ALPHA = property.a;
	ALPHA_HASH_SCALE = 0.01;
	binormal = BINORMAL;
}

void light(){
	mediump vec3 V = normalize(VIEW);
	mediump vec3 N = normalize(NORMAL);
	mediump vec3 B = normalize(binormal);
	vec3 L = normalize(LIGHT);
	vec3 diffuse = getAmbientAndDiffuse(LIGHT_COLOR, N, L, V, ATTENUATION);
	vec3 specular = getSpecularMarschner(L, V, B, ALBEDO, 1.0, 0.0, UV);
	
	DIFFUSE_LIGHT += diffuse;
	SPECULAR_LIGHT += specular * LIGHT_COLOR * ATTENUATION * SPECULAR_AMOUNT;
}
