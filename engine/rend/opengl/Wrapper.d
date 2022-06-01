module engine.rend.opengl.Wrapper;

// Thanks to Dk (http://while-nan.blogspot.com/) for this idea

public
{
	import derelict.opengl.gl;
	import derelict.opengl.glu;
	import derelict.opengl.extension.arb.multitexture;
	import derelict.opengl.extension.arb.vertex_buffer_object;
}

import tango.core.Traits;
import tango.stdc.string;

private bool insideblock = false; // Are we currently inside of a glBegin/glEnd block?

//debug = dump;

template glCheck(alias Fn)
{
	ReturnTypeOf!(typeof(*Fn)) glCheck(ParameterTupleOf!(typeof(*Fn)) args)
	{		
		alias ReturnTypeOf!(typeof(*Fn)) ReturnType;
		
		static if(is(ReturnType == void))
			Fn(args);
		else
			auto result = Fn(args);
		 
		debug
		{
			static if(Fn.stringof == "glBegin")
				insideblock = true;
			else if(Fn.stringof == "glEnd")
				insideblock = false;

			if(!insideblock)
			{
				auto error = glGetError();
				
				if(error)
				{
					auto string = cast(char*)gluErrorString(error);
					assert(false, "gl error: " ~ string[0 .. strlen(string)] ~ " while calling " ~ Fn.stringof);
				}
			}
		}
		
		static if(!is(ReturnType == void))
			return result;
	}
}

alias derelict.opengl.gl GL;
alias derelict.opengl.extension.arb.vertex_buffer_object GL_VBO;
alias derelict.opengl.glu GLU;

alias glCheck!(GL.glViewport) glViewport;
alias glCheck!(GL.glReadPixels) glReadPixels;
alias glCheck!(GL.glTexImage2D) glTexImage2D;
alias glCheck!(GL.glMatrixMode) glMatrixMode;
alias glCheck!(GL.glLoadIdentity) glLoadIdentity;
alias glCheck!(GL.glShadeModel) glShadeModel;
alias glCheck!(GL.glClearColor) glClearColor;
alias glCheck!(GL.glEnable) glEnable;
alias glCheck!(GL.glDisable) glDisable;
alias glCheck!(GL.glClearDepth) glClearDepth;
alias glCheck!(GL.glDepthFunc) glDepthFunc;
alias glCheck!(GL.glHint) glHint;
alias glCheck!(GL.glClear) glClear;
alias glCheck!(GL.glBegin) glBegin;
alias glCheck!(GL.glEnd) glEnd;
alias glCheck!(GL.glVertex3f) glVertex3f;
alias glCheck!(GL.glTexCoord2f) glTexCoord2f;
alias glCheck!(GL.glGenTextures) glGenTextures;
alias glCheck!(GL.glBindTexture) glBindTexture;
alias glCheck!(GL.glTexParameteri) glTexParameteri;
alias glCheck!(GL.glTexImage2D) glTexImage2D;
alias glCheck!(GL.glRotatef) glRotatef;
alias glCheck!(GL.glScalef) glScalef;
alias glCheck!(GL.glTranslatef) glTranslatef;
alias glCheck!(GL.glMultMatrixf) glMultMatrixf;
alias glCheck!(GL.glPushMatrix) glPushMatrix;
alias glCheck!(GL.glPushMatrix) glPushMatrix;
alias glCheck!(GL.glPopMatrix) glPopMatrix;
alias glCheck!(GL.glLoadMatrixf) glLoadMatrixf;
alias glCheck!(GL.glGetIntegerv) glGetIntegerv;
alias glCheck!(GL.glTexEnvf) glTexEnvf;
alias glCheck!(GL_VBO.glGenBuffersARB) glGenBuffersARB;
alias glCheck!(GL_VBO.glBufferDataARB) glBufferDataARB;
alias glCheck!(GL_VBO.glMapBufferARB) glMapBufferARB;
alias glCheck!(GL_VBO.glUnmapBufferARB) glUnmapBufferARB;
alias glCheck!(GL_VBO.glBindBufferARB) glBindBufferARB;
alias glCheck!(GL_VBO.glBufferSubDataARB) glBufferSubDataARB;
alias glCheck!(GLU.gluUnProject) gluUnProject;
