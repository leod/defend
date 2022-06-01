module defend.sim.MapGenerator;

import tango.math.random.Kiss;

import engine.math.Vector;

import defend.sim.GameInfo;
import defend.sim.Player;
import defend.sim.Heightmap : Heightmap;
import defend.sim.Core;

interface MapGenerator
{
	Heightmap generateHeightmap(GameInfo); // will get called before generateObjects
	void generateObjects(GameInfo, GameObjectManager); // optionally
}

MapGenerator getMapGenerator(char[] type)
{
	return mapGenerators[type]();
}

MapGenerator function()[char[]] mapGenerators;

private
{
	static this()
	{
		mapGenerators["four players"] = function MapGenerator() { return new FourPlayers; };
	}

	class FourPlayers : MapGenerator
	{
		Kiss random;
	
		Heightmap generateHeightmap(GameInfo info)
		{
			random.seed(info.terrain.seed);
			
			auto size = vec2us(info.terrain.dimension, info.terrain.dimension);
		
			scope hm2 = new Heightmap(size, 16);
			hm2.randomize(random.toInt(2000), 3, 1.4, 3);
			
			scope hm3 = new Heightmap(size, 20);
			hm3.loadFromImage("four_players.png");

			auto hm = new Heightmap(size, 13);
			with(hm)
			{
				randomize(random.toInt(2000), 2.5, 0.6, 6);
				multiply(hm3);
				multiply(hm2);
				smooth();
			}
			
			return hm;
		}
		
		void generateObjects(GameInfo info, GameObjectManager gameObjects)
		{
			with(gameObjects)
			{
				version(none) for(int x = 0; x < gameObjects.map.size.x; x += 5)
				{
					for(int y = 0; y < gameObjects.map.size.y; y += 5)
						localCreate(0, "citizen", x, y);
				}
			
				localCreate(cast(player_id_t)0, "house", 30, 30);			
				localCreate(cast(player_id_t)0, "sydney", 32, 29);
				localCreate(cast(player_id_t)0, "citizen", 33, 29);
			
				if(gameObjects.players.isPlayer(cast(player_id_t)1))
					localCreate(cast(player_id_t)1, "house", 40, 30);
				//else
				//	localCreate(cast(player_id_t)0, "house", 40, 30);
				
				version(all) for(int i = 0; i < 50; i++)
				{
					auto ti = getTypeInfo(NEUTRAL_PLAYER, "wood");
					auto x = random.toInt(info.terrain.dimension);
					auto y = random.toInt(info.terrain.dimension);
					
					if(ti.isPlaceable(map_pos_t(x, y)))
						localCreate(NEUTRAL_PLAYER, "wood", x, y);
				}
			}
		}
	}
}
