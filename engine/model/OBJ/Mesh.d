module engine.model.OBJ.Mesh;

import engine.model.Mesh : BaseMesh = Mesh;
import engine.model.Instance : BaseInstance = Instance;
import engine.rend.Renderer : renderer;
import engine.rend.Texture : Texture;
import engine.rend.VertexContainer : Primitive, Usage, VertexContainer;
import engine.rend.VertexContainerFactory : createVertexContainer;

package class Mesh
	: BaseMesh
{
	alias VertexContainer!(Vertex, Usage.StaticDraw) Container;

	this(Primitive type, Texture texture, Vertex[] vertices)
	{
		vertices_ = createVertexContainer!(Container)(vertices);
		super(texture, vertices_);
		type_ = type;
	}

	override void render()
	{
		renderer.setTexture(0, texture_);
		vertices_.draw(type_);
	}

private:
	Primitive type_;
	Container vertices_;
}

final class Instance
	: BaseInstance
{
	this(BaseInstance.BoundingBox boundingBox)
	{
		boundingBox_ = boundingBox;
	}

	override
	{
		void set()
		{
		}

		void setAnimation(char[] animationName)
		{
			// NOOP
		}

		void stopAnimation()
		{
			// NOOP
		}

		bool newBoundingBox()
		{
			return false;
		}

		BaseInstance.BoundingBox boundingBox()
		{
			return boundingBox_;
		}
	}

private:
	BaseInstance.BoundingBox boundingBox_;
}
