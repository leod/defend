module engine.rend.opengl.TextureFB;

import engine.rend.Texture;
import engine.rend.opengl.Framebuffer;
import engine.rend.opengl.Wrapper;
import engine.rend.opengl.Texture;

class OGLTextureFB : OGLFramebuffer
{
private:
	OGLTexture target;

public:
	this(OGLTexture target)
	{
		this.target = target;
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
	}
	
	override void unbind()
	{
		target.copyFromScreen();
		glPopAttrib();
	}
}
