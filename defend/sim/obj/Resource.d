module defend.sim.obj.Resource;

import xf.xpose2.Expose;
import xf.xpose2.Serialization;

import engine.math.Vector;
import engine.math.Ray;
import engine.model.Model;
import engine.scene.Graph;
import engine.scene.Node;
import engine.util.RefCount : subRef;

import defend.sim.Resource;
import defend.sim.Player;
import defend.sim.Core;
import defend.sim.SceneNode;

static this()
{
	typeRegister.addLoader("resource", (ResourceTypeInfo ti)
	{
		with(ti)
		{
			abstractType = true;
			parentType = "base";
		}
	});
	
	typeRegister.addLoader("wood", (ResourceTypeInfo ti)
	{
		with(ti)
		{
			parentType = "resource";
			resourceType = ResourceType.Wood;
			model = "tree/untitled.obj";
			posOffset = vec3.zero;
			scale = vec3.one;
			dimension = vec2i(1, 1);
			initialAmount = 1000;
		}
	});
}

class ResourceTypeInfo : ObjectTypeInfo
{
	ResourceType resourceType;
	uint initialAmount;
	
	mixin(xpose2(""));
	mixin xposeSerialization;
	
	this()
	{
		fogOfWarCache = true;
		isNeutral = true;
	}

	override void construct()
	{
		super.construct();
		
		if(model !is model.init)
			Model(model);
		
		objectClass = ObjectClass.Resource;
		
		allocateObject = function GameObject() { return new Resource; };
		freeObject = function void(GameObject object) { delete object; };
	}
	
	override void destruct()
	{
		if(model !is model.init)
			subRef(Model.get(model));
	}
}

class Resource : GameObject
{
protected:
	ResourceTypeInfo resourceInfo;

	uint amountLeft;

	override void createSceneNode()
	{
		//Trace.formatln("resource {}@{}@{}@{}", realPos, mapPos, owner, id);
		//super.createDefaultSceneNode(true);
		
		super.createSceneNode();
	}
	
public:
	mixin(xpose2("
		resourceInfo
		amountLeft
	"));
	mixin xposeSerialization;

	override void onCreate()
	{
		super.onCreate();
		
		assert(owner == NEUTRAL_PLAYER);
		
		resourceInfo = cast(ResourceTypeInfo)typeInfo;
		assert(resourceInfo !is null);
		
		amountLeft = resourceInfo.initialAmount;

		initRealPos();
		createSceneNode();
		
		markMap(false);
	}

	override void onUnserialized()
	{
		super.onUnserialized();

		//markMap(false);
	}
	
	override void onRemove()
	{
		markMap(true);
	}
	
	override void cleanUp()
	{
		super.cleanUp();
	}

	final bool whacked()
	{
		return amountLeft == 0;
	}
	
	final uint leech()
	{
		assert(!whacked);
		--amountLeft;
	
		if(amountLeft == 0)
			selfRemove();
	
		return 1; // amount leeched
	}
}
