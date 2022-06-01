module defend.Test;

import tango.io.Stdout;

import xf.omg.core.LinearAlgebra;
import xf.xpose2.Expose;
import xf.xpose2.Serialization;

alias ushort map_index_t;
alias Vector!(map_index_t, 2) map_pos_t;

struct VectorExport(flt, int dim)
{
	const char[] typename = "Vector!(" ~ flt.stringof ~ "," ~ dim.stringof ~ ")";
	mixin(xpose2(typename, "cell"));
	mixin xposeSerialization!(typename);
}

alias VectorExport!(map_index_t, 2) VectorExport_map_pos_t;

class Test
{
	map_pos_t[] path;
	
	mixin(xpose2("path"));
	mixin xposeSerialization;
}

void main()
{
	{
		auto test = new Test;
		test.path = [map_pos_t(100, 200), map_pos_t(300, 100), map_pos_t(42, 1)].dup;
		Stdout(test.path).newline; // [[100, 200], [300, 100], [42, 1]]
	
		scope s = new Serializer("foo.dat");
		scope(exit) s.close();
		
		s(test);
	}
	
	Stdout("----------------------").newline;
	
	{
		scope u = new Unserializer("foo.dat");
		scope(exit) u.close();
		
		auto test = u.get!(Test);
		Stdout(test.path); // [[100, 200], [0, 0], [0, 0]]
	}
}