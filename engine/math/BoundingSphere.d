module engine.math.BoundingSphere;

import engine.math.Vector;

struct BoundingSphere(T)
{
	vec3!(T) center;
	float radius;
}
