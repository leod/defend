module defend.sim.Serialization;

import tango.util.container.HashMap;

import xf.xpose2.Expose;
import xf.xpose2.Serialization;
import xf.omg.core.Fixed;

import engine.math.Vector;

/+struct VectorExport(flt, int dim) // Can't serialize array of static arrays
{
	const char[] typename = "Vector!(" ~ flt.stringof ~ "," ~ dim.stringof ~ ")";
	mixin(xpose2(typename, "cell"));
	mixin xposeSerialization!(typename);
}+/

/+
// Had to be moved to Core for some fucked up reasons. thanks dmd
struct HashMapExport(K, V)
{
	alias HashMap!(K, V) Type;
	const char[] typename = "HashMap!(" ~ K.stringof ~ "," ~ V.stringof ~ ")";
	mixin(xpose2(typename, ""));
	mixin xposeSerialization!(typename, "serialize", "unserialize");
	
	static void serialize(Type o, Serializer s)
	{
		s(o.size);
		
		foreach(k, v; o)
		{
			s(k);
			s(v);
		}
	}
	
	static void unserialize(Type o, Unserializer s)
	{
		int size;
		s(size);
		
		for(int i = 0; i < size; ++i)
		{
			K k;
			s(k);
			
			V v;
			s(v);
			
			o[k] = v;
		}
	}
}
+/

private:

/+alias VectorExport!(ushort, 2) VectorExport_ushort_2;
alias VectorExport!(uint, 2) VectorExport_uint_2;
alias VectorExport!(int, 2) VectorExport_int_2;+/

struct vec2usExport
{
	mixin(xpose2("vec2us", "x|y"));
	mixin xposeSerialization!("vec2us");
}

struct vec3fiExport
{
	mixin(xpose2("vec3fi", "x|y|z"));
	mixin xposeSerialization!("vec3fi");
}

struct vec3Export
{
	mixin(xpose2("vec3", "x|y|z"));
	mixin xposeSerialization!("vec3");
}

struct FixedExport
{
	const char[] typename = "fixed";
	mixin xposeSerialization!(typename, "serialize", "unserialize");
	
	static void serialize(fixed* o, Serializer s)
	{
		s(*(cast(int*)o));
	}
	
	static void unserialize(fixed* o, Unserializer s)
	{
		int i;
		s(i);
		*(cast(int*)o) = i;
	}
}