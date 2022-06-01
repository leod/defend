module engine.rend.opengl.FBO;

import derelict.opengl.extension.ext.framebuffer_object;

import engine.mem.Memory;
import engine.image.Image;
import engine.rend.Framebuffer;
import engine.rend.Texture;
import engine.rend.opengl.Framebuffer;
import engine.rend.opengl.Texture;
import engine.rend.opengl.Wrapper;

package class FBO : OGLFramebuffer
{
private:
	GLuint id;
	
	Texture target;

public:
	mixin MAllocator;

	this(OGLTexture target)
	{
		this.target = target;
	
		glGenFramebuffersEXT(1, &id);
		bind();
		
		{
			GLuint format;
			
			switch(target.format)
			{
			case ImageFormat.RGB:
				format = GL_COLOR_ATTACHMENT0_EXT;
				break;
				
			case ImageFormat.A:
				format = GL_DEPTH_ATTACHMENT_EXT;
				
				glDrawBuffer(GL_FALSE);
				glReadBuffer(GL_FALSE);
				break;
				
			default:
				assert(false);
			}
		
			//GLuint depthbuffer;
			//glGenRenderbuffersEXT(1, &depthbuffer);
			//glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, depthbuffer);
			//glRenderbufferStorageEXT(GL_RENDERBUFFER_EXT, GL_DEPTH_COMPONENT, texture.width, texture.height);
			//glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_DEPTH_ATTACHMENT_EXT, GL_RENDERBUFFER_EXT, depthbuffer);
			glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, format, GL_TEXTURE_2D, target.id, 0);
		
			//glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, format, GL_TEXTURE_2D, target.id, 0);
		}

		unbind();
	}
	
	~this()
	{
		delete target;
	}
	
	override Texture texture()
	{
		return target;
	}
	
	override void bind()
	{
		glPushAttrib(GL_VIEWPORT_BIT);
		glViewport(0, 0, target.width, target.height);
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, id);
	}
	
	override void unbind()
	{
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);
		glPopAttrib();
	}
}
