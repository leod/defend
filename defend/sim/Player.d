module defend.sim.Player;

import xf.xpose2.Expose;
import xf.xpose2.Serialization;

import engine.util.Log : MLogger;

import defend.sim.Gateway;
import defend.sim.IFogOfWar;

class Player
{
private:
	ResourceArray _resources;
	
	struct Statistics
	{
		int mouseClicks;
		ResourceArray collectedResources;
		int usedResources;
	}
	
	Statistics stats; // TODO: player statistics
	
public:
	PlayerInfo info;
	IFogOfWar fogOfWar;
	
	~this()
	{
		delete fogOfWar;
	}
	
	int[] resources() { return _resources[]; }
	
	bool canBuy(ResourceArray cost)
	{
		foreach(i, c; cost)
		{
			if(c > _resources[i])
				return false;
		}
	
		return true;
	}
	
	bool tryBuy(ResourceArray cost)
	{
		if(!canBuy(cost))
			return false;
		
		buy(cost);
		
		return true;
	}
	
	void buy(ResourceArray cost)
	{
		assert(canBuy(cost));
		
		for(uint i = 0; i < _resources.length; ++i)
			resources[i] -= cost[i];
	}
	
	void addResource(ResourceType type, int amount)
	{
		_resources[type] += amount;
	}
	
	void addResources(ResourceArray res)
	{
		for(uint i = 0; i < _resources.length; ++i)
			_resources[i] += res[i];
	}
	
	char[] toString()
	{
		return info.toString();
	}
	
	mixin(xpose2("
		info
		_resources
		fogOfWar
	"));
	mixin xposeSerialization;
}

class PlayerManager
{
	mixin MLogger;

protected:
	this() {}

	Player[] players;
	
	Gateway gateway;

	// Slots
	void onPlayerDisconnect(player_id_t id)
	{
		logger_.info("player {} disconnected", id);

		assert(isPlayer(id), "player doesn't exist, though");
		players[id] = null;
	}
	
package:
	void onGameInfo(GameInfo info) // called by Simulation
	{
		if(info.useSaveGame)
			return;
	
		foreach(p; info.players)
		{
			assert(p.exists);
			
			if(players.length <= p.id)
				players.length = p.id + 1;
			
			//logger.warn("{} vs {}", players.length, p.id);
			
			players[p.id] = new Player;
			players[p.id].info = p;
			
			players[p.id].resources[] = info.resources[];

			logger_.info("player: {}", p.toString());
		}
	}

public:
	this(Gateway gateway)
	{
		this.gateway = gateway;

		//gateway.onGameInfo.connect(&onGameInfo);
		gateway.onPlayerDisconnect.connect(&onPlayerDisconnect);
	}
	
	~this()
	{
		foreach(player; players)
			delete player;
	}

	bool isPlayer(player_id_t id)
	{
		return id >= 0 && id < players.length && players[id] !is null;
	}

	Player opIndex(player_id_t id)
	in
	{
		assert(isPlayer(id), "player " ~ Integer.toString(id) ~ " doesn't exist"); 
	}
	out(result)
	{
		assert(result !is null);
		assert(result.info.exists);
		assert(result.info.id == id);
	}
	body
	{
		return players[id];
	}

	int opApply(int delegate(ref Player) dg)
	{
		int result = 0;
		
		foreach(player; players)
		{
			if(cast(bool)(result = dg(player)))
				break;
		}
		
		return result;
	}
	
	mixin(xpose2("
		players
	"));
	mixin xposeSerialization;
	
	void onUnserialized()
	{
		logger_.info("players: {}", players);
	}
}
