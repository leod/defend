module engine.rend.opengl.Texture;

import engine.mem.Memory;
import engine.image.Image;
import engine.math.Vector;
import engine.rend.Texture;
import engine.rend.opengl.Wrapper;

class OGLTexture : Texture
{
private:
	ImageFormat _format;

	vec2i dim;
	
	void create()
	{
		glGenTextures(1, &id);
		bind();
		
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);	
	}
	
package:
	GLuint id;

	void bind()
	{		
		glBindTexture(GL_TEXTURE_2D, id);
	}
	
public:
	mixin MAllocator;

	this(Image image)
	{
		_format = image.format;
		
		create();

		//glTexImage2D(GL_TEXTURE_2D, 0, cast(uint)format, 
		//			 image.width, image.height, 0, Image.formatToOpenGL(format), 
		//			 GL_UNSIGNED_BYTE, image.data.ptr);
		
		gluBuild2DMipmaps(GL_TEXTURE_2D, cast(uint)format,
		                  image.width, image.height,
		                  Image.formatToOpenGL(format),
		                  GL_UNSIGNED_BYTE, image.data.ptr);
		
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);	
		
		dim = image.dimension;
		image.free();
		delete image;
	}
	
	this(vec2i dim, ImageFormat format)
	{
		this.dim = dim;
		_format = format;
		
		create();

		{
			auto t = cast(uint)format;
			auto f = Image.formatToOpenGL(format);
			
			if(format == ImageFormat.A)
			{
				t = GL_DEPTH_COMPONENT24;
				f = GL_DEPTH_COMPONENT;
			}

			glTexImage2D(GL_TEXTURE_2D, 0, t, dim.x, dim.y, 0, f, GL_UNSIGNED_BYTE, null);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		}
	}
	
	~this()
	{
		glDeleteTextures(1, &id);
	}
	
	override void update(int x, int y, vec3ub c)
	{
		glPushAttrib(GL_TEXTURE_BIT);
		scope(exit) glPopAttrib();
		
		bind();
		
		glTexSubImage2D(GL_TEXTURE_2D, 0, x, y, 1, 1,
		                Image.formatToOpenGL(format),
						GL_UNSIGNED_BYTE, &c);
	}
	
	override uint width()
	{
		return dimension.x;
	}
	
	override uint height()
	{
		return dimension.y;
	}
	
	override vec2i dimension()
	{
		return dim;
	}

	override ImageFormat format()
	{
		return _format;
	}

	override void copyFromScreen()
	{
		assert(format == ImageFormat.RGB);
		
		glPushAttrib(GL_TEXTURE_BIT);
		scope(exit) glPopAttrib();
		
		bind();
		
		glCopyTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, 0, 0, width, height);
		//glCopyTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, 0, 0, width, height, 0);
	}
	
	override void setFilter(Filter filter)
	{
		GLenum f;
		
		switch(filter)
		{
			case Filter.Nearest:
				f = GL_NEAREST;
				break;
		
			case Filter.Linear:
				f = GL_LINEAR;
				break;
				
			case Filter.MipMapLinear:
				f = GL_LINEAR_MIPMAP_LINEAR;
				break;
				
			default:
				assert(false);
		}
		
		glPushAttrib(GL_TEXTURE_BIT);
		scope(exit) glPopAttrib();
		
		bind();

		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, f);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, f);
	}
	
	override void clamp()
	{
		glPushAttrib(GL_TEXTURE_BIT);
		scope(exit) glPopAttrib();
	
		bind();
		
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	}
}
