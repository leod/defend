module defend.sim.obj.Citizen;

import xf.hybrid.Hybrid;
import xf.hybrid.widgets.Button;

import xf.xpose2.Expose;
import xf.xpose2.Serialization;

import engine.util.Lang;
import engine.util.Cast;
import engine.mem.Memory;
import engine.math.Vector;

import defend.sim.Resource;
import defend.sim.Player;
import defend.sim.Core;
import defend.sim.IHud;
import defend.sim.Effector;
import defend.sim.obj.Unit;
import defend.sim.obj.Resource;
import defend.sim.obj.Building;

//debug = citizen;

static this()
{
	typeRegister.addLoader("citizen", (CitizenTypeInfo ti)
	{
		with(ti)
		{
			// TODO: change citizen model and mini pic
			moveSound = "sheep.ogg";
			selectSound = "sheep.ogg";
			model = "sheep/low.obj";
			miniPic = "minipics/sheep.png";
			parentType = "unit";
			posOffset = vec3(0, 1, 0);
			scale = vec3.one;
			devSteps = 50;
			canBuild = [ "house" ];
			properties[GameObject.Property.MaxLife]  = prop_t(300);
			properties[Unit.Property.Attack]         = prop_t(10);
			properties[Unit.Property.MovementSpeed]  = prop_t(50);
			properties[Unit.Property.AttackSpeed]    = prop_t(250);
			properties[Citizen.Property.RepairSpeed] = prop_t(10);
			properties[GameObject.Property.Sight]    = prop_t(15);
			cost[ResourceType.Iron] = 50;
			cost[ResourceType.Gold] = 50;
		}
	});
}

class CitizenTypeInfo : UnitTypeInfo
{
	mixin(xpose2(""));
	mixin xposeSerialization;

	object_type_t[] canBuild;
	
	OrderError checkObjectRightClickOrder(GameObject[] objects, OrderObjectRightClick* order)
	{
		bool targetExists;
		auto target = gameObjects.getObject(order.target, targetExists);
	
		if(!targetExists)
			return OrderError.TargetDoesNotExist;
	
		if(target.typeInfo.objectClass == ObjectClass.Building &&
		   target.owner == objects[0].owner)
		{
			if(target.status == Building.Status.BuildUp ||
			   (target.status == Building.Status.Finished &&
			    target.life < target.property(GameObject.Property.MaxLife)))
				return OrderError.Okay;
		}
		else if(target.typeInfo.objectClass == ObjectClass.Resource &&
		        target.owner == NEUTRAL_PLAYER)
		{
			return OrderError.Okay;
		}
			
		return OrderError.Ignored;
	}
	
	void onObjectRightClickOrder(GameObject[] objects, OrderObjectRightClick* order)
	in
	{
		assertSameOwner(objects);
	}
	body
	{
		// Get the target object
		auto target = gameObjects.getObject(order.target);
		assert(target !is null);
		assert(target.id == order.target);
		
		if(target.owner == objects[0].owner &&
		   target.typeInfo.objectClass == ObjectClass.Building)
		{
			if(target.status == Building.Status.BuildUp)
			{
				// Building buildings
				iterateObjects(objects, (Citizen object)
				{
					object.build(objCast!(Building)(target));
				});
			}
			else if(target.status == Building.Status.Finished &&
			        target.life < target.property(GameObject.Property.MaxLife))
			{
				// Repairing buildings
				iterateObjects(objects, (Citizen object)
				{
					object.repair(objCast!(Building)(target));
				});
			}
		}
		else if(target.owner == NEUTRAL_PLAYER &&
		        target.typeInfo.objectClass == ObjectClass.Resource)
		{
			// Mining resources
			iterateObjects(objects, (Citizen object)
			{
				object.mine(objCast!(Resource)(target));
			});
		}
		else assert(false);
	}
	
	OrderError checkPlaceObjectOrder(GameObject[] objects, OrderPlaceObject* order)
	{
		auto ti = objCast!(BuildingTypeInfo)(
			gameObjects.getTypeInfo(owner, order.objectType));
		
		if(!gameObjects.players[objects[0].owner].canBuy(ti.cost))
			return OrderError.TooExpensive;
		
		return ti.isPlaceable(map_pos_t(order.x, order.y)) ?
			OrderError.Okay : OrderError.Error;
	}
	
	void onPlaceObjectOrder(GameObject[] objects, OrderPlaceObject* order)
	in
	{
		assertSameOwner(objects);
	}
	body
	{
		auto owner = objects[0].owner;
		
		gameObjects.players[objects[0].owner].buy(
			objCast!(BuildingTypeInfo)(
				gameObjects.getTypeInfo(owner, order.objectType)).cost);
		
		auto building = cast(Building)gameObjects.localCreate(owner, order.objectType,
		                                                      order.x, order.y);
		
		assert(building !is null, "citizens can only build buildings currently");
		
		building.initialStatus = Building.Status.BuildUp;
		
		iterateObjects(objects, (Citizen object)
		{
			object.build(building);
		});
	}

	override void setDeps()
	{
		super.setDeps();
		
		addDeps(canBuild);
	}
	
	override void construct()
	{
		super.construct();

		addOrderCallback("citizen", &checkObjectRightClickOrder,
			null, &onObjectRightClickOrder);
			
		addOrderCallback("citizen", &checkPlaceObjectOrder,
			null, &onPlaceObjectOrder);
			
		allocateObject = function GameObject() { return new Citizen; };
		freeObject = function void(GameObject object) { delete object; };
	}

	override void doLeftHud(IHud hud, GameObject[] selection)
	{
		foreach(i, type; canBuild)
		{
			auto ti = gameObjects.getTypeInfo(owner, type);
			
			if(Button(i).text(Lang.get("general", "build", Lang.Lookup(ti.id))).clicked)
			{
				hud.startPlaceObject(type);
			}
		}
	}
}

class Citizen : Unit
{
protected:
	void build(Building building)
	{
		debug(gameobjects)
			logger.trace("starting to build {} (a `{}')",
				building.id, building.typeInfo.id);
	
		follow(building, &buildingReached);
	}
	
	void repair(Building building)
	{
		debug(gameobjects)
			logger.trace("repairing {} (a `{}')",
				building.id, building.typeInfo.id);
				
		follow(building, &repairTargetReached);
	}
	
	void mine(Resource resource)
	{
		debug(gameobjects)
			logger.trace("mining {} (a `{}')",
				resource.id, resource.typeInfo.id);
			
		follow(resource, &resourceReached);
	}

	override void delegate() readFollowCallback(char[] s)
	{
		if(s == "build")
			return &buildingReached;
		else if(s == "repair")
			return &repairTargetReached;
		else if(s == "resource")
			return &resourceReached;
		
		return super.readFollowCallback(s);
	}
	
	override char[] writeFollowCallback()
	{
		if(followCallback == &buildingReached)
			return "build";
		else if(followCallback == &repairTargetReached)
			return "repair";
		else if(followCallback == &resourceReached)
			return "resource";
		
		return super.writeFollowCallback();
	}
	
	void buildingReached()
	{
		status = Status.Building;
	}
	
	void repairTargetReached()
	{
		status = Status.Repairing;
	}
	
	void resourceReached()
	{
		status = Status.Mining;
	}

public:
	mixin MAllocator;
	
	mixin(xpose2(""));
	//const char[] target = "Citizen";
	mixin xposeSerialization;

	enum Status : object_status_t
	{
		// Building a building
		Building = Unit.Status.max + 1,
		
		// Mining
		Mining,
		
		// Repairing
		Repairing
	}
	
	enum Property : prop_type_t
	{
		// Speed for building buildings
		BuildSpeed = GameObject.Property.max + 1,
		
		// Speed for repairing buildings
		RepairSpeed,
	}

	override void simulate()
	{
		super.simulate();
		
		switch(status)
		{
		case Status.Building:
			if(!followObject) // Happens when the target building gets destroyed
				status = Unit.Status.Idle;
			else
			{
				auto building = objCast!(Building)(followObject);
				
				if(building.status != Building.Status.BuildUp)
				{
					debug(gameobjects)
						logger.trace("building is finished, stopping to build");
					
					status = Unit.Status.Idle;
					stopFollow();
				}
				else
				{
					if(!isStandingNearby(building))
					{
						debug(gameobjects)
							logger.warn("trying to build while not standing nearby a building");
						
						status = Unit.Status.Idle;
					}
					else
					{
						building.oneBuildStep();
						
						if(building.status == Building.Status.Finished)
						{
							status = Unit.Status.Idle;
							stopFollow();
						}
					}
				}
			}
			
			break;
		
		case Status.Repairing:
			if(!followObject) // Happens when the target building gets destroyed
				status = Unit.Status.Idle;
			else
			{
				auto building = objCast!(Building)(followObject);
		
				if(!isStandingNearby(building))
				{
					debug(gameobjects)
						logger.warn("trying to repair while not standing nearby a building");
					
					status = Unit.Status.Idle;
				}
				else
				{
					building.life = building.life + property(Property.BuildSpeed);
					
					if(building.life == building.property(GameObject.Property.MaxLife))
					{					
						status = Unit.Status.Idle;
						stopFollow();
					}
				}
			}
			
			break;			
		
		case Status.Mining:
			if(!followObject) // Very unlikely to happen, but you never know...
				status = Unit.Status.Idle;
			else
			{
				auto resource = objCast!(Resource)(followObject);
				
				if(resource.whacked)
				{
					debug(gameobjects)
						logger.trace("resource is whacked, stopping to mine it");
						
					status = Unit.Status.Idle;
					stopFollow();
				}
				else
				{
					assert(isStandingNearby(resource));
					
					auto amount = resource.leech(); // damn these leechers :F
					auto type = objCast!(ResourceTypeInfo)(resource.typeInfo).resourceType;
					
					gameObjects.players[owner].addResource(type, amount);
				}
			}
			
		default:
			break;
			
		}
	}
}
