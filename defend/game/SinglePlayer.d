module defend.game.SinglePlayer;

import engine.core.TaskManager;
import engine.util.Swap;
import engine.util.Log : MLogger;
import engine.util.Debug;

import defend.sim.Gateway;
import defend.sim.Round;
import defend.game.Config;

// not threading safe yet

class SinglePlayerServer
{
	mixin MLogger;

private:
	GameConfig gameConfig;
	SinglePlayerClient[] clients;
	
	Round previousRound;
	Round currentRound;
	
	const roundLength = 100;
	
	void startRound()
	{
		foreach(client; clients)
		{
			if(!client.finishedRound)
				return;
		}
		
		foreach(client; clients)
			client.mayStartRound = true;
		
		logger_.trace("allowing to start round");
		
		currentRound.length = roundLength;
		currentRound.simulationSteps = 1;
		
		foreach(client; clients)
			client.round = currentRound;
		
		swap(previousRound, currentRound);
		currentRound.reset();
		
		++previousRound.whichRound;
	}
	
public:
	this(GameConfig gameConfig)
	{
		assert(false, "buggy");
	
		this.gameConfig = gameConfig;
		
		foreach(i, player; gameConfig.game.players)
		{
			player.exists = true;
			player.id = i;
			
			clients ~= new SinglePlayerClient(this, player);
		}
		
		OrderData.memoryPool.create(100);
		
		previousRound = new Round;
		currentRound = new Round;
		
		taskManager.addRepeatedTask(&startRound, 100);
	}
	
	~this()
	{
		delete previousRound;
		delete currentRound;
	
		OrderData.memoryPool.release();
	}
	
	Gateway getGateway(char[] playerName)
	{
		foreach(client; clients)
		{
			if(client.info.nick == playerName)
				return client;
		}
		
		assert(false);
	}
	
	void start()
	{
		foreach(gateway; clients)
		{
/+			foreach(client; clients)
				gateway.PlayerListEntry(client.config.info);
				
			gateway.TerrainInfo(gameConfig.terrainInfo);+/
			assert(false);
			gateway.onStartGame();
		}
	}
}

private class SinglePlayerClient : Gateway
{
	mixin MLogger;

	SinglePlayerServer server;
	PlayerInfo info;

	bool mayStartRound = false;
	bool finishedRound = true;
	Round round;

	this(SinglePlayerServer server, PlayerInfo info)
	{
		this.server = server;
		this.info = info;
	}
	
	override player_id_t id()
	{
		return info.id;
	}
	
	override void start()
	{
	
	}
	
	override void sendOrder(object_id_t[] targets, ubyte[] data)
	{
		logger_.trace("pushing order to {}", server.currentRound.whichRound);
	
		//assert(round is server.previousRound);
		server.currentRound.push(targets, data);
	}

	override void disconnect()
	{
		
	}

	override void update()
	{
		
	}

	override void ready()
	{
		
	}

	override void roundDone()
	{
		finishedRound = true;
	}

	override bool startRound()
	{
		if(!round)
			return false;
		
		if(!mayStartRound)
			return false;
		
		assert(round is server.previousRound);
		
		logger_.trace("starting round {} with {} orders", round.whichRound, round.count);
		
		onStartRound(round);
		
		finishedRound = false;
		mayStartRound = false;
		round = null;
		
		return true;
	}
	
	override void checkSync(SyncCheckInfo info)
	{
	
	}
}
