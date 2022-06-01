module engine.util.Serialize;

import tango.util.Convert;
import tango.core.Tuple;
import tango.core.Traits;

import engine.util.Debug;
import engine.util.Meta;

// Simple serializer for structs

private template isIntrinsicType(T)
{
	const isIntrinsicType = isCharType!(T) || isIntegerType!(T) || isRealType!(T) || is(T == bool);
}

void serialize(T, Stream)(ref Stream stream, T t)
{
	//traceln("serializing a {}", T.stringof);

	static if(is(T == struct))
	{
		foreach(i, v; t.tupleof)
			serialize(stream, v);
	}
	else static if(isIntrinsicType!(T))
	{
		stream.write((cast(ubyte*)&t)[0 .. t.sizeof]);
	}
	else static if(isDynamicArrayType!(T))
	{
		int l = t.length;
		stream.write((cast(ubyte*)&l)[0 .. l.sizeof]);
		
		static if(isIntrinsicType!(typeof(T.init[0])))
		{
			stream.write(cast(ubyte[])t);
		}
		else
		{
			foreach(v; t)
				serialize(stream, v);
		}
	}
	else static if(isStaticArrayType!(T))
	{
		static if(isIntrinsicType!(typeof(Init!(T)[0])))
		{
			stream.write(cast(ubyte[])t[]);
		}
		else
		{
			foreach(v; t)
				serialize(stream, v);
		}
	}
	else static assert(false);
}

// fucking static arrays screw up everything \o/
private void unserializeStatic(Stream, U, T)(ref Stream stream, U length, ref T t)
{
	//traceln("unserializing a {}", T.stringof);

	static if(isIntrinsicType!(typeof(Init!(T)[0])))
	{
		t = cast(T)stream.read(typeof(Init!(T)[0]).sizeof * length);
	}
	else
	{
		foreach(ref v; t)
			mixin(unserialize_("v"));
	}
}

private char[] unserialize_(char[] name)
{
	return `static if(isStaticArrayType!(typeof(` ~ name ~ `))) {` ~
				`typeof(Init!(typeof(` ~ name ~ `))[0])[] tmp;` ~
				`.unserializeStatic(stream, Init!(typeof(` ~ name ~ `)).length, tmp);` ~ 
				name ~ `[] = tmp; }` ~
			`else ` ~
				name ~ ` = .unserialize!(typeof(` ~ name ~ `))(stream);`;
}

template unserialize(T)
{
	T unserialize(Stream)(ref Stream stream)
	{
		//traceln("unserializing a {}", T.stringof);

		T t;

		static if(is(T == struct))
		{
			foreach(i, v; t.tupleof)
				mixin(unserialize_("t.tupleof[" ~ i.stringof ~ "]"));
		}
		else static if(isIntrinsicType!(T))
		{
			(cast(ubyte*)&t)[0 .. t.sizeof] = stream.read(t.sizeof);
		}
		else static if(isDynamicArrayType!(T))
		{
			static assert(is(typeof(T.init[0])[] == T));
		
			int l;
			(cast(ubyte*)&l)[0 .. l.sizeof] = stream.read(l.sizeof);
			
			static if(isIntrinsicType!(typeof(T.init[0])))
			{
				alias typeof(t[0]) BaseType; // alias works around some dmd bug; using typeof(t[0]) directly always gives char
			
				t = cast(T)stream.read(l * BaseType.sizeof);
			}
			else
			{
				t.length = l;
				
				foreach(ref v; t)
					mixin(unserialize_("v"));
			}
		}
		else static assert(false);
		
		return t;
	}
}

struct RawWriter
{
private:
	uint offset;
	void delegate(uint, ubyte[]) sink;

public:
	static RawWriter opCall(typeof(sink) sink)
	{
		RawWriter result;
		result.sink = sink;
		
		return result;
	}
	
	void write(ubyte[] data)
	{
		sink(offset, data);
		offset += data.length;
	}
	
	uint written() { return offset; }
}

struct ArrayReader
{
private:
	ubyte[] data;
	
public:
	static ArrayReader opCall(ubyte[] data)
	{
		ArrayReader result;
		result.data = data;
		
		return result;
	}
	
	ubyte[] read(uint amount)
	{
		//traceln("length: {}", data.length);
		//traceln("amount: {}", amount);
		
		ubyte[] result = data[0 .. amount];
		data = data[amount .. $];
		
		return result;
	}
}

/+struct Annotate(T)
{
	static bool __serialize_is_annotation;
	
	alias T Impl;
}

struct DefaultAnnotation
{
	template Aggregate(bool reading, char[] var, T)
	{
		static if(reading && is(T == class))
			const result = "if("  ~ var ~ " is null) " ~ var ~ " = new typeof(" ~ var ~ ");\n";
		else
			const result = "";
	}

	template Variable(bool reading, char[] var, T)
	{
		const result = "stream.record(" ~ var ~ ");";
	}
}

struct MinMax(uint min, uint max)
{
	template Variable(bool reading, char[] var, T)
	{
		const result = DefaultAnnotation.Member!(var, T).result;
	}
}

struct NoSerialize
{

}

interface BitStream
{
	void record(ref ubyte);
	void record(ref ubyte[]);
	
	void record(ref byte);
	void record(ref byte[]);

	void record(ref ushort);
	void record(ref ushort[]);

	void record(ref short);
	void record(ref short[]);
	
	void record(ref char);
	void record(ref char[]);

	void record(ref bool);
	void record(ref bool[]);
	
	void record(ref uint);
	void record(ref uint[]);
	
	void record(ref int);
	void record(ref int[]);
	
	void record(ref float);
	void record(ref float[]);
}

typedef BitStream BitStreamReader;
typedef BitStream BitStreamWriter;

class ArrayReader : BitStreamReader
{
private:
	ubyte[] data;

	final ubyte[] take(uint num)
	{
		auto result = data[0 .. num];
		data = data[num .. $];
		
		return result;
	}

	template genIntegral(char[] type)
	{
		const genIntegral = "override void record(ref " ~ type ~ " o)" ~
			   "{" ~
			   "	o = *(cast(" ~ type ~ "*)take(" ~ type ~ ".sizeof));" ~
			   "}";
	}
		
	template genArray(char[] type)
	{
		const genArray = "override void record(ref " ~ type ~ "[] o)" ~
			   "{" ~
			   "	int length;" ~
			   "	record(length);" ~
			   "	o = cast(" ~ type ~ "[])take(" ~ type ~ ".sizeof * length);" ~
			   "}";
	}

	template gen(char[] type)
	{
		const gen = genIntegral!(type) ~ genArray!(type);
	}

public:
	this(ubyte[] data)
	{
		this.data = data;
	}
	
	mixin(gen!("ubyte"));
	mixin(gen!("byte"));
	mixin(gen!("ushort"));
	mixin(gen!("short"));
	mixin(gen!("char"));
	mixin(gen!("bool"));
	mixin(gen!("uint"));
	mixin(gen!("int"));
	mixin(gen!("float"));
}

class RawWriter : BitStreamWriter
{
private:
	uint offset;
	void delegate(uint, ubyte[]) sink;

	final void put(ubyte[] d)
	{
		sink(offset, d);
		offset += d.length;
	}

	template genIntegral(char[] type)
	{
		const genIntegral = "override void record(ref " ~ type ~ " o)" ~
			   "{" ~
			   "	put((cast(ubyte*)&o)[0 .. " ~ type ~ ".sizeof]);" ~
			   "}";
	}

	template genArray(char[] type)
	{
		const genArray = "override void record(ref " ~ type ~ "[] o)" ~
			   "{" ~
			   "	int length = o.length;" ~
			   "	record(length);" ~
			   "	put(cast(ubyte[])o);" ~
			   "}";
	}

	template gen(char[] type)
	{
		const gen = genIntegral!(type) ~ genArray!(type);
	}

public:
	this(typeof(sink) sink)
	{
		this.sink = sink;
	}
	
	uint written() { return offset; }
	
	mixin(gen!("ubyte"));
	mixin(gen!("byte"));
	mixin(gen!("ushort"));
	mixin(gen!("short"));
	mixin(gen!("char"));
	mixin(gen!("bool"));
	mixin(gen!("uint"));
	mixin(gen!("int"));
	mixin(gen!("float"));
}

private template CodeGen(bool reading, T, uint index = 0, char[] var = "t", Ann = DefaultAnnotation)
{
	static if(index == T.tupleof.length)
		const result = "";
	else
	{
		alias typeof(T.tupleof[index]) Type;
		const name = var ~ ".tupleof[" ~ index.stringof ~ "]";
		
		static if(is(Type == struct) || is(Type == class))
		{
			static if(is(typeof(Type.__serialize_is_annotation)) && is(Type.Impl))
			{
				static if(is(Type.Impl == NoSerialize))
					const result = CodeGen!(reading, T, index + 2, var, DefaultAnnotation).result;
				else
					const result = CodeGen!(reading, T, index + 1, var, Type.Impl).result;
			}
			else
			{
				static if(is(typeof(Ann.Aggregate!(reading, name, Type))))
					const prepend = Ann.Aggregate!(reading, name, Type).result;
				else
					const prepend = "";
			
				const result = prepend ~ CodeGen!(reading, Type, 0, name, Ann).result ~
				               CodeGen!(reading, T, index + 1, var).result;
			}
		}
		else static if(isStaticArrayType!(Type))
		{
			const result = "foreach(ref v; " ~ var ~ ") {" ~
			               Ann.Variable!(reading, "v", int) ~ "}\n" ~
						   CodeGen!(reading, T, index + 1, var).result;
		}
		else
		{
			const result = Ann.Variable!(reading, name, Type).result ~ "\n" ~
			               CodeGen!(reading, T, index + 1, var).result;
		}
	}
}

private void serializer(T, bool reading)(ref T t, BitStream stream)
{
	static assert(is(T == struct), "can't serialize " ~ T.stringof);
	
	pragma(msg, CodeGen!(reading, T).result);
	mixin(CodeGen!(reading, T).result);
}

//template serialize(T) { alias serializer!(T, false) serialize; }
//template unserialize(T) { alias serializer!(T, true) unserialize; }

void serialize(T)(ref T t, BitStream stream) { serializer!(T, false)(t, stream); }
void unserialize(T)(ref T t, BitStream stream) { serializer!(T, true)(t, stream); }

/*void main()
{
	struct Foo
	{
		int f;
		int g;
	}

	struct Test
	{
		//Annotate!(MinMax!(0, 1000)) _x;
		int x;
		
		//Annotate!(NoSerialize) _f;
		Foo f;
		
		//Annotate!(NoSerialize) _g;
		Foo g;
		
		char[] y;
	}
	
	ubyte[2048] data;
	
	auto writer = new ArrayWriter(data);
	auto reader = new ArrayReader(data);
	
	Test test;
	test.x = 42;
	test.y = "hallo, welt";
	test.g.f = 100;
	test.f.g = 200;
	
	Stdout(test.x).newline;
	Stdout(test.y).newline;
	Stdout(test.g.f).newline;
	
	serialize(test, writer);
	
	test = test.init;
	assert(test.x == 0);
	assert(test.y == "");
	assert(test.g.f == 0);
	
	unserialize(test, reader);
	assert(test.x == 42);
	assert(test.y == "hallo, welt");
	assert(test.g.f == 100);
	assert(test.f.g == 200);
	
	Stdout(test.x).newline;
	Stdout(test.y).newline;
	Stdout(test.g.f).newline;
}*/
+/
