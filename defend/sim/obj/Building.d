module defend.sim.obj.Building;

import xf.hybrid.Hybrid;
import xf.hybrid.widgets.Button;
import xf.hybrid.widgets.Label;
import xf.hybrid.widgets.Check;
import xf.hybrid.widgets.Progressbar;
import xf.hybrid.widgets.ScrollView;

import xf.xpose2.Expose;
import xf.xpose2.Serialization;

import engine.model.Model;
import engine.list.LinkedList;
import engine.rend.Renderer;
import engine.rend.opengl.Wrapper;
import engine.mem.Memory;
import engine.util.Swap;
import engine.util.Cast;
import engine.util.Lang;
import engine.math.Misc;
import engine.scene.Node;
import engine.scene.Graph;
import engine.scene.nodes.ParticleSystem;
import engine.math.Rectangle;
import engine.math.Vector;
import engine.math.Ray;

import defend.Config : playerColors, HUD_HEIGHT;
import defend.sim.Resource;
import defend.sim.Core;
import defend.sim.SceneNode;
import defend.sim.Effector;
import defend.sim.IHud;
import defend.sim.IFogOfWar;
import defend.sim.obj.Unit;

static this()
{
	typeRegister.addLoader("building", (BuildingTypeInfo ti)
	{
		with(ti)
		{
			abstractType = true;
			parentType = "base";
		}
	});
}

class DevelopmentTechnology : Technology
{
	object_type_t[] objectTypes;
	tech_t[] techTypes;
	
	mixin(xpose2(""));
	mixin xposeSerialization;
	
	override void develop()
	{
		foreach(type; objectTypes)
			gameObjects.getTypeInfo(owner, type).available = true;
			
		foreach(tech; techTypes)
			gameObjects.getTech(owner, tech).available = true;
	}
}

const uint MAX_BUILDING_QUEUE_LENGTH = 25;

struct OrderBuildUnit
{
	mixin MOrder!(OrderBuildUnit);

	// could send the local_id_t instead, to avoid sending strings over the net
	object_type_t unitType;
	
	static OrderBuildUnit opCall(object_type_t unitType)
	{
		OrderBuildUnit result;
		result.unitType = unitType;
		
		return result;
	}
}

struct OrderDevelop
{
	mixin MOrder!(OrderDevelop);
	
	tech_t techType;
	
	static OrderDevelop opCall(tech_t techType)
	{
		OrderDevelop result;
		result.techType = techType;
		
		return result;
	}
}

class BuildingTypeInfo : ObjectTypeInfo
{
	object_type_t[] canBuild;
	tech_t[] canDevelop;
	
	// Time needed for building (in simulation steps)
	uint buildSteps = 30;

	// Cost
	ResourceArray cost;
	
	mixin(xpose2("
		canBuild
		canDevelop
		buildSteps
		cost
	"));
	mixin xposeSerialization;

	// Orders
	OrderError checkMapRightClickOrder(GameObject[] objects,
		OrderMapRightClick* order)
	{
		return map[order.x, order.y].walkable ?
		       OrderError.Okay : OrderError.Error;
	}
	
	void onMapRightClickOrder(GameObject[] objects,
		OrderMapRightClick* order)
	{
		auto pos = map_pos_t(order.x, order.y);
		assert(map[pos].walkable);
		
		iterateObjects(objects, (Building object)
		{
			object.buildTarget = pos;
		});
	}
	
	OrderError checkBuildUnitOrder(GameObject[] objects,
		OrderBuildUnit* order)
	{
		auto typeInfo = objCast!(UnitTypeInfo)
			(gameObjects.getTypeInfo(owner, order.unitType));
	
		return gameObjects.players[objects[0].owner].canBuy(typeInfo.cost)
			? OrderError.Okay : OrderError.TooExpensive;
	}
	
	void onBuildUnitOrder(GameObject[] objects, OrderBuildUnit* order)
	{
		auto typeInfo = objCast!(UnitTypeInfo)
			(gameObjects.getTypeInfo(owner, order.unitType));
	
		iterateObjects(objects, (Building object)
		{
			if(gameObjects.players[objects[0].owner].
				tryBuy(typeInfo.cost))
			{
				object.enqueue(typeInfo);
			}
		});
	}
	
	OrderError checkDevelopOrder(GameObject[] objects, OrderDevelop* order)
	{
		auto typeInfo = objCast!(Technology)
			(gameObjects.getTech(owner, order.techType));
	
		return gameObjects.players[objects[0].owner].canBuy(typeInfo.cost)
			? OrderError.Okay : OrderError.TooExpensive;		
	}
	
	void onDevelopOrder(GameObject[] objects, OrderDevelop* order)
	{
		auto typeInfo = objCast!(Technology)
			(gameObjects.getTech(owner, order.techType));
		
		iterateObjects(objects, (Building object)
		{
			// first check if this is already being developed
			if(object.hasQueueEntryOfType(typeInfo))
				return;
		
			if(gameObjects.players[objects[0].owner].
				tryBuy(typeInfo.cost))
			{
				object.enqueue(typeInfo);
			}
		});
	}

	this()
	{
		fogOfWarCache = true;
	}
	
	override void setDeps()
	{
		super.setDeps();
		
		addDeps(canBuild);
		addDeps(canDevelop);
	}
	
	override void construct()
	{
		super.construct();
	
		if(model != model.init)
			Model(model);
	
		objectClass = ObjectClass.Building;
		
		addOrderCallback("building", &checkMapRightClickOrder,
			null, &onMapRightClickOrder);

		addOrderCallback("building", &checkBuildUnitOrder,
			null, &onBuildUnitOrder);
			
		addOrderCallback("building", &checkDevelopOrder,
			null, &onDevelopOrder);
			
		allocateObject = function GameObject() { return new Building; };
		freeObject = function void(GameObject object) { delete object; };
	}
	
	override void destruct()
	{
		super.destruct();
	
		if(model != model.init)
			subRef(Model.get(model));
	}

	override void doLeftHud(IHud hud, GameObject[] selection)
	{
		super.doLeftHud(hud, selection);
	
		bool oneFinished = false;
		
		iterateObjects(selection, (Building building)
		{
			if(building.status == Building.Status.Finished)
				oneFinished = true;
		});
		
		if(!oneFinished)
			return;
	
		foreach(i, type; canBuild)
		{
			auto typeInfo = gameObjects.getTypeInfo(owner, type);
			
			if(!typeInfo.available)
				continue;
			
			if(Button(i).text(Lang.get("general", "build",
				Lang.Lookup(typeInfo.id))).clicked)
			{
				gameObjects.order(gameObjects.gateway, selection,
					OrderBuildUnit(type));
			}
		}
	
		foreach(i, type; canDevelop)
		{
			auto typeInfo = gameObjects.getTech(owner, type);
			
			if(!typeInfo.available || typeInfo.developed /*||
			   object.hasQueueEntryOfType(typeInfo)*/)
				continue;
			
			if(Button(i).text(Lang.get("general", "develop",
				Lang.Lookup(typeInfo.id))).clicked)
			{
				gameObjects.order(gameObjects.gateway, selection,
					OrderDevelop(type));
			}
		}
		
		if(selection.length == 1)
		{
			auto b = objCast!(Building)(selection[0]);
			
			if(!b.queue.empty)
			{
				auto q = b.queue.first;
				char[] verb = null;
				
				if(q.type == Building.QueueEntry.Type.Unit)
					verb = "building";
				else if(q.type == Building.QueueEntry.Type.Tech)
					verb = "developing";
				else
					assert(false);
			
				Label().
					fontSize(11).
					text(Lang.get("general", verb, Lang.Lookup(q.typeInfo.id)));
				
				Progressbar().
					position(1 - (cast(real)q.progress / q.typeInfo.devSteps)).
					userSize(vec2(100, 0));
			}
		}
	}
	
	override void doMiddleHud(IHud hud, GameObject[] selection)
	{
		auto building = objCast!(Building)(selection[0]);
	
		if(selection.length == 1 &&
			selection[0].status == Building.Status.Finished &&
			!building.queue.empty)
		{
			if(Check().text(Lang.get("general", "show_queue")).checked)
			{
				ScrollView().
					userSize(vec2(150, HUD_HEIGHT - 40))
				[{
					size_t i = 0;
					foreach(q; building.queue)
						Button(i++).text(Lang.get("objects", q.typeInfo.id));
				}];
			}
		}
	}
}

class Building : GameObject
{
private:
	static class QueueEntry
	{
		mixin MAllocator;
		mixin MLinkedList!(QueueEntry);
	
		enum Type
		{
			Default,
			Unit,
			Tech
		}
	
		Type type = Type.Default;
		fixed progress; // 0 = done
		TypeBase typeInfo;
		
		mixin(xpose2("
			type
			progress
			typeInfo
		"));
		mixin xposeSerialization;
		
		private this(TypeBase typeInfo)
		{
			assert(type != Type.Default);
			progress = fixed.fromInt(typeInfo.devSteps);
			this.typeInfo = typeInfo;
		}
		
		this(UnitTypeInfo typeInfo)
		{
			type = Type.Unit;
			this(cast(TypeBase)typeInfo);
		}
		
		this(Technology typeInfo)
		{
			type = Type.Tech;
			this(cast(TypeBase)typeInfo);
		}
		
		this() // for serialization
		{
		
		}
	}

	void enqueue(T : TypeBase)(T typeInfo)
	{
		queue.attach(new QueueEntry(typeInfo));
	}
	
	bool hasQueueEntryOfType(TypeBase type)
	{
		foreach(entry; queue)
		{
			if(entry.typeInfo is type)
				return true;
		}
		
		return false;
	}
	
protected:
	BuildingTypeInfo buildingInfo;
	map_pos_t buildTarget; // Where built units move to

	QueueEntry.LinkedList queue;

	uint buildSteps; // Progress of the building
	fixed lifeIncrease; // Life is increased by this value while building

	static void writeQueue(Building b, Serializer s)
	{
		s(b.queue.length);
		foreach(e; b.queue)
			s(e);
	}
	
	static void readQueue(Building b, Unserializer s)
	{
		int l;
		s(l);
		
		assert(b.queue.length == 0);
		
		for(int i = 0; i < l; ++i)
		{
			QueueEntry e;
			s(e);
			
			b.queue.attach(e);
		}
	}
	
public:
	mixin MAllocator;

	mixin(xpose2(`
		buildingInfo
		buildTarget
		queue serial { write "writeQueue"; read "readQueue" }
		buildSteps
		lifeIncrease
	`));
	mixin xposeSerialization;
	
	enum Status : object_status_t
	{
		// The object is yet to be built
		BuildUp = GameObject.Status.max + 1,
		
		// The building is finished
		Finished
	}

	enum Property : prop_type_t
	{
		BuildSpeed = GameObject.Property.max + 1
	}

	void initialStatus(object_status_t s)
	in
	{
		assert(s == Status.BuildUp || s == Status.Finished);
	}
	body
	{
		status = s;
		
		if(status == Status.BuildUp)
		{
			_sceneNode.scaling = vec3(typeInfo.scale.x,
				typeInfo.scale.y * 0.1f,
				typeInfo.scale.z);
		    
		    assert(buildingInfo.buildSteps > 1);
		                              
			buildSteps = buildingInfo.buildSteps / 10;
			
			lifeIncrease = property(GameObject.Property.MaxLife) /
				fixed.fromInt(buildingInfo.buildSteps);
			life = lifeIncrease * buildSteps;
			
			setPropFactor(GameObject.Property.Sight, prop_t.ctFromReal!(0));
		}
	}

	void oneBuildStep()
	{
		assert(status == Status.BuildUp);
		assert(buildSteps < buildingInfo.buildSteps);
		
		buildSteps++;
		life = life + lifeIncrease;
		
		//Stdout("set life to ")(life)(" (max ")(property(GameObject.Property.MaxLife))(")").newline;
		
		if(buildSteps == buildingInfo.buildSteps)
		{
			_sceneNode.scaling = typeInfo.scale;
			status = Status.Finished;
			
			setPropFactor(GameObject.Property.Sight, prop_t.ctFromReal!(1));
		}
	}

	override void cleanUp()
	{
		super.cleanUp();
		
		while(!queue.empty)
		{
			auto object = queue.detach(queue.first);
			delete object;
		}
	}

	override void onCreate()
	{
		super.onCreate();
		
		buildingInfo = objCast!(BuildingTypeInfo)(typeInfo);
		status = Status.Finished;
		
		buildTarget = mapPos;

		initRealPos();
		createSceneNode();

		markMap(false);
	}
	
	override void onUnserialized()
	{
		super.onUnserialized();
		
		markMap(false);
	}
	
	override void onRemove()
	{
		super.onRemove();
			
		if(localFogOfWarState == FogOfWarState.Visible)
		{
			foreach(x, y; mapRectangle)
				particles["smoke"].spawn(
					terrain.getWorldPos(x, y) + vec3(0, 1.5, 1), 1);
		}
		
		markMap(true);
	}
	
	override void render()
	{
		super.render();
	
		// Temporary
		if(selected && buildTarget != mapPos)
		{
			glLineWidth(2);
			renderer.setRenderState(RenderState.DepthTest, false);
			
			renderer.drawLine(realPos + vec3(buildingInfo.dimension.x / 2,
			                                 buildingInfo.dimension.y / 2, 0),
			                  terrain.getWorldPos(buildTarget),
			                  vec3(1, 1, 1));
			
			renderer.setRenderState(RenderState.DepthTest, true);
			glLineWidth(1);
		}
	}
	
	override void update()
	{
		super.update();
	
		if(localFogOfWarState == FogOfWarState.Visible && buildSteps > 0)
		{
			_sceneNode.scaling = vec3
			(
				typeInfo.scale.x,
				typeInfo.scale.y * cast(double)buildSteps /
					buildingInfo.buildSteps,
				typeInfo.scale.z
			);
		}
	}
	
	override void simulate()
	{
		super.simulate();

		if(!queue.empty)
		{
			auto entry = queue.first;
			
			assert(entry.progress > fixed(0));

			entry.progress -= property(Property.BuildSpeed);
			
			if(entry.progress <= fixed(0))
			{
				switch(entry.type)
				{
				case QueueEntry.Type.Unit:
					auto unitPos = searchFreeTileAround();

					gateway.checkSync(__FILE__, __LINE__, id);
					gateway.checkSync(__FILE__, __LINE__, unitPos.x);
					gateway.checkSync(__FILE__, __LINE__, unitPos.y);

					if(unitPos == mapPos)
					{
						debug(gameobjects)
							logger.spam("no free place around me, retrying later");
						
						// no space to spawn unit, retry later
						entry.progress = fixed.fromInt(entry.typeInfo.devSteps);
						return;
					}

					debug(gameobjects)
						logger.spam("building a {}", entry.typeInfo.id);
					
					auto obj = objCast!(Unit)(gameObjects.localCreate(
						owner, entry.typeInfo.id, unitPos.x, unitPos.y));
					
					if(buildTarget != mapPos)
						obj.localMove(buildTarget);
					
					break;
					
				case QueueEntry.Type.Tech:
					auto typeInfo = objCast!(Technology)(entry.typeInfo);
				
					debug(gameobjects)
						logger.spam("developing {}", entry.typeInfo.id);
				
					if(!typeInfo.developed)
						typeInfo.develop();
					
					break;
					
				default:
					assert(false);
				}
				
				queue.detach(entry);
				delete entry;
			}
		}
	}
}
