module engine.math.Ray;

import tango.math.Math;

import engine.math.Vector;
import engine.math.Plane;
import engine.math.Epsilon;
import engine.math.BoundingBox;

struct Ray(T)
{
	Vec3!(T) origin = Vec3!(T).zero;
	Vec3!(T) direction = Vec3!(T).zero;
	
	static Ray opCall(Vec3!(T) origin, Vec3!(T) direction)
	{
		Ray result;
		result.origin = origin;
		result.direction = direction;
		
		return result;
	}
	
	bool intersectSphere(Vec3!(T) pos, float radius, float* dist = null)
	{
		Vec3!(T) raySphereDir;
		T raySphereLength = 0.0;
		T intersectPoint = 0.0;
		T squaredPoint = 0.0;
		
		raySphereDir = pos - origin;
		raySphereLength = dot(raySphereDir, raySphereDir);
		
		intersectPoint = dot(raySphereDir, direction);
		if(intersectPoint < 0.0) return false;
		
		squaredPoint = radius * radius - raySphereLength + intersectPoint * intersectPoint;
		if(squaredPoint < 0.0) return false;
		
		if(dist)
			*dist = intersectPoint - cast(T)sqrt(squaredPoint);
		
		return true;
	}
	
	bool intersectTriangle(Vec3!(T) a, Vec3!(T) b, Vec3!(T) c, ref float t, ref float u, ref float v)
	{
		Vec3!(T) edge1 = b - a;
		Vec3!(T) edge2 = c - a;
		Vec3!(T) pvec = cross(direction, edge2);
		T det = dot(edge1, pvec);
		
		if(det < Epsilon!(T))
			return false;
		
		Vec3!(T) tvec = origin - a;
		
		u = dot(tvec, pvec);
		if(u < 0 || u > det)
			return false;
			
		Vec3!(T) qvec = cross(tvec, edge1);
		
		v = dot(direction, qvec);
		if(v < 0 || u + v > det)
			return false;
			
		t = dot(edge2, qvec);
		
		T invDet = 1.0 / det;
		t *= invDet;
		u *= invDet;
		u *= invDet;
		
		return true;
	}
	
	bool intersectPlane(Plane!(T) plane, bool cull = false, Vec3!(T)* point = null, T* dist = null)
	{
		T rayd = dot(plane.n, direction);
		
		if(abs(rayd) < Epsilon!(T)) return false;
		if(cull && rayd > 0.0) return false;
		
		T origind = -(dot(plane.n, origin) + plane.d);
		T intersectd  = origind / rayd;
		
		if(intersectd < 0.001) return false;
		
		if(dist)
			*dist = intersectd;
			
		if(point)
			*point = origin + direction * intersectd;
			
		return true;
	}
	
	bool intersectBoundingBox(BoundingBox!(T) bbox)
	{
		if(direction.x == 0 || direction.y == 0 || direction.z == 0)
			return false;
		
		with(bbox)
		{
			auto maxT = Vec3!(T)(-1, -1, -1);
			auto div = 1.0f / direction;
			bool inside = true;
			
			for(uint i = 0; i < 3; i++)
			{
				if(getVectorField(origin, i) < getVectorField(min, i))
				{
					inside = false;
					setVectorField(maxT, i, (getVectorField(min, i) - getVectorField(origin, i)) *
					                         getVectorField(div, i));
				}
				else if(getVectorField(origin, i) > getVectorField(max, i))
				{
					inside = false;
					setVectorField(maxT, i, (getVectorField(max, i) - getVectorField(origin, i)) *
					                         getVectorField(div, i));
				}
			}
			
			if(inside)
				return true;

			uint index = 0;
			if(maxT.y > getVectorField(maxT, index)) index = 1;
			if(maxT.z > getVectorField(maxT, index)) index = 2;
			
			if(getVectorField(maxT, index) < 0)
				return false;
				
			for(uint i = 0; i < 3; i++)
			{
				if(i != index)
				{
					float temp = getVectorField(origin, i) +
					             getVectorField(maxT, index) * getVectorField(direction, i);
					
					if(temp < getVectorField(min, i) - Epsilon!(T) ||
					   temp > getVectorField(max, i) + Epsilon!(T))
						return false;
				}
			}
			
			return true;
		}
	}
	
	char[] toString()
	{
		return "origin: " ~ origin.toString() ~ "; direction: " ~ direction.toString();
	}
}
