module engine.model.Mesh;

import engine.rend.Texture : Texture;
import engine.rend.VertexContainer : VertexContainerBase;
import engine.mem.Memory;
import engine.util.Vertex : VertexTexPosNor;
import engine.util.RefCount;

abstract class Mesh
{
public:
	alias VertexTexPosNor Vertex;
	alias VertexContainerBase!(Vertex) ContainerBase;

	this(Texture texture, ContainerBase verticesBase)
	{
		assert(verticesBase.length);
		texture_ = texture;
		verticesBase_ = verticesBase;
		verticesBase_.synchronize();
	}

	~this()
	{
		delete verticesBase_;

		if(texture_)
			subRef(texture_);
	}

	void render();

	Texture texture()
	{
		return texture_;
	}

	ContainerBase vertices()
	{
		return verticesBase_;
	}

protected:
	Texture texture_;
	ContainerBase verticesBase_;

	mixin MAllocator;
}
