#include "common.gdshaderinc"

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

// From Anisotropic Rendering (2) Kajiya Kay Hair Rendering https://zhuanlan.zhihu.com/p/363829203
vec3 specular_kajiya_kay(float specular_shift, vec3 primaryColor, float primaryShift, vec3 secondaryColor, float secondaryShift, vec3 N, vec3 T, vec3 V, vec3 L, float specular_power, float specular_width, float specular_scale)
{
	vec3 t1 = shiftTangent(T, N, primaryShift + specular_shift);
	vec3 t2 = shiftTangent(T, N, secondaryShift + specular_shift);
	
	vec3 specular = vec3(0.0);
	specular += primaryColor * hairStrand(t1, V, L, specular_power, specular_width, specular_scale) * specular_scale;
	specular += secondaryColor * hairStrand(t2, V, L, specular_power, specular_width, specular_scale) * specular_scale;
	return specular;
}