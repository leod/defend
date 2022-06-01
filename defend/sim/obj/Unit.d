module defend.sim.obj.Unit;

import tango.math.Math;
import Integer = tango.text.convert.Integer;
import tango.util.Convert;

import xf.xpose2.Expose;
import xf.xpose2.Serialization;

import engine.model.Model;
import engine.util.Debug;
import engine.util.Signal;
import engine.util.Array;
import engine.util.Wrapper;
import engine.util.Cast;
import engine.mem.ArrayPool;
import engine.mem.Memory;
import engine.math.Vector;
import engine.math.Matrix;
import engine.math.BoundingBox;
import engine.math.Ray;
import engine.scene.Node;
import engine.scene.Graph;
import engine.scene.nodes.ModelNode;
import engine.scene.nodes.ParticleSystem;
import engine.rend.Renderer;
import engine.sound.Sound : Sound;

import defend.Config;
import defend.sim.Resource;
import defend.sim.Player;
import defend.sim.Core;
import defend.sim.SceneNode;
import defend.sim.Effector;
import defend.sim.obj.Projectile : SingleTargetProjectile;

//debug = unit;

static this()
{
	typeRegister.addLoader("unit", (UnitTypeInfo ti)
	{
		with(ti)
		{
			abstractType = true;
			parentType = "base";
		}
	});
	
	typeRegister.addLoader("sheepdrugs", (UnitTechnology tech)
	{
		with(tech)
		{
			targets = [ "sydney" ];
			miniPic = "minipics/speed.png";
			factors[Unit.Property.MovementSpeed] = prop_t(20);
			devSteps = 100;
			cost[ResourceType.Gold] = 300;
		}
	});
}

class UnitTechnology : ObjectTechnology
{
	object_type_t[] targets;
	
	mixin(xpose2("UnitTechnology", "targets"));
	mixin xposeSerialization!("UnitTechnology");

	override void develop()
	{
		assert(!developed);

		foreach(target; targets)
			gameObjects.getTypeInfo(owner, target).applyEffector(this);
		
		developed = true;
	}
}

//static this() { dumpXposeData!(UnitTechnology); }

class UnitTypeInfo : ObjectTypeInfo
{
	// Sound which gets played when the unit is ordered to move to some place
	char[] moveSound = null;
	
	// Ranged attacks
	bool rangeAttack = false;
	object_type_t projectileType = null;

	//mixin(xpose2("UnitTypeInfo", ""));
	mixin xposeSerialization!("UnitTypeInfo");
	
	// Orders
	OrderError checkMapRightClickOrder(GameObject[] objects, OrderMapRightClick* order)
	{
		return map[order.x, order.y].walkable ?
		       OrderError.Okay : OrderError.Error;
	}
	
	OrderError checkObjectRightClickOrder(GameObject[] objects, OrderObjectRightClick* order)
	{
		bool targetExists;
		auto target = gameObjects.getObject(order.target, targetExists);
	
		if(!targetExists)
			return OrderError.TargetDoesNotExist;
	
		return OrderError.Okay; // tmp for testing
		return target.owner != objects[0].owner &&
		       target.owner != NEUTRAL_PLAYER ?
		       OrderError.Okay : OrderError.Ignored;
	}
	
	void localMapRightClickOrder(GameObject[] objects, OrderMapRightClick* order)
	{
		if(moveSound)
			Sound(moveSound).play();
	}
	
	void onMapRightClickOrder(GameObject[] objects, OrderMapRightClick* order)
	{
		// Calculate direction
		auto unit = cast(Unit)objects[0];		
		auto direction = Unit.getDirection(unit.path.length < 2 ? unit.mapPos : unit.path[$ - 2],
		                                   map_pos_t(order.x, order.y));
		
		iterateObjects(objects, (Unit object)
		{
			object.finalDirection = direction;
		});
	
		// TODO: Group pathfinding
		iterateObjects(objects, (Unit object)
		{
			object.move(map_pos_t(order.x, order.y));
		});
	}
	
	void onObjectRightClickOrder(GameObject[] objects, OrderObjectRightClick* order)
	{
		auto target = gameObjects.getObject(order.target);
	
		iterateObjects(objects, (Unit object)
		{
			object.attack(target);
		});
	}

	override void setDeps()
	{
		super.setDeps();
		
		if(projectileType)
			addDep(projectileType);
	}

	override void construct()
	{
		super.construct();
	
		if(model !is model.init)
			Model(model);
		
		objectClass = ObjectClass.Unit;
		
		addOrderCallback("unit", &checkMapRightClickOrder,
			&localMapRightClickOrder, &onMapRightClickOrder);
			
		addOrderCallback("unit", &checkObjectRightClickOrder,
			null, &onObjectRightClickOrder);
			
		allocateObject = function GameObject() { return new Unit; };
		freeObject = function void(GameObject object) { delete object; };
	}
	
	override void destruct()
	{
		super.destruct();
	
		if(model !is model.init)
			subRef(Model.get(model));
	}
}

// Base class for units
class Unit : GameObject
{
protected:	
	// Unit collision resolution, returns true when a collision happened
	bool checkCollision(map_pos_t pos)
	{
		//debug(gameobjects) logger.spam("checking [{}|{}] for collisions", pos.x, pos.y);
	
		auto tile = map[pos];
		assert(tile.mapObject !is this, "um, I'm already standing here (" ~ Integer.toString(id) ~ ")");
		
		// Test, if the tile we're going to is already in use
		if(!tile.free)
		{
			if(tile.mapObject !is null &&
			   tile.mapObject !is this &&
			   (cast(GameObject)tile.mapObject).typeInfo.objectClass == ObjectClass.Unit)
			{
				auto unit = cast(Unit)tile.mapObject;
				assert(unit !is null);
				assert(unit.mapPos == pos);
				
				/* If the unit on this tile is moving too,
				   we simply wait some ticks and go to the final goal afterwards */
				if(unit.moving && unit.movePause == 0 &&
				   property(Unit.Property.MovementSpeed) <=
				   unit.property(Unit.Property.MovementSpeed))
				{
					movePause = 5;
					path = null;
					status = Status.Idle;

					currentRealPos = nextRealPos = realPos;

					_sceneNode.setAnimation("stand");
				
					debug(gameobjects) logger.spam("tile occupied; taking a break of {} steps", movePause);
					
					//auto dir = direction;
					//moveFinished(); // do I need to call it?
					//direction = dir;
				}
				else
				{
					// Otherwise, check if any tile on our path is free
					map_pos_t tempGoal = mapPos;
					foreach_reverse(wp; path[1 .. $])
					{
						tile = map[wp];
						
						if(tile.free)
						{
							tempGoal = wp;
							break;
						}
					}
					
					// If no free tile was found, search for a free tile around the goal
					if(tempGoal == mapPos)
					{
						map_pos_t newGoal = map.searchFreeTile(finalGoal, mapPos);
						
						// If no free tile around the goal was found, stop moving
						if(newGoal == mapPos || mapPos.distance(finalGoal) < 2)
						{
							debug(gameobjects) logger.spam("tile occupied and no new path found; stopping");

							moveFinished();
						}
						else
						{
							debug(gameobjects) logger.spam("tile occupied; going to a tile around the goal");
						
							// Otherwise, go there
							move(newGoal, false, false, true);
						}
					}
					else
					{
						debug(gameobjects)
							logger.spam("tile occupied; going to [{}|{}] and then to the final goal",
							            tempGoal.x, tempGoal.y);
					
						/* Go to this free tile while avoiding other units,
						   and then continue to go to the final goal */
						move(tempGoal, false, true, false);
					}
				}
				
				return true;
			}
			else
			{
				// happens when somebody suddenly puts a building in our way
			
				// Test if this our last tile
				if(pos == finalGoal)
				{
					debug(gameobjects)
						logger.spam("tile occupied; but final goal already reached");

					moveFinished();
				   
					return true;
				}
				
				// Simply calculate a new path
				move(finalGoal, false, false, true);
				
				return true;
			}
		}
		
		return false;
	}
	
	// Our type info
	UnitTypeInfo unitInfo;
	
	// Following or going to some other game object
	bool isFollowing;
	GameObject followObject; // The object which we are following
	void delegate() followCallback; // Gets called when the object is reached
	fixed followRange;
	
	void delegate() readFollowCallback(char[] s)
	{
		if(s == "attack")
			return &targetReached;
			
		assert(s == "");
		return null;
	}
	
	char[] writeFollowCallback()
	{
		if(followCallback == &targetReached)
			return "attack";
			
		assert(followCallback == null);
		return "";
	}
	
	static void _readFollowCallback(Unit unit, Unserializer u)
	{
		char[] type;
		u(type);
		
		unit.followCallback = unit.readFollowCallback(type);
	}
	
	static void _writeFollowCallback(Unit unit, Serializer s)
	{
		s(unit.writeFollowCallback());
	}
	
	void follow(GameObject object, void delegate() callback, fixed range = fixed.ctFromReal!(0))
	in
	{
		assert(object !is null);
	}
	body
	{
		debug(gameobjects)
			logger.trace("following {}", object.id);
	
		isFollowing = true;
		
		auto walkPos = mapPos;
		walkPos = object.searchFreeTileAround(mapPos);

		// Move there, even if there's no tile around it free
		localMove(walkPos, false);

		followObject = object;
		followCallback = callback;
		followRange = range;
	}
	
	void stopFollow()
	{
		assert(followObject !is null);
	
		debug(gameobjects)
			logger.spam("stopping to follow {}", followObject.id);
	
		isFollowing = false;
		followObject = null;
		followCallback = null;
	}
	
	void moveFinished()
	{
		_sceneNode.setAnimation("stand");
		
		direction = finalDirection;
		status = Status.Idle;
		path = null;
	
		if(followObject)
		{
			if(isStandingNearby(followObject) ||
				(followRange != fixed(0) && fixed(distance(followObject)) <= followRange))
			{
				debug(gameobjects)
					logger.spam("reached the followed object ({})", followObject.id);
						
				// Look at our target
				direction = getDirection(mapPos, followObject.mapRectangle.nearestPoint(mapPos));
			
				assert(followCallback, "serialize fail");
				followCallback();
				
				isFollowing = false;
			}
			else
			{
				debug(gameobjects)
					logger.spam("didn't come near enough to the followed object, try again");
			
				follow(followObject, followCallback, followRange);
			}
		}
	}
	
	// Movement
	vec3 lastWayPoint;
	vec3 nextWayPoint;
	
	map_pos_t finalGoal;
	bool moving() { return status == Status.Moving; }
	
	vec3fi _direction;
	vec3fi direction() { return _direction; }
	void direction(vec3fi v) { assert(v.ok); _direction = v; }
	
	vec3fi _finalDirection; // set after the target was reached
	vec3fi finalDirection() { return _finalDirection; }
	void finalDirection(vec3fi v) { assert(v.ok); _finalDirection = v; }
	
	fixed movePercent; // progress of walking the current tile
	const MAX_MOVE_PERCENT = fixed.ctFromReal!(100);
	
	int movePause;
	map_pos_t prevMapPos; // needed for serialization (to reconstruct lastWayPoint, which is needed for interpolation)
	
	// slice of the ArrayPool
	map_pos_t[] pathPoolSlice;
	
	// slice of pathPoolSlice or pathBuffer
	map_pos_t[] path;
	
	// Interpolation
	vec3 currentRealPos = vec3.one;
	vec3 nextRealPos = vec3.one;
	
	// Attacking
	GameObject target; // Attack target
	fixed attackCounter; // Countdown to the next attack
	
	map_pos_t[] pathBuffer;
	
	mixin(xpose2("Unit", `
		movePause
		unitInfo
		isFollowing
		followObject
		followRange
		finalGoal
		_direction
		_finalDirection
		target
		attackCounter
		path
		prevMapPos
		followCallback serial { read "_readFollowCallback"; write "_writeFollowCallback" }
	`)); /+// TODO: serialize followCallback with better magic :/ +/
	mixin xposeSerialization!("Unit");
	
	// Find the way to a point on the map and start to walk there
	final void move(map_pos_t p, bool orderOfUser = true,
	                bool considerObjects = false, bool isFinalGoal = true)
	{
		if(p == mapPos)
			return;
	
		movePause = 0;
		
		debug(gameobjects)
			logger.trace("moving to [{}|{}] (order: {})",
			             p.x, p.y, orderOfUser, considerObjects, isFinalGoal);
	
		if(isFinalGoal)
			finalGoal = p;
			
		if(orderOfUser && followObject !is null)
			stopFollow();
		
		if(moving && movePercent != MAX_MOVE_PERCENT)
		{
			pathBuffer[0] = mapPos;
			path = map.getPath(mapPos, p, pathBuffer[1 .. $], considerObjects, this);
			path = pathBuffer[0 .. path.length == 0 ? 1 : path.length];
		}
		else
		{
			//logger.info("searching path from {} to {}", mapPos, p);
		
			path = map.getPath(mapPos, p, pathBuffer, considerObjects, this);
			//logger.info("{}", path[0]);
			//logger.info("path: {}", path);

			if(path.length)
			{
				assert(path[$ - 1] == p);
			
				if(!checkCollision(path[0]))
				{
					_sceneNode.setAnimation("run");
				
					status = Status.Moving;
					
					moveToPoint(path[0]);
					
					assert(lastWayPoint.ok);
					assert(nextWayPoint.ok);
				}
			}
			else
			{
				_sceneNode.setAnimation("stand");
				debug(gameobjects) logger.spam("no path found");
			}
		}

		if(path.length > 1)
			assert(path[$ - 2] != path[$ - 1], "invalid path, last tile appears twice");
		
		//assert(!moving || path.length);
		
		gateway.checkSync(__FILE__, __LINE__, id);
		gateway.checkSync(__FILE__, __LINE__, path.length);
	}
	
	// Attack another unit
	void attack(GameObject object)
	{		
		debug(gameobjects)
			logger.trace("attacking {}", object.id);
	
		target = object;
		follow(target, &targetReached, property(Property.Range));
		
		resetAttackCounter();
	}
	
	void targetReached()
	{
		debug(gameobjects)
			logger.spam("reached attack target ({})", target.id);
	
		status = Status.Attacking;
		_sceneNode.setAnimation("attack");
	}
	
	void resetAttackCounter()
	{
		//Stdout("setting counter to ")(cast(int)property(Property.AttackSpeed)).newline;
	
		attackCounter = property(Property.AttackSpeed);
		assert(attackCounter > fixed(0));
	}
	
	// Calculate move progress of the current tile, in percent (for interpolation)
	void calcMoveProgress()
	{
		auto percent = cast(real)(movePercent / MAX_MOVE_PERCENT);
		assert(percent >= 0.0f && percent <= 1.0f);
		
		// interpolation
		currentRealPos = lastWayPoint * (1.0 - percent) + nextWayPoint * percent;
		calcNextRealPos();
	}
	
	// For interpolation
	void calcNextRealPos()
	{
		auto percent = cast(real)((movePercent + property(Unit.Property.MovementSpeed)) /
								  MAX_MOVE_PERCENT);
								  
		if(percent > 1) percent = 1;
		
		nextRealPos = lastWayPoint * (1.0 - percent) + nextWayPoint * percent;
	}
	
	// Returns the direction for moving from point a to point b
	static vec3fi getDirection(map_pos_t a, map_pos_t b)
	{
		int dx = cast(int)a.x - cast(int)b.x;
		int dy = cast(int)b.y - cast(int)a.y;

		vec3fi makeVec(int a, int b, int c)
		{
			return vec3fi(fixed(a), fixed(b), fixed(c));
		}
		
		if(dx < 0 && dy > 0)
			return makeVec(0, 45, 0);
			
		if(dx == 0 && dy > 0)
			return makeVec(0, 0, 0);
			
		if(dx > 0 && dy > 0)
			return makeVec(0, -45, 0);
			
		if(dx > 0 && dy == 0)
			return makeVec(0, -90, 0);
			
		if(dx > 0 && dy < 0)
			return makeVec(0, -135, 0);
			
		if(dx == 0 && dy < 0)
			return makeVec(0, 180, 0);
			
		if(dx < 0 && dy < 0)
			return makeVec(0, 135, 0);
			
		if(dx < 0 && dy == 0)
			return makeVec(0, 90, 0);
		
		return makeVec(0, 0, 0);
	}
	
	// Moves to a point
	void moveToPoint(map_pos_t p)
	{
		assert(p != mapPos);
	
		// check that there are no jumps
		assert(abs(cast(int)p.x - cast(int)mapPos.x) <= 1);
		assert(abs(cast(int)p.y - cast(int)mapPos.y) <= 1);
	
		debug(gameobjects)
			logger.spam("walking from [{}|{}] to [{}|{}]", mapPos.x, mapPos.y, p.x, p.y);
	
		assert(map[mapPos].mapObject is this);
		map[mapPos].mapObject = null;
		
		direction = getDirection(mapPos, p);
		lastWayPoint = terrain.getWorldPos(mapPos);
		prevMapPos = mapPos;
		
		mapPos = p;
		
		movePercent = fixed(0);
		nextWayPoint = terrain.getWorldPos(mapPos);
		
		assert(map[mapPos].mapObject is null);
		map[mapPos].mapObject = this;

		// interpolation, not simulation related
		currentRealPos = realPos;
		calcNextRealPos();
	}

	// Preallocated memory for pathes
	static ArrayPool!(map_pos_t) pathPool;
	
	/* If the path is longer than that, the unit will need to allocate its own memory,
	   instead of using the pool */
	static const uint MAX_PATH_LENGTH = 400;
	
	static this()
	{
		pathPool.create(MAX_PATH_LENGTH, MAX_OBJECT_NUMBER);
	}
	
	void markMap()
	{
		assert(map[mapPos].free);
		assert(map[mapPos].mapObject is null);
		
		map[mapPos].mapObject = this;
	}
	
public:
	mixin MAllocator;

	enum Status : object_status_t
	{
		// The unit isn't doing anything at all (just standing around)
		Idle = GameObject.Status.max + 1,
		
		// Moving to a point on the map
		Moving,
		
		// Attacking another unit or building
		Attacking
	}

	enum Property : prop_type_t
	{
		Attack = GameObject.Property.max + 1,
		Armour,
		Range,
		MovementSpeed,
		AttackSpeed
	}
	
	this()
	{
		direction = vec3fi.zero;
		pathPoolSlice = pathBuffer = pathPool.allocate();
	}
	
	override void onObjectDead(GameObject which)
	{
		super.onObjectDead(which);
	
		if(which is followObject)
		{
			stopFollow();
			assert(followObject is null);
		}
			
		if(which is target)
		{
			target = null;
			status = Status.Idle;
			path = null;
			_sceneNode.setAnimation("stand");
		}
	}
	
	void localMove(map_pos_t pos, bool orderOfUser = true)
	{
		finalDirection = vec3fi.zero; // //to prevent NaN (in checkCollision)
		move(pos, orderOfUser);
		finalDirection = getDirection(mapPos, pos);
	}
	
	override void onCreate()
	{
		super.onCreate();
		
		markMap();

		unitInfo = cast(UnitTypeInfo)typeInfo;
		assert(unitInfo !is null);
		
		status = Status.Idle;
		finalGoal = mapPos;
		
		initRealPos();
		createSceneNode();
		_sceneNode.setAnimation("stand");
	}
	
	override void onUnserialized()
	{
		super.onUnserialized();
		
		markMap();
		
		if(moving)
		{
			lastWayPoint = terrain.getWorldPos(prevMapPos);
			nextWayPoint = terrain.getWorldPos(mapPos);
			
			calcMoveProgress();
		}
		
		char[] anim;
		
		switch(status)
		{
		case Status.Idle:
			anim = "stand";
			break;
		case Status.Moving:
			anim = "run";
			break;
		case Status.Attacking:
			anim = "attack";
			break;
		default:
			debug(gameobjects)
				logger.warn("no anim for {}?", status);
		}
		
		if(anim)
			_sceneNode.setAnimation(anim);
	}
	
	override void cleanUp()
	{
		super.cleanUp();

		pathPool.free(pathPoolSlice);
	}
	
	override void onRemove()
	{
		assert(map[mapPos].mapObject is this);
		map[mapPos].mapObject = null;

		super.onRemove();
	}
	
	override void render()
	{
		//renderer.drawLine(realPos, realPos + vec3(0, 10, 0), vec3(1, 0, 0));
	
		// Debug the path
		/+/+debug(unit)+/ if(selected)
		{
			if(moving && path.length)
			{
				map_pos_t a = mapPos;
				
				foreach(b; path)
				{
					renderer.drawLine(terrain.getWorldPos(a) + vec3(0, 0.11, 0),
									  terrain.getWorldPos(b) + vec3(0, 0.11, 0),
									  vec3(1, 0, 0));
					
					a = b;
				}
			}
			
			if(followObject)
			{
				renderer.drawLine(center, followObject.center, vec3(1, 1, 0));
			}
		}+/
	}
	
	override void update()
	{
		super.update();
	
		// interpolation
		if(moving && path)
		{
			auto interp = gameObjects.runner.interpolation;
			assert(interp <= 1.0f);
			
			realPos = currentRealPos * (1.0 - interp) + nextRealPos * interp;
		}
		
		sceneNode.translation = realPos + typeInfo.posOffset;
		sceneNode.rotation = to!(vec3)(to!(vec3r)(direction)) + typeInfo.normRotation;
	}

	override void hurt(fixed f)
	{
		super.hurt(f);

		particles["blood"].spawn(realPos, 100);
	}

	override void simulate()
	{
		super.simulate();
		
		// Pause
		if(movePause > 0)
		{
			if(--movePause == 0)
			{
				if(!moving && mapPos != finalGoal)
				{
					debug(gameobjects)
						logger.spam("continuing to final goal after pause");
					
					move(finalGoal, false, false, true);
				}
			}
			
			return;
		}
		
		switch(status)
		{
		case Status.Attacking:
			if(!target)
				status = Status.Idle;
			else
			{
				if(!unitInfo.rangeAttack && isStandingNearby(target))
				{
					attackCounter -= fixed(1);
				
					if(attackCounter <= fixed(0))
					{
						target.hurt(property(Property.Attack));
						
						resetAttackCounter();
					}
				}
				else if(unitInfo.rangeAttack &&
					fixed(distance(target)) <= property(Property.Range))
				{
					attackCounter -= fixed(1);
				
					if(attackCounter <= fixed(0))
					{
						auto projectile = objCast!(SingleTargetProjectile)(
							gameObjects.localCreate(owner,
								unitInfo.projectileType,
								mapPos.x, mapPos.y));
	
						projectile.create(this, target);
						
						resetAttackCounter();
					}
				}
				else
				{
					debug(gameobjects)
						logger.spam("target ran away, attacking again");
					
					attack(target);
				}
			}
		
			break;
		
		case Status.Moving:
			if(movePercent < MAX_MOVE_PERCENT)
				movePercent += property(Property.MovementSpeed);

			if(movePercent > MAX_MOVE_PERCENT)
				movePercent = MAX_MOVE_PERCENT;
	
			// Reached the next tile
			if(movePercent == MAX_MOVE_PERCENT)
			{
				if(isFollowing && followRange != fixed(0) &&
					fixed(distance(followObject)) <= followRange)
				{
					debug(gameobjects)
						logger.spam("in target range (pos now is [{}|{}])", mapPos.x, mapPos.y);
				
					moveFinished();
				}
			
				// Path finished
				else if(path.length < 2)
				{
					debug(gameobjects)
						logger.spam("path finished, reached {}", mapPos);

					status = Status.Idle;
					path = null;
					
					direction = finalDirection;
					
					if(mapPos != finalGoal)
					{
						debug(gameobjects)
							logger.spam("moving to the final goal ({}) now", finalGoal);
						
						move(finalGoal, false, false, true);
					}
					else
						moveFinished();
						
					gateway.checkSync(__FILE__, __LINE__, id);
				}
				
				// Start walking to the next tile
				else if(!checkCollision(path[1]))
				{
					path = path[1 .. $];
					moveToPoint(path[0]);
					assert(mapPos == path[0]);
				}
			}
			
			calcMoveProgress();
			
			break;
		
		case Status.Idle:
			if(path.length)
			{
				if(!checkCollision(path[0]))
				{
					status = Status.Moving;
				
					moveToPoint(path[0]);
					path = path[1 .. $];
				}
			}
		
		default:
			break;
		}
	}
}
