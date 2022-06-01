module defend.sim.IFogOfWar;

import engine.rend.Texture;
import engine.math.Vector;

import defend.sim.Types;

// fog of war state of game objects
enum FogOfWarState
{
	Visible,
	Cached,
	Culled
}

abstract class IFogOfWar
{
	abstract bool isVisible(map_index_t x, map_index_t y);
	abstract bool isRectVisible(map_pos_t p, vec2i d);
	
	//abstract FogOfWarState getObjectState(Object object);
	
	abstract bool enabled();
}
