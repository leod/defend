module defend.sim.obj.Sheep;

import engine.scene.Graph;
import engine.math.Ray;
import engine.math.Vector;
import engine.math.Matrix;
import engine.math.BoundingBox;
import engine.input.Input;

import defend.terrain.Terrain;
import defend.sim.Resource;
import defend.sim.Core;
import defend.sim.obj.Unit;

static this()
{
	typeRegister.addLoader("sydney", (UnitTypeInfo ti)
	{
		with(ti)
		{
			//model = "sheep/low.obj";
			model = "sydney/sydney.md2.cfg";
			miniPic = "minipics/sheep.png";
			parentType = "unit";
			posOffset = vec3(0, 1, 0);
			scale = vec3(0.035, 0.035, 0.035);
			normRotation = vec3(90, -90, 0);
			devSteps = 70;
			rangeAttack = true;
			projectileType = "rocket";
			properties[GameObject.Property.MaxLife] = prop_t(500);
			properties[Unit.Property.Attack]        = prop_t(20);
			properties[Unit.Property.MovementSpeed] = prop_t(25);
			properties[Unit.Property.AttackSpeed]   = prop_t(10);
			properties[Unit.Property.Range]         = prop_t(9);
			properties[GameObject.Property.Sight]   = prop_t(20);
			cost[ResourceType.Iron] = 100;
			cost[ResourceType.Gold] = 100;
		}
	});
}
