module defend.sim.obj.House;

import engine.math.Vector;
import engine.model.Model;

import defend.sim.Resource;
import defend.sim.Core;
import defend.sim.obj.Building;

static this()
{
	typeRegister.addLoader("house", (BuildingTypeInfo ti)
	{
		with(ti)
		{
			model = "house/model.obj";
			miniPic = "minipics/house.png";
			parentType = "building";
			dimension = vec2i(5, 6);
			posOffset = vec3(2, 0.2, -2.5);
			scale = vec3(0.4, 0.4, 0.4);
			buildSteps = 2000;
			canBuild = [ "sydney", "citizen" ];	   
			canDevelop = [ "sheepdrugs" ];
			properties[GameObject.Property.MaxLife] = prop_t(2000);
			properties[GameObject.Property.Sight] = prop_t(20);
			cost[ResourceType.Wood] = 200;
		}
	});
}
