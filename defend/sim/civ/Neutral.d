module defend.sim.civ.Neutral;

import defend.sim.Core;

// Civilisation for neutral "player"

static this()
{
	typeRegister.addCivType(new CivTypeInfo
	(
		"neutral",
	
		[ "wood" ],
		
		(Civ civ)
		{
		
		}
	));
}
