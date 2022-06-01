module engine.rend.opengl.Framebuffer;

import engine.rend.Framebuffer;

abstract class OGLFramebuffer : Framebuffer
{
	abstract void bind();
	abstract void unbind();
}
