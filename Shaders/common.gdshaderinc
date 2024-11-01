#define saturate(x) clamp(x, 0.0, 1.0)
#define SQRT_TWO_PI 2.50663
#define ETA 1.55

float pow2(float x) {
	return x * x;
}

float pow5( float x )
{
	float xx = x * x;
	return xx * xx * x;
}