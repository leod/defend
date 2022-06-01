module engine.math.Matrix;

import tango.math.Math : cos, sin;

public
{
	import xf.omg.core.LinearAlgebra;
	import xf.omg.core.Misc : deg2rad;
}

import xf.omg.core.Algebra;

template Mat4(T)
{
	alias Matrix!(T, 4, 4) Mat4;
}

Mat4!(T[0]) createMat4(T...)(T t)
{
	Mat4!(T[0]) result = void;
	result.col[0].row[0] = t[0];
	result.col[0].row[1] = t[1];
	result.col[0].row[2] = t[2];
	result.col[0].row[3] = t[3];
	result.col[1].row[0] = t[4];
	result.col[1].row[1] = t[5];
	result.col[1].row[2] = t[6];
	result.col[1].row[3] = t[7];
	result.col[2].row[0] = t[8];
	result.col[2].row[1] = t[9];
	result.col[2].row[2] = t[10];
	result.col[2].row[3] = t[11];
	result.col[3].row[0] = t[12];
	result.col[3].row[1] = t[13];
	result.col[3].row[2] = t[14];
	result.col[3].row[3] = t[15];
	
	return result;
}

Mat4!(flt) xRotationMat(flt)(real angle) {
	assert(!isNaN(angle));
	Mat4!(flt) res = Mat4!(flt).identity;

	flt Sin = scalar!(flt)(sin(angle * deg2rad));
	flt Cos = scalar!(flt)(cos(angle * deg2rad));
	
	res.csetRC!(1, 1) = Cos;
	res.csetRC!(2, 1) = -Sin;
	res.csetRC!(2, 2) = Cos;
	res.csetRC!(1, 2) = Sin;
	
	return res;
}

Mat4!(flt) yRotationMat(flt)(real angle) {
	assert(!isNaN(angle));
	Mat4!(flt) res = Mat4!(flt).identity;

	flt Sin = scalar!(flt)(sin(angle * deg2rad));
	flt Cos = scalar!(flt)(cos(angle * deg2rad));
	
	res.csetRC!(0, 0) = Cos;
	res.csetRC!(2, 0) = Sin;
	res.csetRC!(2, 2) = Cos;
	res.csetRC!(0, 2) = -Sin;
	
	return res;
}

Mat4!(flt) zRotationMat(flt)(real angle) {
	assert(!isNaN(angle));
	Mat4!(flt) res = Mat4!(flt).identity;

	flt Sin = scalar!(flt)(sin(angle * deg2rad));
	flt Cos = scalar!(flt)(cos(angle * deg2rad));
	
	res.csetRC!(0, 0) = Cos;
	res.csetRC!(0, 1) = Sin;
	res.csetRC!(1, 1) = Cos;
	res.csetRC!(1, 0) = -Sin;
	
	return res;
}

mat4 rotationMat(float x, float y, float z)
{
	return zRotationMat!(float)(z) * yRotationMat!(float)(y) * xRotationMat!(float)(x);
}

alias Matrix!(double, 4, 4)	mat4d;

/+import tango.io.Stdout;
import tango.math.Math;
import tango.text.convert.Float;

import engine.math.Vector;

struct Mat4(T)
{
	union
	{
		T[16] data = [1, 0, 0, 0,
			          0, 1, 0, 0,
		              0, 0, 1, 0,
		              0, 0, 0, 1];

		struct
		{
			T m00, m10, m20, m30,
			  m01, m11, m21, m31,
			  m02, m12, m22, m32,
			  m03, m13, m23, m33;
		}
		
		T[4][4] array;
	}

/*	invariant
	{
		static if(is(T == float) || is(T == double))
		{
			foreach(f; data)
				assert(f <>= 0);
		}
	}*/

	static Mat4 empty()
	{
		Mat4 result;

		return result;
	}

	static Mat4 opCall(T _00, T _10, T _20, T _30,
	                   T _01, T _11, T _21, T _31,
	                   T _02, T _12, T _22, T _32,
			   T _03, T _13, T _23, T _33)
	{
		Mat4 result;

		with(result)
		{
			m00 = _00; m10 = _10; m20 = _20; m30 = _30;
			m01 = _01; m11 = _11; m21 = _21; m31 = _31;
			m02 = _02; m12 = _12; m22 = _22; m32 = _32;
			m03 = _03; m13 = _13; m23 = _23; m33 = _33;
		}

		return result;
	}

	static Mat4 opCall(Mat4 r)
	{
		Mat4 result;
		result.m00 = r.m00; result.m10 = r.m10; result.m20 = r.m20; result.m30 = r.m30;
		result.m01 = r.m01; result.m11 = r.m11; result.m21 = r.m21; result.m31 = r.m31;
		result.m02 = r.m02; result.m12 = r.m12; result.m22 = r.m22; result.m32 = r.m32;
		result.m03 = r.m03; result.m13 = r.m13; result.m23 = r.m23; result.m33 = r.m33;

		return result;
	}

	T opIndex(uint index)
	{
		return data[index];
	}
	
	T opIndexAssign(T value, uint index)
	{
		return (data[index] = value);
	}

	T* ptr()
	{
		return data.ptr;
	}

	Mat4!(U) convert(U)()
	{
		Mat4!(U) result;

		foreach(i, d; data)
			result.data[i] = cast(U)d;

		return result;
	}

	Mat4 opAddAssign(ref Mat4 r)
	{
		m00 += r.m00; m10 += r.m10; m20 += r.m20; m30 += r.m30;
		m01 += r.m01; m11 += r.m11; m21 += r.m21; m31 += r.m31;
		m02 += r.m02; m12 += r.m12; m22 += r.m22; m32 += r.m32;
		m03 += r.m03; m13 += r.m13; m23 += r.m23; m33 += r.m33;

		return *this;
	}

	Mat4 opSubAssign(ref Mat4 r)
	{
		m00 -= r.m00; m10 -= r.m10; m20 -= r.m20; m30 -= r.m30;
		m01 -= r.m01; m11 -= r.m11; m21 -= r.m21; m31 -= r.m31;
		m02 -= r.m02; m12 -= r.m12; m22 -= r.m22; m32 -= r.m32;
		m03 -= r.m03; m13 -= r.m13; m23 -= r.m23; m33 -= r.m33;

		return *this;
	}

	Mat4 opMulAssign(ref Mat4 r)
	{
		Mat4 l = *this;

		m00 = r.m00 * l.m00 + r.m10 * l.m01 + r.m20 * l.m02 + r.m30 * l.m03;
		m01 = r.m01 * l.m00 + r.m11 * l.m01 + r.m21 * l.m02 + r.m31 * l.m03;
		m02 = r.m02 * l.m00 + r.m12 * l.m01 + r.m22 * l.m02 + r.m32 * l.m03;
		m03 = r.m03 * l.m00 + r.m13 * l.m01 + r.m23 * l.m02 + r.m33 * l.m03;
		m10 = r.m00 * l.m10 + r.m10 * l.m11 + r.m20 * l.m12 + r.m30 * l.m13;
		m11 = r.m01 * l.m10 + r.m11 * l.m11 + r.m21 * l.m12 + r.m31 * l.m13;
		m12 = r.m02 * l.m10 + r.m12 * l.m11 + r.m22 * l.m12 + r.m32 * l.m13;
		m13 = r.m03 * l.m10 + r.m13 * l.m11 + r.m23 * l.m12 + r.m33 * l.m13;
		m20 = r.m00 * l.m20 + r.m10 * l.m21 + r.m20 * l.m22 + r.m30 * l.m23;
		m21 = r.m01 * l.m20 + r.m11 * l.m21 + r.m21 * l.m22 + r.m31 * l.m23;
		m22 = r.m02 * l.m20 + r.m12 * l.m21 + r.m22 * l.m22 + r.m32 * l.m23;
		m23 = r.m03 * l.m20 + r.m13 * l.m21 + r.m23 * l.m22 + r.m33 * l.m23;
		m30 = r.m00 * l.m30 + r.m10 * l.m31 + r.m20 * l.m32 + r.m30 * l.m33;
		m31 = r.m01 * l.m30 + r.m11 * l.m31 + r.m21 * l.m32 + r.m31 * l.m33;
		m32 = r.m02 * l.m30 + r.m12 * l.m31 + r.m22 * l.m32 + r.m32 * l.m33;
		m33 = r.m03 * l.m30 + r.m13 * l.m31 + r.m23 * l.m32 + r.m33 * l.m33;

		return *this;
	}

	Mat4 opMulAssign(T r)
	{
		m01 *= r; m10 *= r; m20 *= r; m30 *= r;
		m01 *= r; m11 *= r; m21 *= r; m31 *= r;
		m02 *= r; m12 *= r; m22 *= r; m32 *= r;
		m03 *= r; m13 *= r; m23 *= r; m33 *= r;

		return *this;
	}

	Mat4 opAdd(ref Mat4 r)
	{
		return Mat4(*this) += r;
	}

	Mat4 opSub(ref Mat4 r)
	{
		return Mat4(*this) -= r;
	}

	Mat4 opMul(ref Mat4 r)
	{
		return Mat4(*this) *= r;
	}

	Mat4 opMul(T r)
	{
		return Mat4(*this) *= r;
	}

	T determinante()
	{
		return m00 * (m11 * m22 - m12 * m21) -
		       m01 * (m10 * m22 - m12 * m20) +
		       m02 * (m10 * m21 - m11 * m20);
	}

	Mat4 inverse()
	{
		T det = determinante();
		assert(det != 0, "matrix does not have an inverse");

		T invDet = 1 / det;

		Mat4 result;

		//with(*this)
		//{
			result.m00 =  invDet * (m11 * m22 - m12 * m21);
			result.m01 = -invDet * (m01 * m22 - m02 * m21);
			result.m02 =  invDet * (m01 * m12 - m02 * m11);
			result.m03 = 0;
			result.m10 = -invDet * (m10 * m22 - m12 * m20);
			result.m11 =  invDet * (m00 * m22 - m02 * m20);
			result.m12 = -invDet * (m00 * m12 - m02 * m10);
			result.m13 = 0;
			result.m20 =  invDet * (m10 * m21 - m11 * m20);
			result.m21 = -invDet * (m00 * m21 - m01 * m20);
			result.m23 = 0;
			result.m30 = -(m30 * result.m00 + m31 * result.m10 + m32 * result.m20);
			result.m31 = -(m30 * result.m01 + m31 * result.m11 + m32 * result.m21);
			result.m32 = -(m30 * result.m02 + m31 * result.m12 + m32 * result.m22);
			result.m33 = 1;
		//}

		return result;
	}

	Mat4 transpose()
	{
		return Mat4(m00, m01, m02, m03,
			    m10, m11, m12, m13,
		            m20, m21, m22, m23,
		            m30, m31, m32, m33);
	}

	Vec3!(T) transform(ref Vec3!(T) v)
	{
		return Vec3!(T)(data[0] * v.x + data[4] * v.y +
		                data[8] * v.z + data[12],
						
		                data[1] * v.x + data[5] * v.y +
		                data[9] * v.z + data[13],
						
		                data[2] * v.x + data[6] * v.y +
		                data[10] * v.z + data[14]);
	}

	Vec3!(T) transformNormal(ref Vec3!(T) v)
	{
		assert(false);
	
		final float length = v.length();
		if(length == 0.0) return v;

		final Mat4 trans = inverse().transpose();

		return Vec3!(T)(v.x * trans.m00 + v.y * trans.m10 + v.z * trans.m20,
		                v.x * trans.m01 + v.y * trans.m11 + v.z * trans.m21,
		                v.x * trans.m02 + v.y * trans.m12 + v.z * trans.m22).normalized() * length;
	}

	char[] toString()
	{
		char[] result;

		for(uint y = 0; y <= 3; ++y)
		{
			for(uint x = 0; x <= 3; ++x)
			{
				if(x != 0) result ~= "	 ";
				result ~= .toString(array[x][y]);
				if(x != 3) result ~= ", ";
			}

			result ~= "\n";
		}

		return result;
	}

	Vec3!(T) getTranslation()
	{
		return Vec3!(T)(m03, m13, m23);
	}

	void setTranslation(Vec3!(T) v)
	{
		m03 = v.x;
		m13 = v.y;
		m23 = v.z;
	}
	
	void setRotation(Vec3!(T) rotation)
	{
		auto cr = cos(rotation.x);
		auto sr = sin(rotation.x);
		auto cp = cos(rotation.y);
		auto sp = sin(rotation.y);
		auto cy = cos(rotation.z);
		auto sy = sin(rotation.z);
		
		data[0] = cp * cy;
		data[1] = cp * sy;
		data[2] = -sp;
		
		auto srsp = sr * sp;
		auto crsp = cr * sp;
		
		data[4] = srsp * cy - cr * sy;
		data[5] = srsp * sy + cr * cy;
		data[6] = sr * cp;
		
		data[8] = crsp * cy + sr * sy;
		data[9] = crsp * sy - sr * cy;
		data[10] = cr * cp;
	}
	
	static
	{
		Mat4 translation(Vec3!(T) v)
		{
			return Mat4(1,   0,   0,   0,
			            0,   1,   0,   0,
				    0,   0,   1,   0,
			            v.x, v.y, v.z, 1);
		}

		Mat4 translation(T x, T y, T z)
		{
			auto vec = Vec3!(T)(x, y, z);

			return translation(vec);
		}

		Mat4 scaling(Vec3!(T) v)
		{
			return Mat4(v.x, 0,   0,   0,
			            0,   v.y, 0,   0,
			            0,   0,   v.z, 0,
			            0,   0,   0,   1);
		}

		Mat4 scaling(T x, T y, T z)
		{
			return scaling(Vec3!(T)(x, y, z));
		}

		Mat4 scaling(T f)
		{
			return scaling(f, f, f);
		}

		Mat4 lookat(Vec3!(T) eye, Vec3!(T) at, Vec3!(T) up)
		{
			Vec3!(T) zaxis = (at - eye).normalized();
			Vec3!(T) xaxis = up.cross(zaxis).normalized();
			Vec3!(T) yaxis = zaxis.cross(xaxis);

			return Mat4(xaxis.x, yaxis.x, zaxis.x, 0,
			            xaxis.y, yaxis.y, zaxis.y, 0,
			            xaxis.z, yaxis.z, zaxis.z, 0,
			            -xaxis.dot(eye), -yaxis.dot(eye), -zaxis.dot(eye), 1);
		}

		Mat4 projection(T aspect, T fov, T near, T far)
		{
			T f = 1.0f / tan(fov / 2);

			return Mat4(f / aspect, 0, 0, 0,
			            0, f, 0, 0,
			            0, 0, (far + near) / (near - far), -1,
				        0, 0, 2.0f * near * far / (near - far), 0);
		}

		Mat4 identity()
		{
			return Mat4(1, 0, 0, 0,
			            0, 1, 0, 0,
			            0, 0, 1, 0,
			            0, 0, 0, 1);
		}

		Mat4 rotationx(T f)
		{
			Mat4 result = identity();

			result.m11 = result.m22 = cos(f);
			result.m12 = sin(f);
			result.m21 = -result.m12;

			return result;
		}

		Mat4 rotationy(T f)
		{
			Mat4 result = identity();

			result.m00 = result.m22 = cos(f);
			result.m20 = sin(f);
			result.m02 = -result.m20;

			return result;
		}

		Mat4 rotationz(T f)
		{
			Mat4 result = identity();

			result.m00 = result.m11 = cos(f);
			result.m01 = sin(f);
			result.m10 = -result.m01;

			return result;
		}

		Mat4 rotation(Vec3!(T) v)
		{
			return rotationz(v.z) *
			       rotationx(v.x) *
			       rotationy(v.y);
		}

		Mat4 rotation(T x, T y, T z)
		{
			return rotationz(z) *
			       rotationx(x) *
			       rotationy(y);
		}
	}
}

alias Mat4!(float) mat4;
alias Mat4!(double) mat4d;+/
