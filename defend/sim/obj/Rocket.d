module defend.sim.obj.Rocket;

import defend.sim.Core;

import defend.sim.obj.Projectile;

static this()
{
	typeRegister.addLoader("rocket", (ProjectileTypeInfo ti)
	{
		with(ti)
		{
			parentType = "projectile";
			
			allocateObject = function GameObject() { return new SingleTargetProjectile; };
			freeObject = function void(GameObject o) { delete o; };
		
			model = "box/box.obj";
			posOffset = vec3(0, 0, 0);
			scale = vec3(0.6, 0.2, 0.2);
			normRotation = vec3(0, 0, 0);
			
			properties[Projectile.Property.MovementSpeed] = prop_t(3);
			properties[Projectile.Property.Damage] = prop_t(100);
		}
	});
}
