module engine.scene.nodes.MeshNode;

import engine.rend.Renderer;
import engine.math.Vector;
import engine.math.Matrix;
import engine.math.BoundingBox;
import engine.model.Instance;
import engine.model.Mesh;
import engine.mem.Memory;
import engine.util.Profiler;
import engine.mem.MemoryPool;
import engine.scene.Node;
import engine.scene.Graph;
import engine.scene.Node;
import engine.scene.Camera;
import engine.image.Image;

class MeshNode : SceneNode
{
private:
	Mesh mesh_;
	Instance modelInstance_;

	void render()
	{
		renderer.pushMatrix();
		renderer.mulMatrix(absoluteTransformation);
		renderer.setColor(parent.color); // use color of parent model
		renderer.setTexture(0, null);
		
		modelInstance_.set();
		mesh_.render();
		
		renderer.setColor(vec3.one);
		renderer.popMatrix();
	}

public:
	this(SceneNode parent, Mesh mesh, Instance instance)
	{
		super(parent);
	
		mesh_ = mesh;
		modelInstance_ = instance;
	}
	
	Mesh getMesh()
	{
		return mesh_;
	}
	
	void setMesh(Mesh newMesh)
	{
		mesh_ = newMesh;
		texture = mesh_.texture;
	}

	override void registerForRendering(Camera camera)
	{
		sceneGraph.passSolid.add(camera, this, &render);
	}
}
