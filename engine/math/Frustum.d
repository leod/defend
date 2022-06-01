module engine.math.Frustum;

import tango.math.Math;
import tango.io.Console;
import Integer = tango.text.convert.Integer;

import engine.util.Wrapper;
import engine.util.Statistics;
import engine.math.Vector;
import engine.math.Plane;
import engine.math.Matrix;
import engine.math.BoundingBox;

class Frustum(T)
{
private:
	Plane!(T)[6] frustum;

public:
	enum PlaneType
	{
		Far,
		Near,
		Left,
		Right,
		Bottom,
		Top
	}

	Plane!(T) getPlane(PlaneType type)
	{
		return frustum[type];
	}

	void create(ref Mat4!(T) modelview, ref Mat4!(T) projection)
	{
		Mat4!(T) clip_ = projection * modelview;
		auto clip = clip_.ptr;

		frustum[0] = Plane!(T)(clip[3] - clip[0], clip[7] - clip[4], clip[11] - clip[ 8], clip[15] - clip[12]);
		frustum[1] = Plane!(T)(clip[3] + clip[0], clip[7] + clip[4], clip[11] + clip[ 8], clip[15] + clip[12]);
		frustum[2] = Plane!(T)(clip[3] + clip[1], clip[7] + clip[5], clip[11] + clip[ 9], clip[15] + clip[13]);
		frustum[3] = Plane!(T)(clip[3] - clip[1], clip[7] - clip[5], clip[11] - clip[ 9], clip[15] - clip[13]);
		frustum[4] = Plane!(T)(clip[3] - clip[2], clip[7] - clip[6], clip[11] - clip[10], clip[15] - clip[14]);
		frustum[5] = Plane!(T)(clip[3] + clip[2], clip[7] + clip[6], clip[11] + clip[10], clip[15] + clip[14]);
		
		foreach(ref plane; frustum)
			plane = plane.normalized();
	}

	bool pointVisible(Vec3!(T) v)
	{
		foreach(plane; frustum)
		{
			if(plane.dotCoords(v) < 0.0)
				return false;
		}

		return true;
	}

	bool sphereVisible(Vec3!(T) v, T radius)
	{
		foreach(index, plane; frustum)
		{
			if(plane.a * v.x + plane.b * v.y + plane.c * v.z + plane.d <= -radius)
				return false;
		}

		return true;
	}

	bool boxVisible(Vec3!(T) min, Vec3!(T) max)
	{
		if(pointVisible(min)) return true;
		if(pointVisible(Vec3!(T)(max.x, min.y, min.z))) return true;
		if(pointVisible(Vec3!(T)(min.x, max.y, min.z))) return true;
		if(pointVisible(Vec3!(T)(max.x, max.y, min.z))) return true;
		if(pointVisible(Vec3!(T)(min.x, min.y, max.z))) return true;
		if(pointVisible(Vec3!(T)(max.x, min.y, max.z))) return true;
		if(pointVisible(Vec3!(T)(min.x, max.y, max.z))) return true;
		if(pointVisible(max)) return true;

		return false;
	}

	bool boundingBoxVisible(BoundingBox!(T) bbox)
	{
		statistics.frustum_bbox_checks++;

		with(bbox)
		{
			foreach(i, plane; frustum)
			{
				if(plane.dotCoords(Vec3!(T)(min.x, min.y, min.z)) > 0) continue;
				if(plane.dotCoords(Vec3!(T)(max.x, min.y, min.z)) > 0) continue;
				if(plane.dotCoords(Vec3!(T)(min.x, max.y, min.z)) > 0) continue;
				if(plane.dotCoords(Vec3!(T)(max.x, max.y, min.z)) > 0) continue;
				if(plane.dotCoords(Vec3!(T)(min.x, min.y, max.z)) > 0) continue;
				if(plane.dotCoords(Vec3!(T)(max.x, min.y, max.z)) > 0) continue;
				if(plane.dotCoords(Vec3!(T)(min.x, max.y, max.z)) > 0) continue;
				if(plane.dotCoords(Vec3!(T)(max.x, max.y, max.z)) > 0) continue;
				
				return false;
			}
		}

		return true;
	}

	char[] toString()
	{
		char[] result;

		foreach(uint index, plane; frustum)
		{
			result ~= Integer.toString(index + 1) ~ ": " ~ plane.toString();
			if(index != frustum.length) result ~= "\n";
		}

		return result;
	}
}
