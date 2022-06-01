module defend.sim.MapData;

import xf.xpose2.Expose;
import xf.xpose2.Serialization;

import defend.sim.Heightmap;
import defend.sim.Types;

// used to serialize maps by the map editor

class MapData
{
	Heightmap heightmap;
	
	struct ObjectInfo
	{
		player_id_t owner;
		object_type_t type;
		
		// probably more to come, like rotation and maybe properties
		
		mixin(xpose2("owner | type"));
		mixin xposeSerialization;
	}
	
	ObjectInfo[] objects;
	
	mixin(xpose2("heightmap | objects"));
	mixin xposeSerialization;
}