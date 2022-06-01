module engine.scene.nodes.ModelNode;

import engine.mem.Memory;
import engine.rend.Renderer;
public import engine.math.Vector;
import engine.math.BoundingBox;
import engine.model.Instance;
import engine.model.Model;
import engine.model.Mesh;
import engine.scene.Node;
import engine.scene.Camera;
import engine.scene.Graph;
import engine.scene.nodes.MeshNode;

class ModelNode : SceneNode
{
private:
	Model model_;
	alias .BoundingBox!(float) BoundingBox;
	BoundingBox boundingBox_;
	Instance instance_;

	void calcBoundingBox()
	{
		boundingBox_ = instance_.boundingBox;
		
		boundingBox_.min *= scaling;
		boundingBox_.max *= scaling;

		boundingBox_.min += relativePosition;
		boundingBox_.max += relativePosition;
	}

public:
	mixin MAllocator;

	this()
	{
		super(null);
	}

	this(SceneNode parent)
	{
		super(parent);
	}
	
	this(SceneNode parent, char[] path)
	{
		this(parent);
		setModel(Model.get(path));
	}
	
	this(SceneNode parent, Model model)
	{
		this(parent);
		setModel(model);
	}
	
	~this()
	{
		if(model_)
			resetModel();
	}

	Model getModel()
	{
		return model_;
	}

	void setModel(Model model)
	{
		if(model_)
			resetModel();
	
		Model.acquire(model);
		
		model_ = model;
		instance_ = model_.createInstance();
		
		foreach(mesh; model_.meshes())
			auto node = new MeshNode(this, mesh, instance_);
		
		calcBoundingBox();
	}
	
	void resetModel()
	{
		assert(model_ !is null);

		model_.freeInstance(instance_);
		subRef(model_);
		model_ = null;
		instance_ = null;

		recurseChildren((MeshNode mesh)
		{
			delete mesh;
			
			return false;
		});
		
		child = null;
	}
	
	override void update()
	{
		if(!model_)
			return;
		
		if(recalcModelview)
			calcBoundingBox(); 
	}
	
	BoundingBox boundingBox()
	{
		return boundingBox_;
	}
}
