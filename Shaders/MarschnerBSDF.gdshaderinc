/**
 * # Marschner BSDF adapted from https://github.com/Scthe/frostbitten-hair-webgpu/blob/master/src/passes/hairShadingPass/marschner.wgsl.ts
 *
 * - [Marschner03] http://www.graphics.stanford.edu/papers/hair/hair-sg03final.pdf
 * - [Karis16] https://blog.selfshadow.com/publications/s2016-shading-course/karis/s2016_pbs_epic_hair.pdf
 * - [Chiang16] https://benedikt-bitterli.me/pchfm/pchfm.pdf
 * - [Tafuri19] https://advances.realtimerendering.com/s2019/hair_presentation_final.pdf
 * - [Sadeghi10] http://graphics.ucsd.edu/~henrik/papers/artist_hair.pdf
 * - GPU gems chapter 23
 *
 * Additional series of posts by Voicu Alexandru–Teodor:
 * - https://hairrendering.wordpress.com/2010/06/26/marschner-shader-part-i/
 * - https://hairrendering.wordpress.com/2010/06/27/marschner-shader-part-ii/
 * - https://hairrendering.wordpress.com/2010/07/05/marschner-shader-part-iii/
 *
 */

#include "common.gdshaderinc"

float specular_fresnel(float F0, float vDotH) {
	return F0 + (1.0f - F0) * pow5(1.0 - vDotH);
}

/** Index of refraction for human hair */
const float HAIR_F0 = (1. - ETA) * (1. - ETA) / ((1. + ETA) * (1. + ETA));

float cos_of_half_angle(float cos_angle) {
	return sqrt(saturate(0.5 + 0.5 * cos_angle));
}

// Beta is based on the roughness of the fiber
// Alpha is based on the tilt of the cuticle scales
/** https://blog.selfshadow.com/publications/s2016-shading-course/karis/s2016_pbs_epic_hair.pdf#page=18 */
float longitudinal_scattering_gaussian(float sin_theta_i, float sin_theta_r, float alpha, float beta) {
	float a = sin_theta_i + sin_theta_r - alpha; // sin(theta_i) + sin(theta_r) - alpha;
	float b = -(a * a) / (2.0 * beta * beta);
	return exp(b) / (beta * SQRT_TWO_PI);
}

/** https://blog.selfshadow.com/publications/s2016-shading-course/karis/s2016_pbs_epic_hair.pdf#page=20 */
float azimuthal_scattering_r(float cos_theta_d, float cos_half_phi) {
	float attenuation = specular_fresnel(HAIR_F0, cos_theta_d);
	return 0.25 * cos_half_phi * attenuation;
}

/** https://blog.selfshadow.com/publications/s2016-shading-course/karis/s2016_pbs_epic_hair.pdf#page=23 */
vec3 azimuthal_scattering_tt(vec3 baseColor, float cos_theta_d, float cos_phi, float cos_half_phi) {
	float eta_prime = (1.19 / cos_theta_d) + (0.36 * cos_theta_d); // slide 26
	float a = 1.0 / eta_prime; // slide 25, should be an alpha, but 'a' is less confusing
	float h_TT = (1.0 + a * (0.6 - 0.8 * cos_phi)) * cos_half_phi; // slide 25

	// slide 28: absorption term
	float T_powNum = sqrt(1.0 - pow2(h_TT) * pow2(a));
	float T_powDenum = 2.0 * cos_theta_d;
	vec3 T_TT = pow(abs(baseColor), vec3(0.5 * T_powNum / T_powDenum));
	// slide 29: distribution
	float D_TT = exp(-3.65 * cos_phi - 3.98);
	// slide 25
	float f_angle = cos_theta_d * sqrt(saturate(1.0 - pow2(h_TT)));
	float f = specular_fresnel(HAIR_F0, f_angle);
	float f_TT = pow2(1.0 - f); // there is also F(...)^{p-1}, but we can skip

	return f_TT * T_TT * D_TT; // slide 23
}

/** https://blog.selfshadow.com/publications/s2016-shading-course/karis/s2016_pbs_epic_hair.pdf#page=32 */
vec3 azimuthal_scattering_trt(vec3 baseColor, float cos_theta_d, float cos_phi) {
	// slide 32: absorption term
	vec3 T_TRT = pow(baseColor, vec3(0.8 / cos_theta_d));
	// slide 32: distribution
	float D_TRT = exp(17.0 * cos_phi - 16.78);
	// slide 32
	// const h_TRT = ${Math.sqrt(3) / 2.0}; // slide 32
	// const f_angleMod_TRT = Math.sqrt(1.0 - h_TRT * h_TRT); // similar as for f_angle in TT
	float f_angle = cos_theta_d * 0.5; // substituted value from f_angleMod_TRT. It's literary 'Math.sqrt(1 - 3/4)'
	float f = specular_fresnel(HAIR_F0, f_angle);
	float f_TRT = pow2(1.0 - f) * f; // las multiply by 'f' cause F(...)^{p-1}

	return f_TRT * T_TRT * D_TRT; // like slide 23
}

vec3 specular_marschner(vec3 albedo, float specular, float roughness, vec3 light, vec3 view, vec3 tangent) {
	// from [Marschner03]
	// w_i - direction of illumination (w Illumination/Incoming)
	// w_r - direction in which scattered light is being computed (w Result)
	// theta_d - difference angle (theta_r − theta_i) / 2
	// There is also 5.2.3 'Approximation for eccentricity' if you are not as lazy as me (not implemented)

	// For derivation we are following GPU gems chapter 23.
	// dot() is used for sin() value. Interesting, but depends on which angle we are calculating the value for?
	float sin_theta_i = dot(tangent, light);
	float sin_theta_r = dot(tangent, view);
	// TODO [MEDIUM] does sign of cos matter for us?
	float cos_theta_i = sqrt(max(0., 1. - pow2(sin_theta_i))); // Pythagorean Identity
	float cos_theta_r = sqrt(max(0., 1. - pow2(sin_theta_r)));
	// Cosine-difference formula: cos(α−β) = cosα ⋅ cosβ + sinα ⋅ sinβ
	float cos_theta_d_fullAngle = cos_theta_i * cos_theta_r + sin_theta_i * sin_theta_r;
	float cos_theta_d = cos_of_half_angle(cos_theta_d_fullAngle); // theta_d is half angle, see above
	// GPU gems chapter 23, page 374
	vec3 lightPerp = light - sin_theta_i * tangent;
	vec3 cameraPerp = view - sin_theta_r * tangent;
	float cos_phi = dot(lightPerp, cameraPerp) * inversesqrt(length(lightPerp) * length(cameraPerp) + 1e-4);
	float cos_half_phi = cos_of_half_angle(cos_phi);

	// For each lobe (R, TT, TRT):
	// M_p(theta_i, theta_r) - longitudinal scattering function
	// N_p(theta_i, theta_r, phi) - azimuthal scattering function

	//Clamp roughness to avoid artifacts
	float clamped_roughness = clamp(roughness, 1.0/255.0f, 1.0f);

	// R: The light ray **REFLECTS** off the front of the hair fiber.
	// Not much color (smth. like specular), as the light does not penetrate strand.
	float shift = 0.035;
	float alpha = 2.0 * -shift;
	float beta = pow2(clamped_roughness);
	float M_r = longitudinal_scattering_gaussian(sin_theta_i, sin_theta_r, alpha, beta);
	float N_r = azimuthal_scattering_r(cos_theta_d, cos_half_phi);
	// TT: The light ray **TRANSMITS THROUGH** the front of the fiber,
	// passes through the interior which colors it due to absorption
	// and then transmits through the other side.
	// Some color. Light goes through the strand once.
	alpha = shift;
	beta = 0.5 * pow2(clamped_roughness);
	float M_tt = longitudinal_scattering_gaussian(sin_theta_i, sin_theta_r, alpha, beta);
	vec3 N_tt = azimuthal_scattering_tt(albedo, cos_theta_d, cos_phi, cos_half_phi);
	// TRT: The light ray transmits through the front of the fiber,
	// 1. **PASSES THROUGH** the colored interior.
	// 2. **REFLECTS** off the opposite side.
	// 3. **PASSES THROUGH** the interior again and transmits out the front.
	// A LOT of color. Light goes through the strand twice.
	alpha = 4.0 * shift;
	beta = 2.0 * pow2(clamped_roughness);
	float M_trt = longitudinal_scattering_gaussian(sin_theta_i, sin_theta_r, alpha, beta);
	vec3 N_trt = azimuthal_scattering_trt(albedo, cos_theta_d, cos_phi);

	return (specular * M_r * N_r) + (M_tt * N_tt) + (M_trt * N_trt);
}