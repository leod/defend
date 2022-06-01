module defend.sim.obj.Projectile;

import xf.omg.core.Misc : deg2rad, rad2deg;
import xf.omg.core.Fixed : fixed;
import xf.omg.core.LinearAlgebra;

import xf.xpose2.Expose;
import xf.xpose2.Serialization;

import tango.math.Math : acos, abs, sqrt;

import engine.scene.nodes.ParticleSystem;
import engine.sound.Sound : Sound;
import engine.math.Matrix : createMat4, zRotationMat;

import defend.sim.Core;

static this()
{
	typeRegister.addLoader("projectile", (ProjectileTypeInfo ti)
	{
		with(ti)
		{
			abstractType = true;
			parentType = "base";
		}
	});
}

class ProjectileTypeInfo : ObjectTypeInfo
{
	mixin(xpose2(""));
	mixin xposeSerialization;
	
	this()
	{
		editorPlaceable = false;
	}
}

class Projectile : GameObject
{
	int x;
	mixin(xpose2("x"));
	mixin xposeSerialization;

	enum Property
	{
		MovementSpeed = GameObject.Property.max + 1,
		Damage,
		AreaOfEffect
	}

	override bool intersectRay(Ray!(float) ray)
	{
		return false; // unselectable
	}
}

// a projectile only targeting one object
class SingleTargetProjectile : Projectile
{
private:
	// simulation
	GameObject shooter;
	GameObject target;
	map_pos_t targetPos;
	
	fixed distanceToTarget;
	fixed progress;
	
	// rendering
	vec3 startPoint;
	vec3 endPoint;
	
	void setRotation()
	{
		auto f = (endPoint - startPoint).normalized();
		auto up = vec3(0, 1, 0).normalized();
		auto s = cross(f, up);
		auto u = cross(s, f);
		
		_sceneNode.rotation = createMat4(s.x, s.y, s.z, 0, f.x, f.y, f.z, 0, u.x, u.y, u.z, 0, 0, 0, 0, 1) *
			zRotationMat!(float)(90.0f);
	}
	
	override void initRealPos()
	{
		realPos = startPoint + (endPoint - startPoint) * cast(real)progress / cast(real)distanceToTarget;
	}
	
public:
	mixin(xpose2("
		shooter
		target
		targetPos
		distanceToTarget
		progress
		
		startPoint
		endPoint
	")); // meh startPoint/endPoint :/
	mixin xposeSerialization;
	
	override void onUnserialized()
	{
		super.onUnserialized();
		setRotation();
	}

	override void createSceneNode()
	{
		//createDefaultSceneNode(true);
		
		super.createSceneNode();
	}
	
	// initialize
	void create(GameObject from, GameObject target)
	{
		assert(this.target is null);
		
		this.shooter = from;
		this.target = target;
		targetPos = target.mapPos;
		distanceToTarget = fixed(distance(target));
		progress = fixed(0);
		
		assert(shooter !is null);
		realPos = shooter.center; // TODO: add a field in ObjectTypeInfo to specify where projectiles get spawned
		
		createSceneNode();
		
		startPoint = realPos;
		endPoint = target.center;

		setRotation();
	}
	
	override void onObjectDead(GameObject object)
	{
		if(object is target)
			target = null;
	}
	
	override void update()
	{
		super.update();
		
		auto nextProgress = progress + property(Projectile.Property.MovementSpeed);
		if(nextProgress > distanceToTarget) nextProgress = distanceToTarget;
		
		auto interpProgress = cast(real)progress +
			(cast(real)nextProgress - cast(real)progress) *
			gameObjects.runner.interpolation;
		
		_sceneNode.translation = realPos =
			startPoint + (endPoint - startPoint) * interpProgress / cast(real)distanceToTarget;
	}

	import defend.terrain.Decals;
	
	override void simulate()
	{
		super.simulate();

		progress += property(Projectile.Property.MovementSpeed);
		//particles["smoke"].spawn(realPos, 1);
		
		if(progress >= distanceToTarget)
		{
			if(target && target.mapPos == targetPos)
			{
				target.hurt(property(Projectile.Property.Damage));
				Sound("explosion.ogg").play();
				terrain.decals.add(Decals.Type.Blood, vec2(target.realPos.x, -target.realPos.z));
			}
						
			selfRemove();
			
			// effects
			//particles["smoke"].spawn(realPos, 2);
		}
	}
	
	override bool mayBeOrdered()
	{
		return false;
	}
}
