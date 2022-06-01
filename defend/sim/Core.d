module defend.sim.Core;

import tango.core.Traits;
import tango.io.Console;
import tango.math.random.Random;
import tango.math.Math;
import tango.util.container.HashMap;
import tango.text.Util;
import Integer = tango.text.convert.Integer;

import xf.xpose2.Expose;
import xf.xpose2.Serialization;

import engine.math.BoundingBox;
import engine.scene.Graph;
import engine.scene.Node;
import engine.list.Queue;
import engine.list.BufferedArray;
import engine.util.Log : Log, Logger, LogLevel, MLogger;
import engine.util.Singleton;
import engine.util.Serialize;
import engine.util.Signal;
import engine.mem.Memory;
import engine.util.Signal;
import engine.util.Profiler;
import engine.util.Cast;
import engine.util.Lang;

public
{
	import engine.math.Vector;
	import engine.math.Ray;
	import engine.math.Rectangle;
}

import defend.Config;
import defend.terrain.ITerrain;
import defend.sim.Map;
import defend.sim.IFogOfWar;
import defend.sim.IHud;
import defend.sim.SceneNode;
import defend.sim.Runner;
import defend.sim.Player;
import defend.sim.Round;
import defend.sim.Resource;
import defend.sim.Gateway;
import defend.sim.Serialization;

public
{
	import defend.sim.GameInfo;
	import defend.sim.Types;
	import defend.sim.Effector;
}

// Logging level of objects
//const objectsLoggerLevel = LogLevel.Spam;
//const objectsLoggerLevel = LogLevel.Trace;
const objectsLoggerLevel = LogLevel.Info;

// -----------------------------------------------------------------------
//{ Orders
alias ubyte order_type_t;

enum OrderError
{
	// This order is valid
	Okay,
	
	// Object does not response to this order
	Ignored,
	
	// General error
	Error,
	
	// Don't have enough resources
	TooExpensive,
	
	// The target object doesn't exist
	TargetDoesNotExist
}

// for generating order IDs in MOrder
order_type_t orderTypeCounter;

alias ArrayReader OrderStreamType;

template MOrder(T)
{
	import engine.util.Serialize;

	static order_type_t type;
	
	static void unserializer(OrderStreamType stream,
		void delegate(void*) callback)
	{
		T order = unserialize!(T)(stream);
		
		callback(cast(void*)&order);
	}

	static this()
	{
		type = orderTypeCounter++;
		GameObjectManager.addOrderUnserializer(type, &unserializer);
	}
}

align(1)
{

struct OrderMapRightClick
{
	mixin MOrder!(OrderMapRightClick);

	map_index_t x;
	map_index_t y;

	static OrderMapRightClick opCall(map_index_t x, map_index_t y)
	{
		OrderMapRightClick result;
		result.x = x;
		result.y = y;

		return result;
	}
}

struct OrderObjectRightClick
{
	mixin MOrder!(OrderObjectRightClick);

	object_id_t target;

	static OrderObjectRightClick opCall(object_id_t target)
	{
		OrderObjectRightClick result;
		result.target = target;

		return result;
	}
}

struct OrderRemove
{
	mixin MOrder!(OrderRemove);

	static OrderRemove opCall()
	{
		OrderRemove result;

		return result;
	}
}

struct OrderPlaceObject
{
	mixin MOrder!(OrderPlaceObject);

	object_type_t objectType;
	map_index_t x;
	map_index_t y;

	static OrderPlaceObject opCall(object_type_t objectType,
	                               map_index_t x, map_index_t y)
	{
		OrderPlaceObject result;

		result.objectType = objectType;
		result.x = x;
		result.y = y;

		return result;
	}
}

}
//}
//------------------------------------------------------------------------
//{ Base for types in the simulation
abstract class TypeBase
{
private:
	type_id_t _id;
	type_id_t[] _deps;
	
	static void readID(TypeBase t, Unserializer u)
	{
		u(t._id);
		
		typeRegister.getInitializer(t._id)(t);
	}
	
	static void writeID(TypeBase t, Serializer s)
	{
		s(t._id);
	}
	
protected:
	final void addDep(type_id_t dep)
	{
		_deps ~= dep;
	}
	
	final void addDeps(type_id_t[] deps)
	{
		foreach(dep; deps)
			addDep(dep);
	}
	
	// override me
	void setDeps() {}
	
public:
	mixin(xpose2(`
		_id serial { read "readID"; write "writeID" }
		_deps
		owner
		cost
		devSteps
		gameObjects
	`));
	mixin xposeSerialization;

	GameObjectManager gameObjects;
	player_id_t owner;

	typedef uint local_id_t;
	local_id_t localTypeID;

	// Optional properties
	ResourceArray cost; // cost for building/developing/whatever this type
	uint devSteps; // time needed for doing that
	char[] miniPic; // icon
	
	final type_id_t id()
	{
		return _id;
	}
	
	final void id(type_id_t t)
	{
		_id = t;
	}
	
	final type_id_t[] deps()
	{
		return _deps;
	}
	
	final char[] name()
	{
		return id;
	}
	
	debug bool wasConstructed = false;
	
	// override me
	void construct() { debug wasConstructed = true; } // construct . destruct === id
	void destruct() { assert(wasConstructed); debug wasConstructed = false; }
	void simulate() { assert(wasConstructed); }
}
//}
//------------------------------------------------------------------------
//{ Civilisation
final class CivTypeInfo
{
	char[] name;
	type_id_t[] types;
	void delegate(Civ) create;
	
	this(char[] name, type_id_t[] types, void delegate(Civ) create)
	{
		this.name = name;
		this.types = types;
		this.create = create;
	}
}

// instantiated for each player
final class Civ
{
	player_id_t owner;
	
	CivTypeInfo typeInfo;
	TypeBase[type_id_t] types;
	
	private
	{
		static void readTypeInfo(Civ c, Unserializer u)
		{
			char[] name;
			u(name);
			
			c.typeInfo = typeRegister.getCivType(name);
		}
		
		static void writeTypeInfo(Civ c, Serializer s)
		{
			s(c.typeInfo.name);
		}
	}
	
	mixin(xpose2(`
		owner
		typeInfo serial { read "readTypeInfo"; write "writeTypeInfo" }
		types
	`));
	mixin xposeSerialization;
	
	void release()
	{
		foreach(ti; types)
		{
			ti.destruct();
			
			delete ti;
		}
	}
	
	void onUnserialized()
	{
		typeRegister.setupCiv(this);
	}
}
//}
//------------------------------------------------------------------------
//{ Object type info
class ObjectTypeInfo : TypeBase, Effected
{
protected:
	const Logger logger_;

	// Iterate through a list of objects
	final void iterateObjects(T)(GameObject[] objects,
		void delegate(T) dg)
	{
		foreach(o; objects)
		{
			auto object = objCast!(T)(o);

			dg(object);
		}
	}

	// Properties
	prop_t[MAX_OBJECT_PROPERTIES] propertyFactors;

	// Effectors
	EffectorInfo[MAX_OBJECT_TYPE_EFFECTORS] effectors;

	ObjectTypeInfo parentPointer = null;

	// Check that all objects have the same owner
	final void assertSameOwner(GameObject[] objects)
	{
		assert(objects.length > 0);
		auto owner = objects[0].owner;
		
		iterateObjects(objects, (GameObject object)
		{
			assert(object.owner == owner);
		});
	}
	
	// Orders
	struct OrderInfo
	{
		bool isset;
		
		OrderError delegate(GameObject[], void*) check;
		void delegate(GameObject[], void*) local;
		void delegate(GameObject[], void*) on;
	}
	
	OrderInfo[] orderCallbacks;
	
	object_type_t[] tempOrders;
	local_id_t[] orders;
	
	// should be called in the typeinfo construct method
	void addOrderCallback(A, B, C)(object_type_t type, A check, B local, C on)
	{
		alias ParameterTupleOf!(A)[1] T;
		
		static assert(is(A == OrderError delegate(GameObject[], T)));
		static assert(is(B == void delegate(GameObject[], T)) ||
			is(B == void*) /* because local is optional and a 'null' can be passed */);
		static assert(is(C == void delegate(GameObject[], T)), C.stringof);
	
		assert(check);
		static if(!is(B == void*)) assert(local);
		assert(on);
	
		if(orderCallbacks.length <= T.type)
			orderCallbacks.length = T.type + 1;
			
		orderCallbacks[T.type].isset = true;
		orderCallbacks[T.type].check = cast(typeof((new OrderInfo).check))check;
		
		static if(!is(B == void*))
			orderCallbacks[T.type].local = cast(typeof((new OrderInfo).local))local;
			
		orderCallbacks[T.type].on = cast(typeof((new OrderInfo).on))on;
		
		if(tempOrders.length <= T.type)
		{
			tempOrders.length = T.type + 1;
			orders.length = tempOrders.length;
		}
		
		tempOrders[T.type] = type;
	}
	
	bool handlesOrder(order_type_t type)
	{
		return type < orderCallbacks.length && orderCallbacks[type].isset;
	}

	OrderError checkOrder(GameObject[] objects, order_type_t type, void* order)
	{
		assert(handlesOrder(type));
		
		auto dg = orderCallbacks[type].check;
		assert(dg);
		
		return dg(objects, order);
	}
	
	void localOrder(GameObject[] objects, order_type_t type, void* order)
	{
		assert(handlesOrder(type));
		
		auto dg = orderCallbacks[type].local;
		if(dg) dg(objects, order);
	}
		
	void onOrder(GameObject[] objects, order_type_t type, void* order)
	{
		assert(handlesOrder(type));
		
		auto dg = orderCallbacks[type].on;
		assert(dg);
		
		dg(objects, order);
	}
	
	// Contract for object class check
	final void assertObjectClass(GameObject[] objects, ObjectClass whatClass)
	{
		iterateObjects(objects, (GameObject object)
		{
			assert(object.typeInfo.objectClass == whatClass);
		});
	}
	
	// Basic orders
	OrderError checkRemoveOrder(GameObject[] objects, OrderRemove* order)
	{
		return OrderError.Okay;
	}
	
	void onRemoveOrder(GameObject[] objects, OrderRemove* order)
	{
		iterateObjects(objects, (GameObject object)
		{
			assert(!object.removed, "object already is removed");
		
			gameObjects.localRemove(object.id);
		});
	}
	
	Map map() { return gameObjects.map; }

public:
	mixin MAllocator;
	
	mixin(xpose2("
		propertyFactors
		effectors
		available
	"));
	mixin xposeSerialization;

	bool available = true;
	bool abstractType = false;

	// Model info
	char[] model;
	vec3 posOffset = vec3.zero;
	vec3 scale = vec3.zero;
	vec3 normRotation = vec3.zero;

	// Sound which gets played when the object gets selected by the user
	char[] selectSound;

	// Shall this kind of object by 'cached' in the fog of war?
	bool fogOfWarCache;
	
	// Shall this kind of object by placeable in the editor?
	bool editorPlaceable = true;
	
	// Is this kind of object usually owned by the neutral player?
	bool isNeutral;

	// Basic properties
	prop_t[MAX_OBJECT_PROPERTIES] properties;

	// Number of tiles occupied
	vec2i dimension;

	// Allocate an object of this type
	GameObject function() allocateObject;
	
	GameObject allocate()
	{
		assert(allocateObject !is null);
		return allocateObject();
	}
	
	// Free an object of this type
	void function(GameObject) freeObject;
	
	void free(GameObject object)
	{
		assert(freeObject !is null);
		freeObject(object);
	}

	object_type_t parentType;
	ObjectClass objectClass;

	// Constructor
	this()
	{
		logger_ = Log["sim.typeinfo." ~ this.classinfo.name.split(".")[$ - 1]];

		foreach(ref pf; propertyFactors)
			pf = prop_t.ctFromReal!(1.0);

		foreach(ref pf; properties)
			pf = prop_t.ctFromReal!(1.0);
			
		foreach(ref order; tempOrders)
			order = "base";
			
		dimension = vec2i(1, 1);
	}

	// returns if this object can be placed at a certain place on the map
	bool isPlaceable(map_pos_t pos)
	{
		if(pos.x + dimension.x >= map.size.x ||
		   pos.y + dimension.y >= map.size.y)
			return false;

		// TODO: fixed point
		float height = -1;
		const float tolerance = 0.2;

		for(auto x = pos.x; x < pos.x + dimension.x; x++)
		{
			for(auto y = pos.y; y < pos.y + dimension.y; y++)
			{
				auto tileHeight = map.heightmap[x, y];
			
				if(height == -1)
					height = tileHeight;
				else
				{
					if(abs(tileHeight - height) > tolerance)
						return false;
				}
				
				if(!map[x, y].free)
					return false;
			}
		}

		return true;
	}

	final ObjectTypeInfo parent()
	{
		if(objectClass == ObjectClass.Base)
			return null;
	
		if(parentPointer is null)
			parentPointer = gameObjects.getTypeInfo(owner, parentType);

		return parentPointer;
	}

	final ObjectTypeInfo hasParent(local_id_t type)
	{
		if(objectClass == ObjectClass.Base)
			return null;

		auto ti = this;

		do
		{
			ti = ti.parent;
			
			if(ti.localTypeID == type)
				return ti;
		} while(ti.objectClass != ObjectClass.Base);
		
		return null;
	}

	final bool isTypeInHierarchy(local_id_t type)
	{
		return localTypeID == type || hasParent(type) !is null;
	}

	override void construct()
	{
		super.construct();
	
		addOrderCallback("base", &checkRemoveOrder,
			null, &onRemoveOrder);
	}

	void doLeftHud(IHud hud, GameObject[] selection) {}
	void doMiddleHud(IHud hud, GameObject[] selection) {}

	// Set a property
	override void scalePropFactor(prop_type_t property, prop_t value)
	{
		propertyFactors[property] *= value;
	}

	// Returns a property factor
	prop_t getPropertyFactor(prop_type_t property)
	{
		return (parent !is null ?
		        parent.getPropertyFactor(property) : prop_t.ctFromReal!(1.0)) *
		        propertyFactors[property];
	}

	// Returns the value of a property
	prop_t getProperty(prop_type_t property)
	{
		return properties[property] * getPropertyFactor(property);
	}

	// Apply an effector
	void applyEffector(Effector effector)
	{
		effector.attach(this);

		if(effector.lifetime == 0)
			return;

		foreach(ref element; effectors)
		{
			if(element.effector)
				continue;

			element.whenApplied = gameObjects.step;
			element.effector = effector;
			break;
		}
	}

	// Set dependencies
	override void setDeps()
	{
		super.setDeps();
		
		if(parentType != "")
			addDep(parentType);
	}

	// SimulationRunner step
	override void simulate()
	{
		foreach(ref element; effectors) with(element)
		{
			if(effector !is null &&
			   effector.lifetime != 0 &&
			   gameObjects.step - whenApplied == effector.lifetime)
			{
				effector.detach(this);
				effector = null;
			}
		}
	}
	
	// Create a scene node
	GameObjectModel createSceneNode(vec3 pos, vec3 color, ITerrain terrain = null)
	{
		//bool isNeutral = owner == NEUTRAL_PLAYER; // that ok? 
	
		return new GameObjectModel
		(
			sceneGraph.root,
			terrain ? terrain : gameObjects.terrain,
			model,
			color,
			isNeutral,
			pos + posOffset,
			scale,
			normRotation
		);
	}
	
	GameObjectModel createSceneNode(vec3 pos, ITerrain terrain = null)
	{
		//bool isNeutral = owner == NEUTRAL_PLAYER; // that ok? 
	
		auto color = isNeutral ? vec3.one :
			playerColors[gameObjects.players[owner].info.color];
	
		return createSceneNode(pos, color, terrain);
	}
}

// Typedef for the objects' state variable
alias int object_status_t;

// Maximal number of effectors which an object can have
const MAX_OBJECT_EFFECTORS = 8;
//}
//------------------------------------------------------------------------
//{ Game object base
abstract class GameObject : Effected
{
private:
	// Current status
	object_status_t _status = Status.Undefined;
	
	// Tile position on the map
	map_pos_t _mapPos;
	
	// The object's ID
	object_id_t _id;
	
	// The owner
	player_id_t _owner;

	// Set to true when onRemove was called
	bool removed = false;

	// The object's type info, stores general informations about the type
	ObjectTypeInfo _typeInfo;

	// Factors (multipliers) for this object's properties
	prop_t[MAX_OBJECT_PROPERTIES] propertyFactors;

	// Effectors can change an object's property factors
	EffectorInfo[MAX_OBJECT_EFFECTORS] effectors;
	
	// This object's life
	fixed _life;
	
	// The real position, in 3D space (only for rendering etc - not related to the simulation)
	vec3 _realPos;
	
	// Object selected by the player?
	bool _selected;
	
	debug
	{
		bool cleanUpCalled = false;
	}
	
	void createLogger()
	{
		debug(gameobjects)
		{
			logger_ = Log["sim.object." ~ Integer.toString(id)];
			logger_.level = objectsLoggerLevel;
		}
	}

public:
	mixin(xpose2("
		_status
		_mapPos
		_id
		_owner
		_typeInfo
		propertyFactors
		effectors
		_life
		gameObjects
		fogOfWarState
	"));
	mixin xposeSerialization;
	
	void onUnserialized()
	{
		createLogger();
		initRealPos();
		createSceneNode();
	}

protected:
	// Shortcuts
	ITerrain terrain() { return gameObjects.terrain; }
	Map map() { return gameObjects.map; }
	IFogOfWar fogOfWar() { return gameObjects.players[owner].fogOfWar; }
	IFogOfWar localFogOfWar() { return gameObjects.localFogOfWar; }

	// Set a new map position
	void mapPos(map_pos_t v)
	{
		_mapPos = v;
	}
	
	// Change the 3D position
	vec3 realPos(vec3 v)
	{
		return _realPos = v;
	}

	// Multiplayer communication
	Gateway gateway;
	
	// Object manager
	GameObjectManager gameObjects;
	
	// The scene node for rendering
	GameObjectModel _sceneNode;
	
	// Will this object be removed after this simulation step?
	bool willBeRemoved = false;
	
	// Logging
	debug(gameobjects)
	{
		mixin MLogger;
	}
	
	// Sets the walkable state of all tiles which are occupied by this object
	void markMap(bool status)
	{
		assert(typeInfo !is null);
		assert(mapPos.x + typeInfo.dimension.x < map.size.x);
		assert(mapPos.y + typeInfo.dimension.y < map.size.y);
		
		for(auto x = mapPos.x; x < mapPos.x + typeInfo.dimension.x; x++)
		{
			for(auto y = mapPos.y; y < mapPos.y + typeInfo.dimension.y; y++)
			{
				assert(map[x, y].walkable == !status);
				map[x, y].walkable = status;
			}
		}
	}

	// May be overriden
	void initRealPos()
	{
		realPos = terrain.getWorldPos(mapPos);
	}
	
	void createSceneNode()
	{
		_sceneNode = typeInfo.createSceneNode(realPos);
	}
	
	// Remove ourself
	void selfRemove()
	{
		if(willBeRemoved)
		{
			debug(gameobjects)
				logger_.warn("already was removed");
			
			return;
		}
	
		debug(gameobjects)
		{
			logger_.trace("removing myself");
		}
		
		gameObjects.localRemove(id);
	}
	
	// Change the status
	void status(object_status_t s)
	{
		_status = s;
	}

public:
	mixin MAllocator;

	// Tell the object that it shall not delete its scene node, because it is still needed
	bool keepSceneNode = false;

	// Fog of war properties
	FogOfWarState[MAX_PLAYERS] fogOfWarState;
	
	FogOfWarState localFogOfWarState()
	{
		return fogOfWarState[gateway.id];
	}

	// For selection
	vec2i screenPos;
	vec2i[8] screenPos_;
	Rectangle!(int) screenRect;

	~this()
	{
		debug
		{
			assert(cleanUpCalled, "cleanUp was not called");
		}
	}

	enum Status : object_status_t
	{
		Undefined,
		Dead
	}
	
	enum Property : prop_type_t
	{
		MaxLife,
		Sight
	}
	
	object_status_t status() { return _status; }
	bool dead() { return status == Status.Dead; }

	// Gets called for each object whenever another object dies
	void onObjectDead(GameObject which) {}
	
	final object_id_t id() { return _id; }
	final player_id_t owner() { return _owner; }
	ObjectTypeInfo typeInfo() { return _typeInfo; }
	final bool selected() { return _selected; }
	final void selected(bool b) { _selected = b; }
	final vec3 realPos() { return _realPos; }
	final vec2us mapPos() { return _mapPos; }
	fixed life() { return _life; }
	
	fixed life(fixed i)
	{
		_life = i;
		
		if(_life <= fixed(0))
		{
			_life = fixed(0);
		
			status = Status.Dead;
			selfRemove();
		}
		else if(_life > property(Property.MaxLife))
		{
			_life = property(Property.MaxLife);
		}
		
		return _life;
	}
	
	int distance(GameObject object)
	{
		return abs(cast(int)object.mapPos.x - cast(int)mapPos.x) + 
			abs(cast(int)object.mapPos.y - cast(int)mapPos.y);
	}
	
	void hurt(fixed f)
	{
		life = life - min(life, f);
	}
	
	override void scalePropFactor(prop_type_t property, prop_t value)
	{
		propertyFactors[property] *= value;
	}
	
	void setPropFactor(prop_type_t property, prop_t value)
	{
		propertyFactors[property] = value;
	}
	
	prop_t property(prop_type_t property)
	{
		assert(property < MAX_OBJECT_PROPERTIES);
		
		return propertyFactors[property] * typeInfo.getProperty(property);
	}

	bool applyEffector(Effector effector)
	{
		foreach(element; effectors)
		{
			if(element.effector is null)
			{
				element.whenApplied = gameObjects.currentSimulationStep();
				element.effector = effector;
				
				return true;
			}
		}

		// no free slot was found; this object already has max effectors
		return false;
	}
	
	// returns this object's mapPos if no free tile was found
	final map_pos_t searchFreeTileAround(map_pos_t from)
	{
		// TODO: fixed point
		float minDistance = float.max;
		map_pos_t result = mapPos;

		foreach(x, y; mapRectangle(1))
		{
			if(!map[x, y].free)
				continue;
			
			map_pos_t pos = map_pos_t(x, y);
			
			auto distance = pos.distance(from);
			
			if(distance < minDistance)
			{
				minDistance = distance;
				result = pos;
			}
		}
		
		return result;
	}
	
	final map_pos_t searchFreeTileAround()
	{
		return searchFreeTileAround(mapPos);
	}

	final Rectangle!(map_index_t) mapRectangle(uint radius = 0)
	out(result)
	{
		assert(result.left >= 0);
		assert(result.top >= 0);
		assert(result.right < map.size.x);
		assert(result.bottom < map.size.y);
	}
	body
	{
		return Rectangle!(map_index_t)(
				mapPos.x >= radius ? mapPos.x - radius : 0,
				mapPos.y >= radius ? mapPos.y - radius : 0,
						
				mapPos.x + typeInfo.dimension.x + radius < map.size.x ?
						mapPos.x + typeInfo.dimension.x + radius :
						mapPos.x + typeInfo.dimension.x,

				mapPos.y + typeInfo.dimension.y + radius < map.size.y ?
						mapPos.y + typeInfo.dimension.y + radius :
						mapPos.y + typeInfo.dimension.y);
	}

	// Returns if this object is standing nearby another object
	bool isStandingNearby(GameObject other)
	{
		return mapRectangle.collides(other.mapRectangle);
	}

	// Release all resources being used by this object
	void cleanUp()
	{
		debug
		{
			assert(!cleanUpCalled);
			cleanUpCalled = true;
		}
		
		if(_sceneNode && !keepSceneNode)
		{
			delete _sceneNode;
		}
	}

	// Called when the object is removed
	void onRemove()
	{
		assert(!removed);
		removed = true;
	}

	/* Update. This should only be used for things like interpolation and
	   should not change any variables which are related to the simulation. */
	void update()
	{
		if(_sceneNode)
			_sceneNode.fogOfWarCulled = localFogOfWar.enabled &&
				(localFogOfWarState == FogOfWarState.Culled ||
				 (localFogOfWarState == FogOfWarState.Cached && !typeInfo.fogOfWarCache));
	}
	
	// Render (for debugging, actually anything should be rendered through the scene graph)
	void render() {}
	
	// SimulationRunner step, simulation state may be changed here
	void simulate()
	{
		if(removed)
		{
			debug(gameobjects)
				logger_.warn("simulate() called after removal");
			
			return;
		}
	
		// Check if effectors are finished and may be removed
		foreach(element; effectors)
		{
			if(element.effector !is null && element.effector.lifetime != 0 &&
			   gameObjects.currentSimulationStep() - element.whenApplied == 0)
			{
				element.effector.detach(this);
				element.effector = null;
			}
		}
	}
	
	// Returns if this object can be ordered by the *local* player
	bool mayBeOrdered()
	{
		return owner == gateway.id;
	}
	
	bool isAlwaysVisibleTo(player_id_t player)
	{
		return player == owner; // TODO: teams
	}
	
	// Test intersection with an ray
	bool intersectRay(Ray!(float) ray)
	{
		if(_sceneNode)
			return ray.intersectBoundingBox(_sceneNode.boundingBox);
			
		assert(false);
	}
	
	// Returns if this object is visible for the main camera
	bool visible()
	{
		if(_sceneNode)
			return _sceneNode.visible;
			
		assert(false, "no scene node: " ~ this.classinfo.name);
	}

	vec3 center()
	{
		if(_sceneNode)
			return (_sceneNode.boundingBox.min + _sceneNode.boundingBox.max) * 0.5f;
			
		assert(false);
	}
	
	SceneNode sceneNode()
	{
		if(_sceneNode)
			return _sceneNode;
			
		assert(false);
	}
	
	BoundingBox!(float) boundingBox()
	{
		if(_sceneNode)
			return _sceneNode.boundingBox;
			
		assert(false);
	}
	
	// Called when the object has been created
	void onCreate()
	{
		assert(typeInfo.owner == owner);
		
		foreach(ref pf; propertyFactors)
			pf = prop_t.ctFromReal!(1.0);

		if(owner != NEUTRAL_PLAYER)
		{
			if(isAlwaysVisibleTo(owner))
				fogOfWarState[owner] = FogOfWarState.Visible;
			else
				fogOfWarState[owner] = FogOfWarState.Culled;
		}
		
		_life = property(Property.MaxLife);

		createLogger();
	}

	// TODO: Optimize lowestCommonType
	static ObjectTypeInfo lowestCommonType(GameObject[] objects)
	in
	{
		assert(objects.length > 0);
		
		foreach(object; objects[1 .. $])
			assert(object.owner == objects[0].owner);
	}
	body
	{
		if(objects.length == 1)
			return objects[0].typeInfo;
		
		GameObject regulator = objects[0];
		ObjectTypeInfo currentLevel = regulator.typeInfo;
		
		outer: while(currentLevel.parent !is null)
		{
			foreach(object; objects[1 .. $])
			{
				ObjectTypeInfo ti = object.typeInfo;

				if(!ti.isTypeInHierarchy(currentLevel.localTypeID))
				{
					currentLevel = currentLevel.parent;
					continue outer;
				}
			}
			
			break;
		}

		return currentLevel;
	}
}

enum ObjectClass : int // string?
{
	Base,
	Unit,
	Building,
	Resource,
	Other
}
//}
//------------------------------------------------------------------------
//{ Game object manager
class GameObjectManager
{
	mixin MLogger;

protected:
	// Current simulation step
	uint _currentSimulationStep;

	// Player list
	PlayerManager _players;

	// The communication gateway
	Gateway _gateway;
	
	// Terrain and co
	ITerrain _terrain;
	Map _map;

	// Simulation runner
	SimulationRunner _runner;

	// The object list
	HashMap!(object_id_t, GameObject) objects;
	
	struct HashMapExport(K, V)
	{
		alias HashMap!(K, V) Type;
		const char[] typename = "HashMap!(" ~ K.stringof ~ "," ~ V.stringof ~ ")";
		//mixin(xpose2(typename, ""));
		mixin xposeSerialization!(typename, "serialize", "unserialize");
		
		static void serialize(Type o, Serializer s)
		{
			s(o.size);
			
			foreach(k, v; o)
			{
				s(k);
				s(v);
			}
		}
		
		static void unserialize(Type o, Unserializer s)
		{
			int size;
			s(size);
			
			//Stdout.formatln("{}", size);
			
			for(int i = 0; i < size; ++i)
			{
				K k;
				s(k);
				
				V v;
				s(v);
				
				o[k] = v;
			}
		}
	}

	this()
	{
	}

	alias HashMapExport!(object_id_t, GameObject) HashMapExport_object_id_t_GameObject;
	
	BufferedArray!(GameObject) objectBuffer;

	// Objects which are to be removed from or appended to the list
	Queue!(GameObject) freeQueue, appendQueue;
	
	// Civs
	Civ neutralCiv;
	Civ[player_id_t] civs;
	
	// Queueing orders
	BufferedArray!(OrderData) orderQueue;
	bool queueOrders = false;
	
	// Random generator for the simulation
	Random _simulationRandom;
	
	// Unserializing orders
	static void function(OrderStreamType, void delegate(void*))[]
		orderUnserializers;
	
	// Slots
	void onStartRound(Round round)
	{
		logger_.spam("starting round {}", round.whichRound);
	
		gateway.checkSync(__FILE__, __LINE__, round.whichRound);
	
		foreach(item; round)
		{
			// 1) write target objects into a buffer
			objectBuffer.reset;
			
			foreach(target; item.targets)
			{
				GameObject object;
				bool found = objects.get(target, object);
				
				if(!found)
				{
					/* 
					 * This does happen if an object gets removed in round x,
					 * but, before round x is executed, is ordered in round x + 1.
					 *
					 * I hope it's safe to ignore it.
					 */
					
					continue;
				}

				// Has the object been removed in this round?
				if(object.removed)
					continue;
				
				assert(object !is null, "object is null");
				
				objectBuffer.append(object);
			}
				
			// 2) apply filters
			// TODO: apply order filters (eg remove order duplicates)
			
			// 3) determine order type, unserialize and call the callbacks
			auto stream = ArrayReader(item.data);
			
			order_type_t type = unserialize!(order_type_t)(stream);

			auto unserializer = orderUnserializers[type];
			assert(unserializer);
			
			unserializer(stream, (void* order)
			{
				// seperate objects by their order callback overrides, and call these
				iterateOrderLevels(objectBuffer.toArray, type, (GameObject[] objects)
				{
					assert(objects[0].typeInfo.handlesOrder(type));
				
					// Validate the order
					auto error = objects[0].typeInfo.checkOrder(objects, type, order);
					
					if(error != OrderError.Okay)
						onInvalidOrder(objects, error);
					else
						objects[0].typeInfo.onOrder(objects, type, order);
				});
			});
		}
	}
	
	void onSimulationStep()
	{
		simulate();
	}
	
	object_id_t objectIdCounter = 0;
	
	object_id_t getFreeObjectID()
	{
		// TODO: Improve the "algorithm" which determines free object ids
		return objectIdCounter++;
	}
	
	// Delegate for appending an object to the object list
	void delegate(GameObject) objectAppender;
	
	void appendObject(GameObject object)
	{
		if(!objects.add(object.id, object))
			assert(false); // object.id was already in the hashmap
	}
	
	void removeObject(GameObject object)
	{
		object.cleanUp();
	
		debug(gameobjects)
			logger_.trace("removing object (type: '{}'; id: {}, owner: {})",
				object.typeInfo.id, object.id, object.owner);

		foreach(obj; objects)
		{
			if(obj is object)
				continue;
		
			obj.onObjectDead(object);
		}

		onRemoveObject(object);

		object.onRemove();
		objects.removeKey(object.id);
		object.typeInfo.free(object);
	}
	
	void createNeutralCiv()
	{
		neutralCiv = typeRegister.loadCiv(this, NEUTRAL_PLAYER, "neutral");
		civs[NEUTRAL_PLAYER] = neutralCiv;
		
		logger_.info("loaded civ for neutral player");
	}
	
package:
	void onGameInfo(GameInfo info) // called by Simulation
	{	
		logger_.trace("got game info");
	
		if(info.useSaveGame)
			return; // civs will get unserialized
	
		createNeutralCiv();
	
		foreach(player; info.players)
		{
			assert(player.exists);
			assert(!(player.id in civs));
			
			civs[player.id] = typeRegister.loadCiv(this, player.id, player.civ);
			
			logger_.info("loaded civ '{}' for player '{}'",
			            civs[player.id].typeInfo.name, player.nick);
		}
	}
	
public:
	mixin MAllocator;

	mixin(xpose2(`
		_currentSimulationStep
		objects
		civs
		objectIdCounter
	`)); // TODO: serialize state of the random generator, if i ever use it
	mixin xposeSerialization;
	
	void onUnserialized()
	{
		foreach(obj; objects)
		{
			obj.gateway = gateway;
			//logger.info("unserialized object: {} (type: {}; owner: {}; may be ordered: {})", obj.id, obj.typeInfo.id, obj.owner, obj.mayBeOrdered);
		}
	}

	// for MOrder
	static void addOrderUnserializer(order_type_t type,
		typeof(orderUnserializers[0]) dg)
	{
		if(orderUnserializers.length <= type)
			orderUnserializers.length = type + 1;
		
		orderUnserializers[type] = dg;
	}

	// TODO: Optimize iterateOrderLevels
	static void iterateOrderLevels(GameObject[] objects,
		order_type_t order, void delegate(GameObject[]) dg)
	{
		
		ObjectTypeInfo.local_id_t[MAX_ORDERED_OBJECTS] todo = void;
		size_t numTodo;

		{
			outer: foreach(object; objects)
			{
				assert(object !is null, "object is null");
				assert(object.typeInfo !is null, "object typeinfo is null");
				
				if(!object.typeInfo.handlesOrder(order))
					continue;
				
				foreach(td; todo[0 .. numTodo])
				{				
					if(object.typeInfo.orders[order] == td)
						continue outer;
				}
				
				todo[numTodo++] = object.typeInfo.orders[order];
			}
		}

		{
			GameObject[MAX_ORDERED_OBJECTS] buffer = void;
		
			foreach(type; todo[0 .. numTodo])
			{
				size_t numObjects;
			
				foreach(object; objects)
				{
					if(!object.typeInfo.handlesOrder(order))
						continue;
				
					if(object.typeInfo.orders[order] == type)
						buffer[numObjects++] = object;
				}
				
				assert(numObjects);
				dg(buffer[0 .. numObjects]);
			}
		}
	}

	// Emitted when a synchronized object has been created
	Signal!(GameObject) onCreateObject;
	
	// Emitted when a synchronized object has been removed
	Signal!(GameObject) onRemoveObject;
	
	// An object has died
	Signal!(GameObject) onObjectDead;
	
	// Order error
	Signal!(GameObject[], OrderError) onInvalidOrder;

	this(Gateway _gateway, PlayerManager _players, SimulationRunner _runner)
	{
		this._gateway = _gateway;
		this._players = _players;
		this._runner = _runner;
		
		objects = new HashMap!(object_id_t, GameObject); // new typeof(objects) doesn't compile
		objectBuffer.create(256, true);
		orderQueue.create(512);
		freeQueue.create(512);
		appendQueue.create(512);

		// Connect signals
		_gateway.onStartRound.connect(&onStartRound);
		//_gateway.onGameInfo.connect(&onGameInfo);
		_runner.onSimulationStep.connect(&onSimulationStep);
		
		objectAppender = &appendObject;
		
		logger_.info("game object manager created");
	}
	
	void setTerrain(ITerrain terrain)
	{
		assert(_terrain is null);
		_terrain = terrain;
	}
	
	void setMap(Map map)
	{
		assert(_map is null);
		_map = map;
	}

	~this()
	{
		// Delete objects
		foreach(object; objects)
		{
			object.cleanUp();
			object.typeInfo.free(object);
		}
		
		// Delete object types and civs
		foreach(civ; civs)
		{
			if(civ is null)
				continue;
			else
				civ.release();
		}
		
		typeRegister.unload();
		
		delete objects;
		objectBuffer.release();
		orderQueue.release();
		appendQueue.release();
		freeQueue.release();
	}

	// Send an order
	void order(T)(Gateway gateway, GameObject[] objects, T order,
		void delegate(OrderError, GameObject[]) errorCallback = null)
	{
		logger_.spam("sending order of type `{}' to {} objects", T.stringof, objects.length);
	
		if(objects.length > MAX_ORDERED_OBJECTS)
		{
			logger_.warn("trying to order {} objects, limit is {}",
			            objects.length, MAX_ORDERED_OBJECTS);
			objects = objects[0 .. MAX_ORDERED_OBJECTS];
		}
	
		// Buffer for the objects' ids
		object_id_t[MAX_ORDERED_OBJECTS] ids = void;
		size_t numIds;
		
		/* Seperate the objects by their order levels,
		   and check if the order is valid for them */
		iterateOrderLevels(objects, T.type, (GameObject[] slice)
		{
			assert(slice.length);
			
			if(!slice[0].typeInfo.handlesOrder(T.type))
			{
				logger_.spam("object type {} ignores order {}", slice[0].typeInfo.id, T.stringof);
				
				errorCallback(OrderError.Ignored, slice);
				return;
			}
			
			auto error = slice[0].typeInfo.checkOrder(slice, T.type, cast(void*)&order);
			
			if(error == OrderError.Okay)
			{
				foreach(object; slice)
					ids[numIds++] = object.id;
					
				slice[0].typeInfo.localOrder(slice, T.type, cast(void*)&order);
			}
			else
			{
				if(errorCallback)
				{
					errorCallback(error, slice);
				}
				else if(error != OrderError.Ignored)
				{
					onInvalidOrder(slice, error);
					
					logger_.trace("invalid order (T = {}), not sending (for {})",
						T.stringof, slice[0].typeInfo.id);
				}
			}
		});

		if(numIds)
		{
			//scope b1 = new Benchmark("send order");
		
			// Serialize the order
			ubyte[1024] buffer; // shit .. need to use ScopedResource from deadlock or so.
			
			auto stream = RawWriter((uint offset, ubyte[] data)
			{
				buffer[offset .. offset + data.length] = data[];
			});
			
			serialize(stream, T.type);
			serialize(stream, order);

			// Send the order
			if(!queueOrders)
				gateway.sendOrder(ids[0 .. numIds],
					buffer[0 .. stream.written]);
			
			// Or queue it
			else
			{
				auto container = OrderData.allocate();
				container.set(ids[0 .. numIds],
					buffer[0 .. stream.written]);
			
				orderQueue.append(container);
			}
		}
	}
	
	// Queueing orders
	void startOrderQueue()
	{
		assert(!queueOrders);
		queueOrders = true;
		
		debug(gameobjects)
			logger_.trace("queuing orders");
	}
	
	void stopOrderQueue()
	{
		assert(queueOrders);
		queueOrders = false;
	
		debug(gameobjects)
			logger_.trace("sending {} queued orders", orderQueue.length);
		
		foreach(container; orderQueue)
		{
			gateway.sendOrder(container.targets, container.data);
			OrderData.free(container);
		}
		
		orderQueue.reset();
	}
	
	/* this always returns the gateway of the LOCAL player..
	   AI will have another gateway, so don't use it for that. */
	Gateway gateway()
	{
		return _gateway;
	}
	
	ITerrain terrain()
	{
		assert(_terrain !is null);
		return _terrain;
	}
	
	Map map()
	{
		assert(_map !is null);
		return _map;
	}

	PlayerManager players()
	{
		return _players;
	}
	
	IFogOfWar localFogOfWar()
	{
		return players[gateway.id].fogOfWar;
	}
	
	SimulationRunner runner()
	{
		return _runner;
	}
	
	GameObject getObject(object_id_t id)
	{
		bool found; 
		GameObject object = getObject(id, found);
		assert(found, "object not found");
		
		return object;
	}
	
	GameObject getObject(object_id_t id, out bool found)
	{
		GameObject object;
		found = objects.get(id, object);
		
		return object;		
	}
	
	void update()
	{
		foreach(obj; objects)
			obj.update();
	}
	
	version(none) import engine.rend.Renderer;
	
	void render()
	{
		foreach(obj; objects)
			obj.render();
			
		version(none) for(uint x = 0; x < terrain.dimension.x; x++)
		{
			for(uint y = 0; y < terrain.dimension.y; y++)
			{
				auto visible = fogOfWar.isVisible(x, y);
				
				if(visible)
				{
					auto pos = terrain.getWorldPos(x, y);
					renderer.drawLine(pos, pos + vec3(0, 1, 0), vec3(1, 0, 0));
				}
			}
		}
	}
	
	void simulate()
	{
		logger_.spam("simulation step");
	
		++_currentSimulationStep;
		
		{
			// We need to delay all appends to the object list, since appending doesn't work while iterating
			auto oldAppender = objectAppender;
			
			objectAppender = (GameObject object)
			{
				appendQueue.push(object);
			};
			
			scope(exit)
				objectAppender = oldAppender;
		
			// Simulate objects
			foreach(obj; objects)
			{
				obj.simulate();
			}
			
			// Simulate type infos
			foreach(civ; civs)
			{
				foreach(ti; civ.types)
					ti.simulate();
			}
		}
		
		// Append objects which have been created this simulation step to the list
		while(!appendQueue.empty)
			appendObject(appendQueue.pop);
		
		assert(appendQueue.empty);

		// Remove objects which were deleted
		while(!freeQueue.empty)
		{
			auto object = freeQueue.pop;
			assert(object.willBeRemoved);
		
			gateway.checkSync(__FILE__, __LINE__, object.id);
		
			removeObject(object);
		}
				
		assert(freeQueue.empty);
	}
	
	uint currentSimulationStep()
	{
		return _currentSimulationStep;
	}
	
	alias currentSimulationStep step;

	Random simulationRandom()
	{
		return _simulationRandom;
	}

	TypeBase getType(player_id_t owner, type_id_t type)
	{
		if(owner == NEUTRAL_PLAYER)
			return neutralCiv.types[type];
		
		assert(owner in civs, Integer.toString(owner));
		assert(type in civs[owner].types, type);
		
		return civs[owner].types[type];
	}

	ObjectTypeInfo getTypeInfo(player_id_t owner, object_type_t type)
	{
		return objCast!(ObjectTypeInfo)(getType(owner, type));
	}
	
	Technology getTech(player_id_t owner, tech_t type)
	{
		return objCast!(Technology)(getType(owner, type));
	}
	
	Civ getCiv(player_id_t owner)
	{
		return civs[owner];
	}

	int opApply(int delegate(ref GameObject) dg)
	{
		int result = 0;
		
		foreach(obj; objects)
		{
			GameObject o = obj;
			
			if(cast(bool)(result = dg(o)))
				break;
		}
		
		return result;
	}

	void iterateCivs(bool delegate(Civ) dg)
	{
		foreach(civ; civs)
		{
			if(!civ)
				continue;
			
			if(!dg(civ))
				return;
		}
	}
	
	void localRemove(object_id_t id)
	{
		auto object = getObject(id);
		assert(object.id == id);
		
		assert(!object.willBeRemoved);
		object.willBeRemoved = true;
		
		freeQueue.push(object);
	}
	
	GameObject localCreate(player_id_t owner, object_type_t type,
	                       map_index_t x, map_index_t y)
	out(result)
	{
		assert(result.owner == owner);
		assert(result.typeInfo.owner == civs[owner].owner);
		assert(result.typeInfo.id == type);
		assert(result.mapPos.x == x);
		assert(result.mapPos.y == y);
	}
	body
	{
		ObjectTypeInfo typeInfo = getTypeInfo(owner, type);
		assert(!typeInfo.abstractType);
		
		GameObject object = typeInfo.allocate();
		assert(object !is null);

		auto id = getFreeObjectID();
		object._id = id;
		object._owner = owner;
		object._typeInfo = typeInfo;
		object.mapPos = map_pos_t(x, y);
		object.gateway = _gateway;
		object.gameObjects = this;
		object.onCreate();
		
		objectAppender(object);
		
		debug(gameobjects)
			logger_.trace("new game object (type: '{}'; id: {}; owner: {})", type, id, owner);
		
		onCreateObject(object);
		
		return object;
	}
}

// Create the type info loader for the base object type

static this()
{
	typeRegister.addLoader("base", (ObjectTypeInfo ti)
	{
		with(ti)
		{
			abstractType = true;
			objectClass = ObjectClass.Base;
		}
	});
}

//}
// -----------------------------------------------------------------------
//{ Technology
abstract class Technology : TypeBase
{
	bool available = true;
	bool developed = false;

	abstract void develop();
	
	mixin(xpose2("
		available
		developed
	"));
	mixin xposeSerialization;
}

// Technologies changing objects' stats
abstract class ObjectTechnology : Technology, Effector
{
	prop_t[MAX_OBJECT_PROPERTIES] factors;
	
	mixin(xpose2("
		factors
	"));
	mixin xposeSerialization;
	
	this()
	{
		foreach(ref pf; factors) pf = prop_t.ctFromReal!(1.0);
	}
	
	override void attach(Effected effected)
	{
		foreach(i, pf; factors)
		{
			if(pf != prop_t.ctFromReal!(1.0))
				effected.scalePropFactor(i, pf);
		}
	}
	
	override void detach(Effected effected)
	{
		foreach(i, pf; factors)
		{
			if(pf != prop_t.ctFromReal!(1.0))
				effected.scalePropFactor(i, prop_t.ctFromReal!(1) / pf);
		}		
	}
	
	override uint lifetime() { return 0; }
	override void update() { }
}
//}
//------------------------------------------------------------------------
//{ Type register
enum SimType
{
	Undefined,
	ObjectType,
	Tech
}

private template SimTypeType(SimType type)
{
	static if(type == SimType.Undefined)
		alias TypeBase SimTypeType;
	else static if(type == SimType.ObjectType)
		alias ObjectTypeInfo SimTypeType;
	else static if(type == SimType.Tech)
		alias Technology SimTypeType;
	else static assert(false);
}

final class TypeRegister
{
	mixin MLogger;

private:
	// Type loaders
	struct TypeLoader
	{
		SimType type;
	
		TypeBase delegate() create;
		void delegate(TypeBase) init;
		
		TypeBase opCall()
		{
			assert(create);
			assert(init);
		
			auto object = create();
			assert(object !is null);
			init(object);
			
			return object;
		}
	}
	
	TypeLoader[type_id_t] typeLoaders;

	// Civilisations
	CivTypeInfo[char[]] civTypeList;

public:
	mixin MSingleton;

	this()
	{
	}

	CivTypeInfo getCivType(char[] name)
	{
		return civTypeList[name];
	}
	
	TypeBase delegate() getCreator(char[] type)
	{
		return typeLoaders[type].create;
	}
	
	void delegate(TypeBase) getInitializer(char[] type)
	{
		return typeLoaders[type].init;
	}
	
	// doesn't construct
	SimTypeType!(type)[] createAllTypes(SimType type = SimType.Undefined)(
		player_id_t owner, GameObjectManager gameObjects)
	{
		SimTypeType!(type)[] result;
	
		foreach(id, loader; typeLoaders)
		{
			if(type != SimType.Undefined && loader.type != type)
				continue;
				
			auto ti = objCast!(SimTypeType!(type))(loader.create());
			loader.init(ti);
			
			ti.id = id;
			ti.owner = owner;
			ti.gameObjects = gameObjects;
			
			result ~= ti;
		}
		
		return result;
	}
	
	// Add a new type loader
	void addLoader(T)(type_id_t type, void delegate(T) init)
	{
		struct Wrap
		{
			void delegate(T) init_;
			
			TypeBase create()
			{
				return new T;
			}
			
			void initialize(TypeBase t)
			{
				assert(init_);
				init_(objCast!(T)(t));
			}
		}
		
		auto w = new Wrap;
		w.init_ = init;
		
		SimType simType;
		
		static if(is(T : Technology))
			simType = SimType.Tech;
		else static if(is(T : ObjectTypeInfo))
			simType = SimType.ObjectType;
		else static assert(false, "invalid type: " ~ T.stringof);
		
		addLoader_(type, &w.create, &w.initialize, simType);
	}
	
	final void addLoader_(type_id_t type, TypeBase delegate() create, void delegate(TypeBase) init, SimType simType)
	{
		assert(!(type in typeLoaders));
	
		assert(create);
		assert(init);
	
		TypeLoader loader;
		loader.type = simType;
		loader.create = create;
		loader.init = init;
	
		typeLoaders[type] = loader;
	}

	// Load a civilisation
	final Civ loadCiv(GameObjectManager from, player_id_t player, char[] type, type_id_t additionalTypes = null)
	{
		// TODO: load additional types
	
		logger_.info("loading civ {} for {}", type, player);
	
		assert(type in civTypeList, "civilisation `" ~ type ~ "' not found");
		auto ti = civTypeList[type];
		
		auto result = new Civ;
		result.typeInfo = ti;
		result.owner = player;
		
		// Create types and their dependencies
		{
			type_id_t[] loadList = ti.types;
		
			while(loadList.length)
			{
				auto t = loadList[0];

				assert(!(t in result.types));
				assert(t in typeLoaders, t);
			
				with(result.types[t] = typeLoaders[t]())
				{
					owner = player;
					gameObjects = from;
					id = t;
					
					setDeps();
					
					outer: foreach(dep; deps)
					{
						if(!(dep in result.types))
						{
							foreach(l; loadList)
							{
								if(l == dep)
									continue outer;
							}

							loadList ~= dep;
						}
					}
				}
				
				loadList = loadList[1 .. $];
			}
		}

		// Initialize
		ti.create(result);
		
		setupCiv(result);

		return result;
	}
	
	void setupCiv(Civ civ)
	{
		logger_.info("initializing civ {}", civ.typeInfo.name);
	
		// Construct the types
		foreach(t; civ.types)
			t.construct();

		// Create local type IDs (faster than always comparing strings)
		{
			TypeBase.local_id_t counter;
			
			foreach(t; civ.types)
				t.localTypeID = counter++;
		}

		// Resolve order level IDs
		foreach(t_; civ.types) if(auto t = cast(ObjectTypeInfo)t_) with(t)
		{
			foreach(i, ref order; orders)
			{
				if(!handlesOrder(i))
					continue;

				order = civ.types[tempOrders[i]].localTypeID;
			}
		}
	}
	
	// Add a new civilisation type
	final void addCivType(CivTypeInfo ti)
	{
		assert(!(ti.name in civTypeList));

		civTypeList[ti.name] = ti;
	}
	
	// Unload
	void unload()
	{
	
	}
}

alias SingletonGetter!(TypeRegister) typeRegister;
//}
