module engine.util.Config;

/*

	Format:
		
		- structure by indentation (tabs)
		- [section] creates a new section
		- sections may be nested
		- a = b defines a variable
		- allowed values:
			- numbers: 42, 4.2
			- strings: "foo"
			- vectors of numbers: vec3(2, 3, 3), vec3(2.3, 3.3, 3.0), vec2(4, 2)
		- comments: //
		
		Example:
	
		[name]
			a = "b"
			c = 37
		
			[blubber]
				foo = vec3(1, 2, 3)
				blablabla = "blabl\nabla?"
				
			foo = "bar"
*/

import Path = tango.io.Path;
import tango.io.UnicodeFile;
import tango.io.Stdout;
import Integer = tango.text.convert.Integer;

class ConfigException : Exception
{
	char[] msg;
	char[] codeFile;
	int codeLine;

	this(char[] msg, int codeLine = -1)
	{
		this.msg = msg;
		this.codeLine = codeLine;
		
		super(msg);
	}
	
	override char[] toString()
	{
		return "(" ~ codeFile ~ ":" ~ Integer.toString(codeLine) ~ ") " ~ msg;
	}
}

class Config : ConfigSection
{
private:
	char[] path_;

public:
	this(char[] path)
	{
		super(null, "root");
		
		this.path_ = path;
		
		try
		{
			(new Parser(new Tokenizer(cast(char[])(new UnicodeFile!(char)(full, Encoding.Unknown)).read))).parse(this);
		}
		catch(ConfigException exception)
		{
			exception.codeFile = full;
			throw exception;
		}
	}
	
	char[] full()
	{
		return path_;
	}
	
	char[] path()
	{
		return Path.parse(path_).path;
	}
}

private
{
	char[] genCode(char[] names)
	{
		//pragma(msg, "a"); 

		char[] result = "";

		{
			char[][] types = [];
			char[][] ids = [];
			
			extractNames(names, types, ids);
			
			char[][][] idParts = [];
			
			foreach(id; ids)
				idParts ~= splitParts(id);
			
			result ~= genStructs(types, ids, idParts);
			result ~= "this(char[] c)\n{\n\tsuper(c);\n";
			
			for(size_t i = 0; i < types.length; i++)
				result ~= genAssign(types[i], ids[i], idParts[i]);
			
			result ~= "}";
		}

		//pragma(msg, "b");
		
		return result;
	}
	
	char[] extractNames(char[] names, out char[][] types, out char[][] ids)
	{
		char[] result;
		
		int position;
	
		do
		{
			char[] name;
			char[] type;
			char[] id;
			
			while(names[position] == ' ' || names[position] == '\n' || names[position] == '\r')
			      position++;
		
			while(names[position] != ';' && position < names.length)
				name ~= names[position++];

			position++;
			
			{
				int i;
				
				while(name[i] != ' ' && i < name.length)
					type ~= name[i++];
				
				i++;
				
				while(i < name.length)
					id ~= name[i++];
			}
			
			types ~= type;
			ids ~= id;
		}
		while(position != names.length);
		
		return result;
	}

	char[][] splitParts(char[] id)
	{
		char[][] result;
	
		{
			char[] part;
			
			foreach(c; id)
			{
				if(c != '.')
					part ~= c;
				else
				{
					result ~= part;
					part = "";
				}
			}
			
			result ~= part;
		}
		
		return result;
	}

	char[] genAssign(char[] type, char[] id, char[][] parts)
	{
		char[] result = "\t" ~ id ~ " = this";
		
		{
			for(uint i = 0; i < parts.length; i++)
			{
				auto part = parts[i];
				
				if(i == parts.length - 1)
				{
					result ~= ".";
				
					if(type == "int")
						result ~= "integer";
					else if(type == "string")
						result ~= "string";
					else
						assert(false, "unknown type: " ~ type);
				}
				else
					result ~= ".child";
				
				result ~= "(\"" ~ part ~ "\")";
			}
		}	
		
		return result ~ ";\n";
	}

	char[] genStructs(char[][] types, char[][] ids, char[][][] idParts,
	                  char[] level = "", uint depth = 0)
	{
		char[] result = "";
		char[][] done = [];
		
		foreach(i, id; ids)
		{
			char[][] parts = idParts[i];
		
			if(id.length > level.length && id[0 .. level.length] == level)
			{
				if(parts.length == depth + 1)
					result ~= types[i] ~ " " ~ parts[$ - 1] ~ ";\n";
				else
				{
					char[] newLevel = level ~ (depth ? "." : "") ~ parts[depth];
					
					bool found = false;
					
					foreach(d; done)
					{
						if(d == newLevel)
						{
							found = true;
							break;
						}
					}
					
					if(found)
						continue;

					done ~= newLevel;
					
					result ~= "struct _" ~ parts[depth] ~ "\n{\n";
					result ~= genStructs(types, ids, idParts, newLevel, depth + 1);
					result ~= "}\n_" ~ parts[depth] ~ " " ~ parts[depth] ~ ";\n";
				}
			}
		}
		
		return result;
	}
}

class CachedConfig(char[] names) : Config
{
public:
	//pragma(msg, genCode());
	mixin(genCode(names));
}

struct ConfigVariable
{
	enum Type
	{
		Define,
		String,
		Integer,
		Float
	}
	
	Type type;
	
	union
	{
		char[] string;
		int integer;
		float float_;
	}
	
	static ConfigVariable opCall()
	{
		ConfigVariable result = void;
		result.type = Type.Define;
		
		return result;
	}
	
	static ConfigVariable opCall(char[] s)
	{
		ConfigVariable result = void;
		result.type = Type.String;
		result.string = s;
		
		return result;
	}
	
	static ConfigVariable opCall(int i)
	{
		ConfigVariable result = void;
		result.type = Type.Integer;
		result.integer = i;
		
		return result;
	}
	
	static ConfigVariable opCall(float f)
	{
		ConfigVariable result = void;
		result.type = Type.Float;
		result.float_ = f;
		
		return result;
	}
}

class ConfigSection
{
private:
	ConfigSection parent;
	char[] name;
	
	ConfigSection[char[]] children;
	ConfigVariable[char[]] variables;
	
	this(ConfigSection parent, char[] name)
	{
		this.parent = parent;
		this.name = name;
		
		if(parent)
			parent.children[name] = this;
	}
	
public:
	bool hasChild(char[] name)
	{
		return !!(name in children);
	}

	ConfigSection child(char[] name)
	{
		auto section = name in children;
		
		if(!section)
			throw new ConfigException("section not found: " ~ name);
			
		return *section;
	}
	
	alias child opCall;
	
	bool hasVariable(char[] name)
	{
		return !!(name in variables);
	}
	
	ConfigVariable variable(char[] name)
	{
		auto variable = name in variables;
		
		if(!variable)
			throw new ConfigException("variable not found: " ~ name);
			
		return *variable;
	}

	char[] string(char[] name)
	{
		auto variable = variable(name);
		
		if(variable.type != ConfigVariable.Type.String)
			throw new ConfigException("wrong variable type for " ~ name);
	
		return variable.string;
	}
	
	int integer(char[] name)
	{
		auto variable = variable(name);
		assert(variable.type == ConfigVariable.Type.Integer);
	
		return variable.integer;
	}

	int opApply(T)(int delegate(ref char[], ref T) dg)
	{
		int result;
	
		foreach(key, val; variables)
		{
			T temp;
		
			static if(is(T == ConfigVariable))
				temp = val;
			else static if(is(T == char[]))
				temp = val.string;
			else static if(is(T == int))
				temp = val.integer;
			else
				static assert(false);
			
			if(cast(bool)(result = dg(key, temp)))
				break;
		}
		
		return result;
	}

	void dump(uint indent = 1)
	{
		for(uint i = 0; i < indent; i++)
			Stdout("-> ");
			
		Stdout(name).newline;
		
		foreach(key, val; variables)
		{
			for(uint i = 0; i < indent; i++)
				Stdout("   ");
				
			Stdout(key)(" = ")(val.integer).newline;
		}
		
		foreach(child; children)
			child.dump(indent + 1);
	}
}

private
{
	enum TokenType
	{
		Undefined,
	
		Identifier,
		String,
		Number,
		NewLine,
		EndOfFile,
		Indent,
		Assign,
		
		LBracket,
		RBracket
	}
	
	struct Token
	{
		TokenType type;
		uint line;
		
		union
		{
			char[] text;
			int number;
			float fnumber;
		}
	}
	
	class Tokenizer
	{
	private:
		char[] text;
		uint pos;
		
		char c() // returns the current char
		{
			return text[pos];
		}
		
		char nc() // goes to the next char, returns it
		{
			assert(pos + 1 < text.length);
			
			return text[++pos];
		}
		
		char cn() // goes to the next char, returns the old one
		{
			assert(pos + 1 < text.length);
			
			return text[pos++];
		}
		
		uint line = 1;
		
		void error(char[] msg)
		{
			throw new ConfigException(msg, line);
		}
	
	public:
		this(char[] text)
		{
			this.text = text ~ '\0';
		}
		
		Token next()
		{
			Token token;
			token.line = line;
		
			while(true)
			{
				switch(c)
				{
				case '0', '1', '2', '3', '4', '5', '6', '7', '8', '9':
					token.type = TokenType.Number;
					
					// TODO: tokenize floats
					while(c >= '0' && c <= '9' && c != '\0')
						token.text ~= cn;
					
					token.number = Integer.toInt(token.text);
					
					return token;
		
				case 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k',
					 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v',
					 'w', 'x', 'y', 'z',
					 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K',
					 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V',
					 'W', 'X', 'Y', 'Z',
					 '_':
					
					token.type = TokenType.Identifier;

					// I should rather use some 'isIdentifierChar' function
					while(c != ' ' && c != '=' && c != '\r' && c != '\n' && c != '\0' &&
					      c != ']' && c != '[')
						token.text ~= cn;
					
					return token;
					
				case '\t':
					nc;
				
					token.type = TokenType.Indent;
					return token;
					
				case ' ':
					nc;
					
					continue;
				
				case '[':
					nc;
					
					token.type = TokenType.LBracket;
					return token;
					
				case ']':
					nc;
					
					token.type = TokenType.RBracket;
					return token;
				
				case '/':
					if(nc != '/')
						error("invalid char: '/'");
						
					while(nc != '\r' && c != '\n' && c != '\0') {}
					
					continue;
					
				case '\r', '\n':
					auto t = c;
					nc;
				
					if((t == '\r' && c == '\n') || // windows
					   (t == '\n' && c == '\r'))
					   nc;
					
					line++;
					
					token.type = TokenType.NewLine;
					return token;
				
				case '=':
					nc;
				
					token.type = TokenType.Assign;
					return token;
				
				case '"':
					token.type = TokenType.String;

					while(nc != '"')
						token.text ~= c;
					
					nc;
					
					if(c == '\0')
						error("unexpected end of file");
					
					return token;
				
				case '\0':
					token.type = TokenType.EndOfFile;
					return token;
				
				default:
					error("unexpected char"); 
				}
			}
		}
	}
	
	// Parsing
	class Parser
	{
	private:
		Tokenizer tokenizer;
		
		Token token;
		
		void error(char[] msg)
		{
			throw new ConfigException(msg, token.line);
		}
		
		// Returns how the current line is indented
		uint measureIndent()
		out
		{
			assert(token.type != TokenType.Indent);
		}
		body
		{
			uint result;
			
			if(token.type != TokenType.Undefined &&
			   token.type != TokenType.Indent)
			   return 0; // the line is not indented at all
			
			if(token.type == TokenType.Indent)
				result = 1;
			
			do
			{
				next;
				
				if(token.type == TokenType.EndOfFile)
					return result;
				
				if(token.type == TokenType.Indent)
					result++;
			}
			while(token.type == TokenType.Indent);
			
			return result;
		}
		
		Token next()
		{
			return token = tokenizer.next();
		}
		
	public:
		this(Tokenizer tokenizer)
		{
			this.tokenizer = tokenizer;
		}
		
		uint parse(ConfigSection section)
		{
			auto indent = measureIndent();
			bool noIndentCheck;
			
			while(true)
			{			
				noIndentCheck = false;
			
				switch(token.type)
				{
				case TokenType.LBracket:
					if(next.type != TokenType.Identifier)
						error("expected 'identifier' after 'section'");

					auto name = token.text;
					
					if(next.type != TokenType.RBracket)
						error("expected ']' after section identifier, got " ~ Integer.toString(token.type));
					
					if(next.type != TokenType.NewLine)
						error("expected 'new line' after section definition");
					
					next;
					
					auto newIndent = parse(new ConfigSection(section, name));
					
					if(newIndent < indent)
						return newIndent;
					
					noIndentCheck = true;
					
					break;
					
				case TokenType.Identifier:
					auto name = token.text;

					next;
					
					if(token.type == TokenType.NewLine ||
					   token.type == TokenType.EndOfFile)
					{
						section.variables[name] = ConfigVariable();
						break;
					}
					
					if(token.type != TokenType.Assign)
						error("expected '=' after 'identifier'");

					next;

					{
						ConfigVariable variable;
						   
						if(token.type == TokenType.Number)
							variable = ConfigVariable(token.number);
						else if(token.type == TokenType.String)
							variable = ConfigVariable(token.text);
							
						section.variables[name] = variable;
					}
					
					next;
					
					if(token.type == TokenType.EndOfFile)
						return 0;
					
					if(token.type != TokenType.NewLine)
						error("expected 'new line' after variable definition");
					
					next;
					
					break;
					
				case TokenType.EndOfFile:
					return 0;
				
				case TokenType.NewLine:
					next;
					
					if(token.type == TokenType.EndOfFile)
						return 0;
				
					break;
				
				default:
					error("unhandled token: " ~ Integer.toString(token.type));
					
					break;
				}
				
				if(token.type == TokenType.EndOfFile)
					return 0;
				
				if(!noIndentCheck)
				{
					auto newIndent = measureIndent();

					if(newIndent < indent && token.type != TokenType.NewLine)
						return newIndent;
				}
			}
		}
	}
}
