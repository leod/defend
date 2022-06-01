module engine.util.Lang;

import tango.text.convert.Layout : BaseLayout = Layout, Arg, TypeCode;
import tango.text.Util : trim, patterns;

import engine.util.Config;
import engine.util.Environment : gSearchPath;

class Lang
{
private:
	static class Layout(T) : BaseLayout!(T)
	{
		override T[] unknown(T[] result, T[] format, TypeInfo type, Arg p)
		{
			if(type.classinfo.name[9] == TypeCode.STRUCT &&
				type == typeid(Lookup))
			{
				auto lookup = cast(Lookup*)p;

				foreach(group; patterns(format[0 .. $], ","))
				{
					group = trim(group);
					
					if(exists(group, lookup.varName))
						return currentLang(group).string(lookup.varName);
				}
				
				throw new Exception("variable '" ~ lookup.varName ~ "' not found in any group");
			}
			
			return super.unknown(result, format, type, p);
		}
	}

	static char[512] textBuffer;
	
	static Layout!(char) layout;
	static Config currentLang;
	
public:
	/* pass this as a parameter to get() if you want to give the language
	   the possibility to lookup words from other groups by themselves, e.g.:
	   bla = "foo {0:objects_acc,objects} bar" */
	struct Lookup
	{
		char[] varName;
	}
	
	static this()
	{
		layout = new typeof(layout);
	}

	static void load(char[] lang)
	{
		currentLang = new Config(gSearchPath.find("lang/" ~ lang ~ ".cfg", &gSearchPath.abort)[0]);
	}
	
	static bool exists(char[] group, char[] name)
	{
		return currentLang(group).hasVariable(name);
	}
	
	// returns a temporary string, don't store it anywhere	
	static char[] get(char[] group, char[] name, ...)
	{
		return layout.vprint(textBuffer, currentLang(group).string(name), _arguments, _argptr);
	}
	
	// writes into a given buffer instead of the internal one
	static char[] getToBuffer(char[] buffer, char[] group, char[] name, ...)
	{
		return layout.vprint(buffer, currentLang(group).string(name), _arguments, _argptr);
	}
}
