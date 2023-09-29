float square(float x) {
	return x * x;
}

float saturate(float a){
	float s = min(max(a, 0.0), 1.0);
	return s;
}

float luminance(vec3 rgb){
	return (0.2126 * rgb.x) + (0.7152 * rgb.y) + (0.0722 * rgb.z);
}

float rcp(float x){
	return 1.0 / x;
}

float HairIOF(float Eccentric) {
	float n = 1.55;
	float a = 1.0 - Eccentric;
	float ior1 = 2.0 * (n - 1.0) * (a * a) - n + 2.0;
	float ior2 = 2.0 * (n - 1.0) / (a * a) - n + 2.0;
	return 0.5f * ((ior1 + ior2) + 0.5f * (ior1 - ior2)); //assume cos2PhiH = 0.5f 
}

#define SQRT2PI 2.50663

float Hair_G(float B, float Theta)
{
	return exp(-0.5 * square(Theta) / (B*B)) / (SQRT2PI * B);
}

vec3 SpecularFresnel(vec3 F0, float vDotH) {
	return F0 + (1.0f - F0) * pow(1.0 - vDotH, 5);
}

vec3 rgb2hsv(vec3 c){
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c){
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}