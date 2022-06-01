module defend.terrain.ITerrain;

import engine.rend.Texture;
import engine.math.Vector;
import engine.math.Ray;

public
{
	import defend.terrain.Decals;
	import defend.sim.Heightmap;
}

import defend.sim.Types;
import defend.terrain.Patch;

interface ITerrain
{
	Heightmap heightmap();
	Decals decals();
	vec3 getWorldPos(map_pos_t p);
	vec3 getWorldPos(vec2i p);
	vec3 getWorldPos(uint x, uint y);
	Texture lightmap();
	Texture fogOfWarTexture();
	map_pos_t dimension();
	void renderOrthogonal();
	bool within(vec2us p);
	void iteratePatches(bool delegate(TerrainPatch) dg);
	bool intersectRay(Ray!(float) ray, ref map_pos_t mapPos);
}