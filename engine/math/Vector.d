module engine.math.Vector;

public
{
	import xf.omg.core.LinearAlgebra;
}

template Vec3(T)
{
	alias Vector!(T, 3) Vec3;
}

template Vec2(T)
{
	alias Vector!(T, 2) Vec2;
}

alias Vec2!(ushort) vec2us;
alias Vec3!(real) vec3r;

T.flt getVectorField(T, S)(T vector, S index)
{
	assert(index < T.dim);
	return vector.ptr[index];
}

U setVectorField(T, S, U)(ref T vector, S index, U value)
{
	assert(index < T.dim);
	return vector.ptr[index] = value;
}

/+import tango.core.Tuple;
import tango.math.Math;
import tango.text.convert.Float;

struct Vec2(T)
{
	union
	{
		struct
		{
			T x = cast(T)0;
			T y = cast(T)0;
		}

		struct
		{
			T width;
			T height;
		}

		struct
		{
			T u;
			T v;
		}

		T array[2];
	}

	invariant()
	{
		static if(is(T == float) || is(T == double))
		{
			assert(x <>= 0);
			assert(y <>= 0);
		}
	}

	static Vec2 opCall(T x, T y)
	{
		Vec2 result;
		result.x = x;
		result.y = y;

		return result;
	}

	bool opEquals(Vec2 rhs)
	{
		return x == rhs.x && y == rhs.y;
	}

	Vec2 opAdd(Vec2 rhs)
	{
		return Vec2(cast(T)(x + rhs.x), cast(T)(y + rhs.y));
	}

	Vec2 opSub(Vec2 rhs)
	{
		return Vec2(cast(T)(x - rhs.x), cast(T)(y - rhs.y));
	}

	Vec2 opMul(Vec2 rhs)
	{
		return Vec2(cast(T)(x * rhs.x), cast(T)(y * rhs.y));
	}

	Vec2 opMul(T rhs)
	{
		return Vec2(cast(T)(x * rhs), cast(T)(y * rhs));
	}

	Vec2 opDiv(Vec2 rhs)
	in
	{
		assert(rhs.x != 0);
		assert(rhs.y != 0);
	}
	body
	{
		return Vec2(cast(T)(x / rhs.x), cast(T)(y / rhs.y));
	}

	Vec2 opDiv(T r)
	in
	{
		assert(r != 0);
	}
	body
	{
		return Vec2(cast(T)(x / r), cast(T)(y / r));
	}

	void opAddAssign(Vec2 rhs)
	{
		x += rhs.x;
		y += rhs.y;
	}

	void opSubAssign(Vec2 rhs)
	{
		x -= rhs.x;
		y -= rhs.y;
	}

	void opMulAssign(Vec2 rhs)
	{
		x *= rhs.x;
		y *= rhs.y;
	}

	void opDivAssign(Vec2 rhs)
	in
	{
		assert(rhs.x != 0);
		assert(rhs.y != 0);
	}
	body
	{
		x /= rhs.x;
		y /= rhs.y;
	}

	void set(T _x, T _y)
	{
		x = _x;
		y = _y;
	}

	float distance(Vec2 rhs)
	{
		return sqrt(cast(float)((rhs.x - x) * (rhs.x - x) +
		            	(rhs.y - y) * (rhs.y - y)));
	}

	char[] toString()
	{
		return "[" ~ .toString(x) ~ "|" ~ .toString(y) ~ "]";
	}

	int opApply(int delegate(ref T, ref T) dg)
	{
		int result = 0;

		for(T current_x = 0; current_x < x; ++current_x)
			for(T current_y = 0; current_y < y; ++current_y)
			{
				result = dg(current_x, current_y);

				if(result) break;
			}

		return result;
	}
	
	T* ptr() { return cast(T*)this; }
}

alias Vec2!(float) vec2;
alias Vec2!(int) vec2i;
//alias Vec2!(uint) vec2ui;
alias Vec2!(short) vec2s;
alias Vec2!(ushort) vec2us;

struct Vec3(T)
{
	T x = 0;
	T y = 0;
	T z = 0;

	//alias x r;
	//alias y g;
	//alias z b;

	invariant
	{
		static if(is(T == float) || is(T == double))
		{
			assert(x <>= 0, "x is nan");
			assert(y <>= 0, "y is nan");
			assert(z <>= 0, "z is nan");
		}
	}

	void checkInvariant() {}

	static Vec3 empty()
	{
		Vec3 result;

		return result;
	}

	static Vec3 opCall(T x, T y, T z)
	{
		Vec3 result;
		result.x = x;
		result.y = y;
		result.z = z;

		return result;
	}

	static Vec3 opCall(Vec3 r)
	{
		return Vec3(r.x, r.y, r.z);
	}

	static Vec3 opCall(T t)
	{
		return Vec3(t, t, t);
	}

	Vec3 opAddAssign(Vec3 r)
	{
		x += r.x;
		y += r.y;
		z += r.z;
	
		return *this;
	}

	Vec3 opAddAssign(T r)
	{
		x += r;
		y += r;
		z += r;

		return *this;
	}

	Vec3 opSubAssign(Vec3 r)
	{
		x -= r.x;
		y -= r.y;
		z -= r.z;

		return *this;
	}

	Vec3 opSubAssign(T r)
	{
		x -= r;
		y -= r;
		z -= r;

		return *this;
	}

	Vec3 opMulAssign(Vec3 r)
	{
		x *= r.x;
		y *= r.y;
		z *= r.z;

		return *this;
	}

	Vec3 opMulAssign(T r)
	{
		x *= r;
		y *= r;
		z *= r;

		return *this;
	}

	Vec3 opDivAssign(T r)
	in
	{
		assert(r != 0);
	}
	body
	{
		return Vec3(cast(T)(x / r),
		            cast(T)(y / r),
		            cast(T)(z / r));
	}

	Vec3 opAdd(Vec3 r)
	{
		return Vec3(*this) += r;
	}

	Vec3 opSub(Vec3 r)
	{
		return Vec3(*this) -= r;
	}

	Vec3 opMul(Vec3 r)
	{
		return Vec3(*this) *= r;
	}

	Vec3 opMul(T r)
	{
		return Vec3(*this) *= r;
	}

	Vec3 opDiv(T r)
	{
		return Vec3(*this) /= r;
	}

	Vec3 opDiv_r(T l)
	{
		return Vec3(cast(T)(l / x),
		            cast(T)(l / y),
		            cast(T)(l / z));
	}

	Vec3 normalized()
	{
		return *this * cast(T)(1 / length());
	}

	T opIndex(uint index)
	{
		switch(index)
		{
		case 0:
			return x;

		case 1:
			return y;

		case 2:
			return z;

		default:
			assert(false);
		}

		assert(false);
	}

	T opIndexAssign(T value, uint index)
	{
		switch(index)
		{
		case 0:
			return (x = value);

		case 1:
			return (y = value);

		case 2:
			return (z = value);

		default:
			assert(false);
		}

		assert(false);
	}

	bool opEquals(Vec3 r)
	{
		return x == r.x && y == r.y && z == r.z;
	}

	int opCmp(Vec3 r)
	{
		if(x < r.x && y < r.y && z < r.z)
			return -1;

		if(x > r.x && y > r.y && z > r.z)
			return 1;

		return 0;
	}

	T sqLength()
	{
		return cast(T)(x * x + y * y + z * z);
	}

	T length()
	{
		return cast(T)sqrt(cast(float)sqLength());
	}

	T dot(Vec3 r)
	{
		return cast(T)(x * r.x + y * r.y + z * r.z);
	}

	Vec3 cross(Vec3 r)
	{
		return Vec3(cast(T)(y * r.z - z * r.y),
		            cast(T)(z * r.x - x * r.z),
		            cast(T)(x * r.y - y * r.x));
	}

	T distance(Vec3 r)
	{
		T vx = cast(T)(x - r.x);
		T vy = cast(T)(y - r.y);
		T vz = cast(T)(z - r.z);

		return cast(T)sqrt(cast(float)(vx * vx +
		                               vy * vy +
		                               vz * vz));
	}

	char[] toString()
	{
		return "["
		       ~ .toString(x) ~
		       "|"
		       ~ .toString(y) ~
		       "|"
		       ~ .toString(z) ~
		       "]";
	}
	
	T* ptr() { return cast(T*)this; }
}

alias Vec3!(float) vec3;
alias Vec3!(double) vec3d;
alias Vec3!(byte) vec3b;
alias Vec3!(ubyte) vec3ub;
alias Vec3!(int) vec3i;
alias Vec3!(uint) vec3ui;
alias Vec3!(float) color3;

struct Vec4(T)
{
	union
	{
		struct
		{
			T x = 0;
			T y = 0;
			T z = 0;
			T w = 0;
		}

		struct
		{
			T r;
			T g;
			T b;
			T a;
		}

		Tuple!(T, T, T, T) tuple;
	}

	static Vec4 opCall(T x = 0, T y = 0, T z = 0, T w = 0)
	{
		Vec4 result;

		result.x = x;
		result.y = y;
		result.z = z;
		result.w = w;

		return result;
	}
	
	char[] toString()
	{
		return "[" ~ .toString(x) ~ "|" ~ .toString(y) ~ "|" ~ .toString(z) ~ "|" ~ .toString(w) ~ "]";
	}
	
	T* ptr() { return cast(T*)this; }
}

alias Vec4!(float) vec4;
alias Vec4!(float) vec4f;
alias Vec4!(float) color4;+/
