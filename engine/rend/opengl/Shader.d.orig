module engine.rend.opengl.Shader;

import tango.text.Util;
import Path = tango.io.Path;
import tango.io.Stdout;
import tango.text.Util : locate;

import derelict.opengl.gl;
import derelict.opengl.glu;
import derelict.opengl.extension.arb.shading_language_100;
import derelict.opengl.extension.arb.shader_objects;
import derelict.opengl.extension.arb.vertex_shader;
import derelict.opengl.extension.arb.fragment_shader;

import engine.math.Vector;
import engine.math.Matrix;
import engine.rend.Shader;
import engine.util.Config;
import engine.util.File;
import engine.util.Resource : ResourcePath;

package class OGLShader : Shader
{
private:
	char[] globalDefines;
	
	int context;

	int[char[]] uniformHandles;

	char[] preprocessIncludes(char[] base, char[] code)
	{
		char[] result;
	
		foreach(origLine; lines(code))
		{
			auto line = trim(origLine);
		
			if(!line.length || line[0] != '#')
				continue;
			
			if(auto pos = locate(line, ' '))
			{
				auto command = trim(line[1 .. pos]);
				
				if(command == "include")
				{
					withReadFile(base ~ line[pos + 2 .. $ - 1], (char[] code)
					{
						result ~= code ~ "\n" ~ preprocessIncludes(base, code) ~ "\n";
					});
					
					// whatever :P
					{
						auto offset = origLine.ptr - code.ptr;
						code[offset .. offset + origLine.length] = ' ';
					}
				}
			}
		}
		
		return result;
	}

	void checkError(int object, int type)
	{
		int status;
	
		glGetObjectParameterivARB(object, type, &status);
		
		if(status == 0)
		{
			int length;
			char[] error;
			
			glGetObjectParameterivARB(object, GL_OBJECT_INFO_LOG_LENGTH_ARB, &length);
			error.length = length + 1;
			
			glGetInfoLogARB(object, length, &length, error.ptr);
			
			Stdout("GLSL error: ")(error).newline;
			throw new Exception("GLSL error: " ~ error);
		}
	}

	import tango.io.Console;

	void compile(U, T...)(U type, T codes)
	{
		assert(context);
		
		auto result = glCreateShaderObjectARB(type);
		
		char*[T.length] strings;
		int[T.length] lengths;
		
		foreach(i, code; codes)
		{
			//Stdout(code).newline;
			//Cin.get;
		
			// somehow the \0 is necessary even though I'm passing the lengths
			strings[i] = (code ~ '\0').ptr;
			lengths[i] = code.length;
		}

		glShaderSourceARB(result, T.length, strings.ptr, lengths.ptr);
		glCompileShaderARB(result);
        
        glAttachObjectARB(context, result);
        
        checkError(result, GL_OBJECT_COMPILE_STATUS_ARB);
        
        return result;
	}

	void link()
	{
		glLinkProgramARB(context);
		
		checkError(context, GL_OBJECT_LINK_STATUS_ARB);
	}

	int uniformHandle(char[] name)
	in
	{
		assert(*(name.ptr + name.length) == '\0', "uniform names need to be zero terminated");
	}
	body
	{
		if(auto handle = name in uniformHandles)
			return *handle;
		
		return (uniformHandles[name] = glGetUniformLocationARB(context, name.ptr));
	}
	
	void init()
	{
		//if(!ARBVertexShader.isEnabled || !ARBFragmentShader.isEnabled)
		//	throw new Exception("u can has shaderz 2.0 kthxbai");	
			
		context = glCreateProgramObjectARB();
		
		// create GLSL code for setting the global defines
		foreach(key, val; Shader.defines)
			globalDefines ~= "#define " ~ key ~ " " ~ val ~ "\n";
	}

	private void createFromFile(U, T...)(char[] file, char[] base, U type, T codes)
	{
		auto path = base ~ '/' ~ file;

		if (!Path.exists(path)) {
			return;
		}

		withReadFile(path, (char[] content)
		{
			// preprocess must be called before compile() because it might change 'code'
			auto includes = preprocessIncludes(base, content);

			compile(type, codes, globalDefines, includes, content);
		});
	}

	void createShaders(T...)(char[] base, char[] vertexFile, char[] pixelFile, T codes)
	{
		createFromFile(pixelFile, base, GL_FRAGMENT_SHADER_ARB, codes);
		createFromFile(vertexFile, base, GL_VERTEX_SHADER_ARB, codes);
	}

package:
	void bind()
	{
		glUseProgramObjectARB(context);
	}
	
	static void unbind()
	{
		glUseProgramObjectARB(0);
	}

public:
	mixin MAllocator;

	this(ResourcePath path)
	{
		init();
		scope config = new Config(path.fullPath);
		char[] definesCode;

		if(config.hasChild("defines"))
		{
			foreach(char[] name, ConfigVariable var; config("defines"))
				definesCode ~= "#define " ~ name ~ "\n";
		}

		createShaders(config.path, config.string("vertex_shader"), config.string("pixel_shader"), definesCode);
		link();
	}
	
	~this()
	{
		
	}
	
	override void setUniform(char[] name, int value)
	{
		glUniform1iARB(uniformHandle(name), value);
	}
	
	override void setUniform(char[] name, vec2 value)
	{
		glUniform2fARB(uniformHandle(name), value.tuple);
	}
	
	override void setUniform(char[] name, vec3 value)
	{
		glUniform3fARB(uniformHandle(name), value.tuple);
	}
	
	override void setUniform(char[] name, vec4 value)
	{
		glUniform4fARB(uniformHandle(name), value.tuple);
	}
	
	override void setUniform(char[] name, mat4 value)
	{
		glUniformMatrix4fvARB(uniformHandle(name), 1, false, value.ptr);
	}
}
