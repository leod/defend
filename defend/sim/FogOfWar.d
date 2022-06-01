module defend.sim.FogOfWar;

import xf.xpose2.Expose;
import xf.xpose2.Serialization;

import engine.core.TaskManager;
import engine.util.Log : Log, Logger, LogLevel;
import engine.util.Profiler;
import engine.util.Array;
import engine.util.Cast;
import engine.list.BufferedArray;
import engine.math.Vector;
import engine.math.Rectangle;
import engine.scene.Node;

import defend.sim.Core;
import defend.sim.IFogOfWar;
import defend.sim.SceneNode;
import defend.sim.Types;

class DisableFogOfWar : IFogOfWar
{
	mixin(xpose2(""));
	mixin xposeSerialization;

	bool isVisible(map_index_t, map_index_t)
	{
		return true;
	}
	
	bool isRectVisible(map_pos_t, vec2i)
	{
		return true;
	}

	FogOfWarState getObjectState(Object)
	{
		return FogOfWarState.Visible;
	}
	
	bool enabled()
	{
		return false;
	}
}


class FogOfWar : IFogOfWar
{
private:
	Logger logger;
	
	player_id_t player;
	
	GameObjectManager gameObjects;
	
	map_pos_t dimension;
	
	static void readDimension(FogOfWar f, Unserializer u)
	{
		u(f.dimension);
		
		f.visibleTiles.create(f.dimension.tuple);
		f.visitedTiles.create(f.dimension.tuple);
	}
	
	static void writeDimension(FogOfWar f, Serializer s)
	{
		s(f.dimension);
	}

	// arrays of visible and visited tiles
	Array2D!(bool) visibleTiles, visitedTiles;

	static void readVisitedTiles(FogOfWar f, Unserializer u)
	{
		assert(f.visitedTiles.width == f.dimension.x);
		assert(f.visitedTiles.height == f.dimension.y);
		
		for(int x = 0; x < f.dimension.x; ++x)
		{
			for(int y = 0; y < f.dimension.y; ++y)
			{
				bool t;
				u(t);
				
				f.visitedTiles[x, y] = t;
			}
		}
	}
	
	static void writeVisitedTiles(FogOfWar f, Serializer s)
	{
		foreach(bool b; f.visitedTiles.iterate)
			s(b);
	}
	
	/* cached fog of war objects. 
	   created to retain the scene nodes of objects which were removed,
	   while they were fog of war cached */
	struct CachedObject
	{
		map_pos_t mapPos;
		vec2i dimension;
		SceneNode sceneNode;
	}
	
	BufferedArray!(CachedObject) cachedObjects;

	static void readCachedObjects(FogOfWar f, Unserializer u)
	{
		int length;
		u(length);
		
		for(int i = 0; i < 0; ++i)
		{
			CachedObject c;
			u(c);
			
			f.cachedObjects.append(c);
		}
	}
	
	static void writeCachedObjects(FogOfWar f, Serializer s)
	{
		s(f.cachedObjects.length);
		
		foreach(c; f.cachedObjects)
			s(c);
	}
	
	// create a cached object if a game object gets removed
	void onRemoveObject(GameObject object)
	{
		if(object.mayBeOrdered || !object.typeInfo.fogOfWarCache ||
		   object.fogOfWarState[player] != FogOfWarState.Cached)
		{
			return;
		}
	
		logger.trace("creating cached object for {} (type `{}')", object.id, object.typeInfo.id);
	
		SceneNode sceneNode = null;
	
		if(isLocal)
		{
			logger.trace("keeping scene node");
			
			object.keepSceneNode = true;
			sceneNode = object.sceneNode;
		}
		
		cachedObjects.append(CachedObject(object.mapPos,
			object.typeInfo.dimension, sceneNode));
	}
	
	void onSimulationStep()
	{
		visibleTiles.reset();
	
		// update the visited and visible array
		foreach(o; gameObjects)
		{
			if(!o.isAlwaysVisibleTo(player))
				continue;
			
			auto sight = cast(int)(cast(real)o.property(GameObject.Property.Sight));
		
			void point(int x, int y)
			{
				if(x < 0 || y < 0 || x >= dimension.x || y >= dimension.y)
					return;
			
				visibleTiles[x, y] = true;
				visitedTiles[x, y] = true;
			}
			
			void vline(int x, int y, int w)
			{
				for(int i = 0; i < w; ++i)
					point(x + i, y);
			}
			
			void hline(int x, int y, int h)
			{
				for(int i = 0; i < h; ++i)
					point(x, y + i);
			}

			// draw a circle
			{
				sight /= 2;
			
				int f = 1 - sight;
				int ddF_x = 1;
				int ddF_y = -2 * sight;
				int x = 0;
				int y = sight;
				int x0 = o.mapPos.x + o.typeInfo.dimension.x / 2;
				int y0 = o.mapPos.y + o.typeInfo.dimension.y / 2;

				hline(x0, y0 - sight, sight * 2);
				vline(x0 - sight, y0, sight * 2);

				while(x < y) 
				{
					if(f >= 0) 
					{
						--y;
						ddF_y += 2;
						f += ddF_y;
					}
					
					++x;
					ddF_x += 2;
					f += ddF_x;

					vline(x0 - x, y0 + y, x * 2);
					vline(x0 - x, y0 - y, x * 2);
					vline(x0 - y, y0 + x, y * 2);
					vline(x0 - y, y0 - x, y * 2);
				}
			}
		}

		// check if objects are visited or visible
		loop1: foreach(o; gameObjects)
		{
			if(o.isAlwaysVisibleTo(player))
				continue;
			
			auto ti = o.typeInfo;
			auto oldState = o.fogOfWarState[player];
			
			foreach(tile; visibleTiles.iterate(o.mapPos.x, o.mapPos.y,
				ti.dimension.x, ti.dimension.y))
			{
				if(tile)
				{
					if(o.fogOfWarState[player] != FogOfWarState.Visible)
						logger.spam("visible {} (type `{}')", o.id, o.typeInfo.id);
					
					o.fogOfWarState[player] = FogOfWarState.Visible;
					continue loop1;
				}
			}

			if(o.fogOfWarState[player] == FogOfWarState.Cached)
				continue;
			
			if(o.fogOfWarState[player] != FogOfWarState.Culled)
				logger.spam("culling {} (type `{}')", o.id, o.typeInfo.id);
			
			o.fogOfWarState[player] = FogOfWarState.Culled;
			
			if(ti.fogOfWarCache && oldState == FogOfWarState.Visible)
			{
				foreach(tile; visitedTiles.iterate(o.mapPos.x, o.mapPos.y,
					ti.dimension.x, ti.dimension.y))
				{
					if(tile)
					{
						logger.spam("no, caching {} (type `{}')", o.id, o.typeInfo.id);
						
						o.fogOfWarState[player] = FogOfWarState.Cached;
						continue loop1;
					}
				}
			}
		}
		
		// check if cached objects are still needed
		loop2: foreach(i, o; cachedObjects)
		{
			foreach(tile; visibleTiles.iterate(o.mapPos.x, o.mapPos.y,
				o.dimension.x, o.dimension.y))
			{
				if(tile)
				{
					logger.trace("cached object for deleted object no longer needed");
					
					cachedObjects.remove(i);
					delete o.sceneNode;
					
					goto loop2;
				}
			}
		}
	}
	
	bool isLocal()
	{
		return gameObjects.gateway.id == player;
	}
	
public:
	mixin(xpose2(`
		dimension serial { read "readDimension"; write "writeDimension" }
		visitedTiles serial { read "readVisitedTiles"; write "writeVisitedTiles" }
		cachedObjects serial { read "readCachedObjects"; write "writeCachedObjects" }
		player
	`));
	mixin xposeSerialization;

	this()
	{
		cachedObjects.create(16);
	}
	
	void onUnserialized()
	{
		logger = Log["sim.fogofwar." ~ Integer.toString(player)];
	}
	
	// must be called once after unserialization
	package void setGameObjects(GameObjectManager gameObjects)
	{
		this.gameObjects = gameObjects;
	
		gameObjects.onRemoveObject.connect(&onRemoveObject);
		gameObjects.runner.onSimulationStep.connect(&onSimulationStep);
	}

	this(GameObjectManager gameObjects, player_id_t player, map_pos_t dimension)
	{
		this();
		
		this.player = player;
	
		logger = Log["sim.fogofwar." ~ Integer.toString(player)];
		logger.level = LogLevel.Spam;
		
		this.gameObjects = gameObjects;
		this.dimension = dimension;
		
		visibleTiles.create(dimension.tuple);
		visitedTiles.create(dimension.tuple);

		gameObjects.onRemoveObject.connect(&onRemoveObject);
		gameObjects.runner.onSimulationStep.connect(&onSimulationStep);
	}

	~this()
	{
		visibleTiles.release();
		visitedTiles.release();
		cachedObjects.release();
	}

	override bool isVisible(map_index_t x, map_index_t y)
	{
		return visibleTiles[x, y];
	}
	
	override bool isRectVisible(map_pos_t p, vec2i d)
	{
		foreach(tile; visitedTiles.iterate(p.x, p.y, d.x, d.y))
		{
			if(!tile)
				return false;
		}
		
		return true;
	}
	
	/+FogOfWarState getObjectState(Object object)
	{
		auto o = objCast!(GameObject)(object);
		auto d = o.typeInfo.dimension;
		
		foreach(tile; visitedTiles.iterate(o.mapPos.x, o.mapPos.y, d.x, d.y))
		{
			
		}
	}+/

	override bool enabled()
	{
		return true;
	}
}
