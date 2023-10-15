#define saturate(x) clamp(x, 0.0, 1.0)
#define SQRT2PI 2.50663

mediump float luminance(vec3 linear_color){
	return dot(linear_color, vec3(0.3, 0.59, 0.11));
}

float square(float x) {
	return x * x;
}

float rcp(float x){
	return 1.0 / x;
}

float acosFast(float inX) 
{
	float x = abs(inX);
	float res = -0.156583f * x + (0.5 * PI);
	res *= sqrt(1.0f - x);
	return (inX >= 0.0) ? res : PI - res;
}

float asinFast(float x)
{
	return (0.5 * PI) - acosFast(x);
}