module defend.sim.Sim;

import tango.core.Memory;

import engine.util.Log : MLogger;
import engine.util.Signal;

import xf.xpose2.Serialization;

import defend.terrain.Terrain;
import defend.sim.Core;
import defend.sim.Gateway;
import defend.sim.Player;
import defend.sim.Runner;
import defend.sim.Heightmap;
import defend.sim.Map;
import defend.sim.FogOfWar;
import defend.sim.MapGenerator;

class Simulation
{
	mixin MLogger;

private:
	Gateway _gateway;
	GameObjectManager _gameObjects;
	PlayerManager _players;
	SimulationRunner _runner;

	Heightmap _heightmap;
	Map _map;
	
	GameInfo gameInfo;
	
	void generateMap(GameInfo gi)
	{
		logger_.info("generating map (size={}*{}, seed={})",
		             gi.terrain.dimension, gi.terrain.dimension,
		             gi.terrain.seed);
	
		auto generator = getMapGenerator(gi.terrain.generatorType);
		
		_heightmap = generator.generateHeightmap(gi);
		_map = new Map(heightmap);

		gameObjects.setMap(map);

		onGameInfo(gi);
		
		if(!gi.useSaveGame)
			generator.generateObjects(gi, gameObjects);
	}
	
	void _onGameInfo(GameInfo info)
	{
		logger_.trace("got game info");

		if(!info.useSaveGame)
		{
			logger_.info("no savegame; forwarding game info");
	
			gameInfo = info;
	
			_players.onGameInfo(info);
			_gameObjects.onGameInfo(info);
			
			if(gameInfo.terrain.isRandom)
			{
				generateMap(info);
			}
			else
			{
				scope unserializer = new Unserializer(info.saveGame);
				scope(exit) unserializer.close();

				{
					GameInfo dummy;
					unserializer(dummy);
					
					assert(dummy.players.length == info.players.length, "wrong number of players for this map, adjusting currently not supported");
					assert(dummy.isMapSave, "not a map");
				}
				
				// TODO
				assert(false);
			}
			
			foreach(player; _players)
			{
				if(gameInfo.withFogOfWar)
					player.fogOfWar = new FogOfWar(_gameObjects, player.info.id, _map.size);
				else
					player.fogOfWar = new DisableFogOfWar;
			}
		}
		else
		{
			logger_.info("savegame: {}", info.saveGame);
			
			scope unserializer = new Unserializer(info.saveGame);
			scope(exit) unserializer.close();
			
			logger_.info("unserializing game info");
			gameInfo = unserializer.get!(GameInfo);
			assert(gameInfo.useSaveGame);
			
			logger_.info("unserializing players");
			_players.onGameInfo(info);
			unserializer.readObject(_players);
			
			if(info.terrain.isRandom)
			{
				generateMap(info);
			}
			else
			{
				// TODO
				assert(false);
			}

			logger_.info("unserializing game objects");
			_gameObjects.onGameInfo(gameInfo);
			unserializer.readObject(_gameObjects);
			
			foreach(player; players) // not a hack at all
			{
				if(auto fow = cast(FogOfWar)player.fogOfWar)
				{
					fow.setGameObjects(gameObjects);
				}
			}
		}
	}
	
	void onMakeSaveGame(char[] name)
	{
		logger_.info("saving game to {}", name);
	
		saveGame(name);
		
		GC.collect();
		
		// TODO: compare savegame with all other clients (hash)
	}
	
	void synchGameInfo()
	{
		gameInfo.players.length = 0;
		
		foreach(player; players)
			gameInfo.players ~= player.info;
	}
	
public:
	Signal!(GameInfo) onGameInfo;

	this(Gateway gateway)
	{
		_gateway = gateway;
		_gateway.onGameInfo.connect(&_onGameInfo);
		_gateway.onMakeSaveGame.connect(&onMakeSaveGame);
		
		_players = new PlayerManager(_gateway);
		_runner = new SimulationRunner(_gateway);
		_gameObjects = new GameObjectManager(_gateway, _players, _runner);
	}
	
	~this()
	{
		delete _gameObjects;
		delete _players;
	}
	
	GameObjectManager gameObjects()
	{
		return _gameObjects;
	}
	
	PlayerManager players()
	{
		return _players;
	}
	
	Heightmap heightmap()
	{
		return _heightmap;
	}
	
	Map map()
	{
		return _map;
	}
	
	/+FogOfWar fogOfWar()
	{
		return _fogOfWar;
	}+/
	
	void serialize(Serializer s)
	{
		synchGameInfo();
		gameInfo.useSaveGame = true;
		gameInfo.isMapSave = false;
	
		s(gameInfo);
		
		s(_players);
		s(_gameObjects);
		
		if(!gameInfo.terrain.isRandom && gameInfo.terrain.file.length == 0)
			s(heightmap);
	}
	
	void saveGame(char[] file)
	{
		scope s = new Serializer(file);
		scope(exit) s.close();
		
		serialize(s);
	}
	
	void setTerrain(Terrain terrain)
	{
		logger_.info("setting terrain");
		gameObjects.setTerrain(terrain);
	}
	
	static GameInfo getGameInfoFromSaveGame(char[] file)
	{
		scope u = new Unserializer(file);
		scope(exit) u.close();
		
		return u.get!(GameInfo);
	}
}
