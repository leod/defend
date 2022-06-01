module defend.game.net.Client;

import tango.core.Thread;
import tango.net.Socket;
import tango.net.SocketConduit;
import tango.net.InternetAddress;
import tango.text.Util;
import Integer = tango.text.convert.Integer;

import engine.util.Swap;
import engine.util.Log : MLogger;
import engine.util.Signal;
import engine.util.Wrapper;
import engine.mem.Memory;
import engine.util.Profiler;
import engine.list.Queue;
import engine.list.MoveQueue;
import engine.math.Vector;
import engine.net.tcp.Socket;

import defend.Config;
import defend.game.Config;
import defend.sim.Gateway;
import defend.sim.Round : Round;
import defend.sim.GameInfo;
import defend.game.net.Messages;

//debug = networking;

final class NetworkClient : Gateway
{
	mixin MLogger;
private:
	PlayerInfo me;
	
	char[] _address;
	uint _port;

	bool serverDisconnect = false;

	uint lastPing = 0;
	uint pingStart = 0;
	uint pingTime = 0;
	bool pongReceived = true;

	QueueThreadSocket socket;

	player_id_t _id;

	round_counter_t round = -1;
	MoveQueue!(Round) roundQueue;

	bool makeSaveGame;
	round_counter_t saveGameTime;
	char[] saveGameName;
	
	Round getRound(round_counter_t which)
	{
		foreach(entry; roundQueue)
		{
			if(entry.whichRound == which)
				return entry;
		}
		
		return null;
	}

	// Message handlers
	void onPing(MessagePing* message)
	{
		lastPing = getTickCount();
		pongReceived = true;

		MessagePong messageOut;
		socket.send(messageOut);
		
		//logger.trace("sending pong");
	}
	
	void onPong(MessagePong* message)
	{
		lastPing = getTickCount();
		pingTime = getTickCount() - pingStart;
	}
	
	void onRequestVersion(MessageRequestVersion* message)
	{
		logger_.info("version information requested");

		MessageSendVersion messageOut;
		
		with(messageOut)
		{
			major = DEFEND_VERSION_MAJOR;
			minor = DEFEND_VERSION_MINOR;
			patch = DEFEND_VERSION_PATCH;
		}

		socket.send(messageOut);

		logger_.info("version information sent");	
	}
	
	void onRequestInfo(MessageRequestInfo* message)
	{
		logger_.info("nickname requested");

		MessageSendInfo messageOut;
		messageOut.info = me;

		socket.send(messageOut);

		logger_.info("nickname sent");	
	}
	
	void onGameInfo(MessageGameInfo* message)
	{
		//TerrainInfo(message.info);	
		super.onGameInfo(message.info);
	}
	
	void onOrder(MessageOrder* message)
	{
		assert(message.round >= roundQueue.first.whichRound);
		assert(message.round <= roundQueue.last.whichRound);
		
		Round whichRound = getRound(message.round);
		assert(whichRound !is null);
		assert(whichRound.whichRound == message.round);
		
		whichRound.push(message.targets, message.order);

		debug(networking)
			logger_.info("received order for round {}", message.round);	
	}
	
	void onStartRound(MessageStartRound* message)
	{
		Round whichRound = getRound(message.which);
		assert(whichRound !is null);
		assert(whichRound.whichRound == message.which);

		debug(networking)
			logger_.info("may start round {}. length: {}; steps: {}",
						message.which,
						whichRound.length,
						whichRound.simulationSteps);

		assert(message.which >= roundQueue.first.whichRound, "too early");
		assert(message.which <= roundQueue.last.whichRound, "too late");
		
		debug(networking) if(message.which > roundQueue[2].whichRound)
			logger_.warn("may start round message is early ({}/{})",
						message.which, roundQueue.first.whichRound);

		whichRound.length = message.length;
		whichRound.simulationSteps = message.simulationSteps;
		whichRound.mayBeStarted = true;	
	}
	
	void onClientID(MessageClientID* message)
	{
		_id = message.id;

		onGatewayID(id);

		logger_.info("my id is {}", id);	
	}

	void onPlayerDisconnect(MessagePlayerDisconnect* message)
	{
		if(message.id == _id)
			return;
		
		logger_.info("player {} disconnected", message.id);
		
		super.onPlayerDisconnect(message.id);		
	}
	
	void onServerShutdown(MessageServerShutdown* message)
	{
		serverDisconnect = true;
		onGatewayShutdown(false);	
	}
	
	void onStartGame(MessageStartGame* message)
	{
		serverDisconnect = true;
		super.onStartGame();
	}
	
	void onMakeSaveGame(MessageMakeSaveGame* message)
	{
		logger_.info("server requested to make savegame {} at end of round {}", message.name, message.when);
	
		makeSaveGame = true;
		saveGameTime = message.when;
		saveGameName = message.name.dup;
		
		assert(saveGameTime >= round);
	}
	
	// Disconnect handler
	void onDisconnect()
	{
		onGatewayShutdown(true);
	}
	
public:
	mixin MAllocator;
	
	char[] address() { return _address; }
	uint port() { return _port; }
	override player_id_t id() { return _id; }

	this(char[] _address, uint _port, PlayerInfo me)
	{
		this._address = _address;
		this._port = _port;
		this.me = me;

		roundQueue.create(20);
		
		round_counter_t i;
		foreach(ref entry; roundQueue)
		{
			entry = new Round;
			entry.whichRound = i;
			i++;
		}
		
		OrderData.memoryPool.create(100);
		
		with(socket = new typeof(socket))
		{
			setMessageHandlers(&onPing,
				&onPong,
				&onRequestVersion,
				&onRequestInfo,
				&onGameInfo,
				&onOrder,
				&onStartRound,
				&onClientID,
				&onPlayerDisconnect,
				&onServerShutdown,
				&onStartGame,
				&onMakeSaveGame);
		
			setDisconnectHandler(&onDisconnect);
		}
	}
	
	~this()
	{
		foreach(entry; roundQueue)
			delete entry;
		
		roundQueue.release();
		
		OrderData.memoryPool.release();
	}

	override void start()
	{
		logger_.info("connecting to {}:{}", address, port);

		SocketConduit s = new SocketConduit();
		s.connect(new InternetAddress(address, cast(ushort)port));

		logger_.info("connection created");

		socket.start(logger_, s);
	}

	override void sendOrder(object_id_t[] targets, ubyte[] data)
	{
		ubyte[1024] buffer = void;
		uint offset = 0;

		MessageOrder message;
		message.round = round + cast(round_counter_t)2;
		message.targets = targets;
		message.order = data;
		
		socket.send(message);
	}
	
	override void disconnect()
	{
		if(!serverDisconnect && socket !is null)
		{
			MessageClientDisconnect message;
			socket.send(message);
		}

		socket.release();
	}

	override void update()
	{
		profile!("gateway.update")
		({
			socket.dispatch();
			
			// Ping
			if(pongReceived && getTickCount() - lastPing > 10000)
			{
				MessagePing message;
				socket.send(message);

				lastPing = pingStart = getTickCount();
				pongReceived = false;
			}
		});
	}

	override void ready()
	{
		logger_.info("ready");
		
		MessageReadyToStart message;
		socket.send(message);
	}

	override void roundDone()
	{
		debug(networking)
			logger_.info("round {} done", round);
		
		MessageRoundDone message;
		message.which = round;
		
		socket.send(message);
		
		//startRound();
		
		if(makeSaveGame && round == saveGameTime)
		{
			super.onMakeSaveGame(saveGameName);
			makeSaveGame = false;
		}
	}
	
	override bool startRound()
	{
		if(!roundQueue.first.mayBeStarted)
			return false;
		
		round++;
		
		debug(networking)
			logger_.info("starting round {} with {} orders, {} length, {} steps",
			            roundQueue.first.whichRound,
			            roundQueue.first.count,
			            roundQueue.first.length,
			            roundQueue.first.simulationSteps);
		
		//debug if(roundQueue.first.whichRound % 30 == 0)
		//	logger.trace("round length: {}", roundQueue.first.length);
		
		super.onStartRound(roundQueue.first);

		roundQueue.first.reset();
		roundQueue.pop();
		roundQueue.last.whichRound = roundQueue[roundQueue.length - 2].whichRound +
					     cast(round_counter_t)1;
					     
		return true;
	}
	
	override void checkSync(SyncCheckInfo info)
	{
		info.round = round;
	
		MessageSyncCheck message;
		message.info = info;
		
		socket.send(message);
	}
}
