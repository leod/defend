module engine.rend.VertexContainerFactory;

import engine.rend.Renderer : Renderer, renderer;
import engine.rend.opengl.Renderer : OGLRenderer;
import engine.rend.VertexContainer : Usage, VertexContainer;

V createVertexContainer(V : VertexContainer!(T, U), T, Usage U)(T[] elements)
{
	switch(renderer.engine)
	{
	case Renderer.Engine.OpenGL:
		return (cast(OGLRenderer)renderer).createVertexContainer!(V)(elements);
		break;
	
	default:
		assert(false);
	}
}