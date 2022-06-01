module defend.sim.civ.Test;

import engine.util.Array;

import defend.sim.Core;
import defend.sim.obj.Unit;
import defend.sim.obj.Citizen;
import defend.sim.obj.Building;

static this()
{
	typeRegister.addCivType(new CivTypeInfo
	(
		"test 1",
	
		//[ "base", "unit", "building",
		//  "sheep", "house", "citizen",
		//  "sheep on drugs" ],
		
		/* only need to load "house" explicitly, because it depends on
		   "citizen", "sheep" and "sheep on drugs" */
		[ "house" ],
		
		(Civ civ)
		{
			/*with(civ.ids["unit"])
			{
				scalePropFactor(Unit.Property.MovementSpeed, 1);
			}
			
			with(civ.ids["sheep"])
			{
				scalePropFactor(Unit.Property.MovementSpeed, 1);
			}*/
			
			/*with(cast(BuildingTypeInfo)civ.ids["house"])
			{
				canBuild = removeElement(canBuild, "citizen");
			}*/
		}
	));
	
	typeRegister.addCivType(new CivTypeInfo
	(
		"test 2",
	
		[ "house" ],
		
		(Civ civ)
		{
			with(cast(ObjectTypeInfo)civ.types["unit"])
			{
				scalePropFactor(Unit.Property.MovementSpeed, prop_t(2));
			}
		}
	));
}
