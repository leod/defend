module engine.util.Statistics;

import tango.text.convert.Layout;

import engine.util.Log : MLogger;
import engine.util.Singleton;
import engine.math.Vector;

private char[] generateEntries(char[][] strings)
{
	char[] result;
	char[] variables;
	char[] init;
	
	foreach(string; strings)
	{
		char[] varName;
		
		foreach(c; string)
		{
			if(c == ' ')
				varName ~= '_';
			else
				varName ~= c;
		}
		
		variables ~= "int " ~ varName ~ ";\n";
		init ~= "entries[\"" ~ string ~ "\"] = &" ~ varName ~ ";\n";
	}
	
	result ~= variables;
	result ~= "void initVars()\n";
	result ~= "{\n";
	result ~= init;
	result ~= "}\n";

	return result;
}

class Statistics
{
	mixin MLogger;

private:
	Layout!(char) layout;
	
public:
	mixin MSingleton;

	int*[char[]] entries;

	mixin(generateEntries(["triangles rendered"[],
	                      "frustum bbox checks",
	                      "texture changes",
	                      "shader changes",
	                      "vertices animated",
	                      "array format changes",
	                      "bbox xforms",
						  
	                      "patches rendered",
	                      "game object nodes rendered"]));

	this()
	{
		initVars();
	}

	void dump()
	{
		foreach(k, v; entries)
		{
			logger_.trace("{}: {}", k, *v);
		}
		
		reset();
	}
						  
	void render(vec2i pos)
	{
		/+uint i;
		foreach(key, entry; entries)
		{
			font.write(renderer, pos + vec2i(0, font.maxHeight + 4) * i,
			           vec3(.3, .3, 1), "{}: {}", key, *entry);
			
			i++;
		}+/
	}
	
	void reset()
	{
		foreach(entry; entries)
			*entry = 0;
	}
}

alias SingletonGetter!(Statistics) statistics;
