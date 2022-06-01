module engine.math.Rectangle;

import tango.text.convert.Float;

import engine.math.Vector;

struct Rectangle(T)
{
	alias .Vec2!(T) vec2;

	T left;
	T top;
	T right;
	T bottom;

	invariant
	{
		assert(left <= right);
		assert(top <= bottom);
	}

	static Rectangle opCall(T left, T top, T right, T bottom)
	{
		Rectangle result;
		result.left = left;
		result.top = top;
		result.right = right;
		result.bottom = bottom;

		return result;
	}
	
	static Rectangle opCall(vec2 a, vec2 b)
	{
		return Rectangle(a.x, a.y, b.x, b.y);
	}

	vec2 begin()
	{
		return vec2(left, top);
	}

	vec2 end()
	{
		return vec2(right, bottom);
	}

	T width()
	{
		return right - left;
	}

	T height()
	{
		return bottom - top;
	}

	char[] toString()
	{
		return .toString(left)
		       ~ "|" ~
		       .toString(top)
		       ~ " " ~
		       .toString(right)
		       ~ "|" ~
		       .toString(bottom);
	}

	bool contains(U)(U p)
	{
		static if(is(U == Rectangle))
		{
			return right > p.left && left < p.right &&
			       bottom > p.top && top < p.bottom;
		}
		else
		{
			return p.x >= left && p.x <= right &&
				   p.y >= top && p.y <= bottom;
		}
	}

	bool collides(Rectangle other)
	{
		return right >= other.left && left <= other.right &&
			   bottom >= other.top && top <= other.bottom;
	}

	int opApply(int delegate(ref T, ref T) dg)
	{
		int result = 0;

		for(T x = left; x < right; ++x)
		{
			for(T y = top; y < bottom; ++y)
			{
				result = dg(x, y);

				if(result)
					break;
			}
		}

		return result;
	}

	vec2 nearestPoint(vec2 from)
	{
		float minDistance = 10_000;
		vec2 result = from;

		for(T x = left; x < right; x++)
		{
			for(T y = top; y < bottom; y++)
			{
				auto point = Vec2!(T)(x, y);
				auto distance = point.distance(from);

				if(distance < minDistance)
				{
					minDistance = distance;
					result = point;
				}
			}
		}

		return result;
	}
}

alias Rectangle!(int) Rect;
