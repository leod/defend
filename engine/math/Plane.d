module engine.math.Plane;

import tango.math.Math;
import Float = tango.text.convert.Float;

import engine.math.Vector;

struct Plane(T)
{
	/*union
	{
		struct
		{
			struct
			{
				T a;
				T b;
				T c;
			}
			
			struct
			{
				vec3!(T) n;
			}
			
			T d;
		}
		
		T v[4];
	}*/
	
	union
	{
		struct
		{
			T a, b, c;
		}
		
		Vec3!(T) n;
	}
	
	T d;
	
	static Plane opCall(T a, T b, T c, T d)
	{
		Plane result;
		result.a = a;
		result.b = b;
		result.c = c;
		result.d = d;
		
		return result;
	}
	
	static Plane opCall(Vec3!(T) n, T d)
	{
		Plane result;
		result.n = n;
		result.d = d;
		
		return result;
	}
	
	static Plane fromPointNormal(Vec3!(T) p, Vec3!(T) n)
	{
		return Plane(n, -n.x * p.x - n.y * p.y - n.z * p.z); 
	}
	
	static Plane fromPoints(Vec3!(T) v1, Vec3!(T) v2, Vec3!(T) v3)
	{
		return fromPointNormal(v1, cross((v3 - v2), (v1 - v2)));
	}
	
	Plane normalized()
	{
		T length = n.length();
		
		Plane result = *this;
		
		if(length != 0.0)
			result = Plane(n / length, d / length);
		
		return result;
	}
	
	T dotNormal(Vec3!(T) v)
	{
		return a * v.x + b * v.y + c * v.z;
	}
	
	T dotCoords(Vec3!(T) v)
	{
		return dotNormal(v) + d;
	}
  
	char[] toString()
	{
		return "a: " ~ Float.toString(a) ~ "; b: " ~ Float.toString(b) 
			   ~ "; c: " ~ Float.toString(c) ~ "; d: " ~ Float.toString(d);
	}
}
