module defend.sim.SceneNode;

import engine.util.Log : MLogger;
import engine.util.Cast;
import engine.mem.Memory;
import engine.util.Statistics;
import engine.math.Vector;
import engine.math.BoundingBox;
import engine.scene.Node;
import engine.scene.Graph;
import engine.scene.Camera;
import engine.scene.RenderPass;
import engine.scene.effect.Effect;
import engine.scene.effect.Node;
import engine.scene.effect.Library;
import engine.model.Model;
import engine.model.Instance;
import engine.model.Mesh;
import engine.rend.Renderer;

import defend.Config;
import defend.terrain.ITerrain;
import defend.sim.IFogOfWar;

class GameObjectModel : SceneNode
{
	mixin MLogger;

private:
	Model model_;
	Instance modelInstance_;
	Instance.BoundingBox boundingBox_;
	
	void calcBoundingBox()
	{
		++statistics.bbox_xforms;
	
		// doesn't include the parents rotation.. and is slow :F
		boundingBox_ =  modelInstance_.boundingBox.xform(matrixRotation);
		boundingBox_.min *= scaling;
		boundingBox_.max *= scaling;
		boundingBox_.min += relativePosition;
		boundingBox_.max += relativePosition;
		
		//logger.spam("recalculating bounding box");
	}

public:
	mixin MAllocator;

	vec3 color;
	bool isNeutral;
	
	// set by the game objects in their update()-function
	bool fogOfWarCulled;
	
	this(SceneNode parent, ITerrain terrain,
	     char[] path, vec3 color, bool isNeutral = false,
	     vec3 initTranslate = vec3.zero, vec3 initScale = vec3.zero, vec3 initRot = vec3.zero)
	{
		super(parent);
		assert(parent !is null);
		
		model_ = Model(path);
		modelInstance_ = model_.createInstance();
		
		this.color = color;
		this.isNeutral = isNeutral;
		
		translation = initTranslate;
		scaling = initScale;
		rotation = initRot;
		
		foreach(mesh; model_.meshes)
			new GameObjectMesh(this, terrain, mesh);

		calcTransformation();
		calcBoundingBox();
	}
	
	~this()
	{
		model_.freeInstance(modelInstance_);
		subRef(model_);
	}
	
	override void update()
	{
		//logger.spam("updating");
	
		if(recalcModelview || modelInstance_.newBoundingBox)
			calcBoundingBox();
	}
	
	override void registerForRendering(Camera camera)
	{
		visible = camera.frustum.boundingBoxVisible(boundingBox_) && !fogOfWarCulled;
		//visible = true;
		
		//debug if(sceneGraph.debugNodeVisible(this) && visible)
		//	sceneGraph.addToRender(RenderPass.Debug, this);
	}
	
	/+debug override void render()
	{
		renderer.pushMatrix();
		//renderer.mulMatrix(absoluteTransformation);
		renderer.drawBoundingBox(boundingBox_, vec3(0, 0.5, 1));
		renderer.popMatrix();
	}+/

	override Instance.BoundingBox boundingBox()
	{
		return boundingBox_;
	}

	void setAnimation(char[] name)
	{
		modelInstance_.setAnimation(name);
	}
}

// normal effect for rendering the object
abstract class GameObjectEffect : Effect
{
	ITerrain terrain;
	Texture fogOfWarTexture;

	this(char[] name, int score)
	{
		super("game object", name, score);
	}

	abstract void registerForRendering(Camera camera, GameObjectMesh node);
	void inject(RenderPass delegate(RenderPass) dg) {}

	static this()
	{
		gEffectLibrary.addEffectType("game object");
	}
}

abstract class GameObjectCustomEffect : Effect
{
	this(char[] name, int score)
	{
		super("game object custom", name, score);
	}
	
	abstract void registerForRendering(Camera camera, GameObjectMesh node);

	static this()
	{
		gEffectLibrary.addEffectType("game object custom");
	}
}

class GameObjectMesh : SceneNode
{
private:
	Mesh mesh;
	GameObjectModel _parent;

	mixin MEffectSupport!(GameObjectEffect, "game object") mainEffect;
	mixin MEffectSupport!(GameObjectCustomEffect, "game object custom", true) customEffects;

public:
	mixin MAllocator;

	this(GameObjectModel parent, ITerrain terrain, Mesh mesh)
	{
		super(parent);
		
		this._parent = parent;
		this.mesh = mesh;
		
		texture = mesh.texture;
		renderShadow = true;

		mainEffect.load();
		mainEffect.best.terrain = terrain;
		mainEffect.best.fogOfWarTexture = terrain.lightmap;
		
		customEffects.load();
	}

	GameObjectModel parent()
	{
		return _parent;
	}

	void renderMesh()
	{
		parent.modelInstance_.set();
		mesh.render();
	}
	
	override void registerForRendering(Camera camera)
	{
		mainEffect.register(camera);
		customEffects.register(camera);
	}
}
