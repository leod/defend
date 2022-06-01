module engine.math.BoundingBox;

import engine.math.Misc;

import xf.omg.core.LinearAlgebra;

struct BoundingBox(T)
{
	alias Vector!(T, 3) vec3;
	alias Matrix!(T, 4, 4) mat4;

	vec3 min = { x: T.max, y: T.max, z: T.max };
	vec3 max = { x: T.min, y: T.min, z: T.min };
	vec3 center = vec3.zero;

	const char[] okCode = "min.ok && max.ok && center.ok";

	bool ok()
	{
		return mixin(okCode);
	}

	invariant()
	{
		assert(mixin(okCode));
		// assert(center == (min + max) * 0.5);
	}

	private template calculateCode(char[] add = "")
	{
		const calculateCode =
			"if(points.length)"
			"{"
			"	" ~ add ~ "max = " ~ add ~ "min = points[0];" ~
			"	" ~ add ~ "center = (" ~ add ~ "max + " ~ add ~ "min) / 2;"
			""
			"	if(points.length > 1)"
			"		foreach(point; points[1 .. $])"
			"			" ~ add ~ "addPoint(point);"
			"}";
	}

	static BoundingBox opCall(vec3[] points ...)
	{
		BoundingBox result;
		mixin(calculateCode!("result."));

		return result;
	}
	
	void calculate(vec3[] points ...)
	{
		mixin(calculateCode!());
	}
	
	void addPoint(vec3 point)
	{
		max.x = .max(max.x, point.x);
		max.y = .max(max.y, point.y);
		max.z = .max(max.z, point.z);
		
		min.x = .min(min.x, point.x);
		min.y = .min(min.y, point.y);
		min.z = .min(min.z, point.z);

		center = (min + max) / 2;
	}
	
	void expand(T amount)
	{
		max += amount;
		min -= amount;
	}
	
	BoundingBox expanded(T amount)
	{
		BoundingBox result = *this;
		result.expand(amount);
		
		return result;
	}
	
	BoundingBox xform(mat4 matrix)
	{
		BoundingBox result;
		result.addPoint(matrix.xform(min));
		result.addPoint(matrix.xform(vec3(min.x, min.y, max.z)));
		result.addPoint(matrix.xform(vec3(min.x, max.y, min.z)));
		result.addPoint(matrix.xform(vec3(min.x, max.y, max.z)));
		result.addPoint(matrix.xform(vec3(max.x, min.y, min.z)));
		result.addPoint(matrix.xform(vec3(max.x, min.y, max.z)));
		result.addPoint(matrix.xform(vec3(max.x, max.y, min.z)));
		result.addPoint(matrix.xform(max));
		
		return result;
	}

	void translate(vec3 vector)
	{
		min += vector;
		max += vector;
		center += vector;
	}

	bool checkCollision(vec3 vector)
	{
		return max.x > vector.x && min.x < vector.x &&
		       max.y > vector.y && min.y < vector.y &&
		       max.z > vector.z && min.z < vector.z; 
	}
	
	bool checkCollision(BoundingBox other)
	{
		return checkCollision(other.min) ||
		       checkCollision(vec3(other.min.x, other.min.y, other.max.z)) ||
		       checkCollision(vec3(other.min.x, other.max.y, other.min.z)) ||
		       checkCollision(vec3(other.min.x, other.max.y, other.max.z)) ||
		       checkCollision(vec3(other.max.x, other.min.y, other.min.z)) ||
		       checkCollision(vec3(other.max.x, other.min.y, other.max.z)) ||
		       checkCollision(vec3(other.max.x, other.max.y, other.min.z)) ||
		       checkCollision(other.max);
	}
	
	char[] toString()
	{
		return "[" ~
		       min.toString() ~
		       "," ~
		       max.toString() ~
		       "," ~
		       center.toString() ~
		       "]";
	}
}
