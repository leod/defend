module defend.game.net.Server;

import tango.core.Thread;
import tango.core.sync.Mutex;
import tango.net.Socket;
import tango.net.ServerSocket;
import tango.net.SocketConduit;
import Integer = tango.text.convert.Integer;

import engine.util.Log : Log, Logger, MLogger;
import engine.mem.Memory;
import engine.util.Profiler;
import engine.util.Wrapper;
import engine.math.Misc;
import engine.list.Queue;
import engine.list.MoveQueue;
import engine.net.tcp.Socket;

import defend.Config;
import defend.sim.Gateway;
import defend.game.Config;
import defend.game.net.Messages;

//debug = networking;

// -------------------------------------------------------------------
// Client handler
// -------------------------------------------------------------------
private final class ClientHandler
{
private:
	const Logger logger_;

	// Client disconnected?
	bool disconnected = false;

	// Initialization progress
	bool firstPong = false;
	bool infoReceived = false;
	bool ready = false;
	
	// Current round of the client
	round_counter_t whichRound;

	// Footex
	Mutex mutex;

	// Client info
	player_id_t id;
	PlayerInfo me;
	
	// Sync checks
	Queue!(SyncCheckInfo) syncChecks;
	Mutex syncCheckMutex;
	
	// Update thread
	Thread updateThread;
	
	// The socket
	ImmediateThreadSocket socket;

	ClientManager cm;
	NetworkServer server;
	
	// Ping info
	uint pingSent = 0;
	uint pingCount = 0;
	bool pingAnswer = true;
	
	uint lastPing = 0;
	uint lastHighestPing = 0;

	const PING_INTERVAL = 1000;

	// The background thread
	void update()
	{
		void ping()
		{
			MessagePing message;
			socket.send(message);
			
			assert(pingAnswer);
			pingAnswer = false;
			
			pingSent = getTickCount();
		}
	
		try
		{
			assert(socket !is null);
		
			logger_.info("sending ping");
			{
				ping();
			}

			logger_.info("sending my id to the client");
			{
				MessageClientID message;
				message.id = id;
				socket.send(message);
			}

			logger_.info("requesting version information");
			{
				MessageRequestVersion message;
				socket.send(message);
			}

			logger_.info("requesting info");
			{
				MessageRequestInfo message;
				socket.send(message);
			}

			while(!socket.stop)
			{
				if(server.gameStarted && getTickCount() - pingSent > PING_INTERVAL)
				{
					synchronized(mutex)
					{
						if(!pingAnswer)
						{
							if(getTickCount() - pingSent > 15_000)
								logger_.warn("pong is taking longer than 15 seconds");
							
							Thread.sleep(2);
							continue;
						}

						ping();
					}
				}

				Thread.yield();
			}
		}
		catch(Exception exception)
		{
			logger_.fatal("exception in update thread: {} ({}:{})",
			             exception, exception.file, exception.line);
			version(none) if(exception.info)
			{
				foreach(l; exception.info)
					logger_.fatal(l);
			}
		}
	}

	void disconnect()
	{
		MessagePlayerDisconnect message;
		message.id = id;

		cm.broadcast(message);
		cm.disconnect(id);
		
		/* don't wait for the read thread to finish,
		   since that's where this function call is coming from */
		socket.release(false, true);
		
		// Also stop the update thread
		updateThread.join();
		
		updateThread = null;
		socket = null;
	}
	
	// Message handlers
	void onPing(MessagePing* message)
	{
		MessagePong messageOut;
		socket.send(messageOut);	
	}
	
	void onPong(MessagePong* message)
	{
		synchronized(mutex)
		{
			//Trace.formatln("(pong got called)");
		
			lastPing = getTickCount() - pingSent;
			
			assert(!pingAnswer);
			pingAnswer = true;

			if(!firstPong) firstPong = true;

			lastHighestPing = lastPing;
			
			//logger.info("ping: {}", lastPing);
		}
	}
	
	void onSendInfo(MessageSendInfo* message)
	{
		me = message.info;
		me.exists = true;
		me.id = id;
		me.color = id; // long-term tmp
		
		logger_.info("received info: {}", me.toString());

		infoReceived = true;	
	}
	
	void onSendVersion(MessageSendVersion* message)
	{
		logger_.info("client has version {}.{}.{}", message.major, message.minor, message.patch);

		if(message.major != DEFEND_VERSION_MAJOR ||
		   message.minor != DEFEND_VERSION_MINOR ||
		   message.patch != DEFEND_VERSION_PATCH)
		{
			// TODO: What should we do in this case?
			logger_.warn("version unknown");
		}	
	}

	void onReadyToStart(MessageReadyToStart* message)
	{
		logger_.info("ready");
	
		ready = true;	
	}

	void onOrder(MessageOrder* message)
	{
		synchronized(server.roundMutex)
		{
			debug(networking) 
				logger_.info("received order for round {}", message.round);
			
			if(message.round < server.currentRound)
			{
				debug(networking)
					logger_.info("need to adjust order's round from {} to {}",
				                 message.round,
				                 server.currentRound + cast(round_counter_t)1);
				
				message.round = server.currentRound + cast(round_counter_t)1;
			}
			
			// Broadcast the order
			cm.broadcast(*message);
		}	
	}
	
	void onClientDisconnect(MessageClientDisconnect* message)
	{
		logger_.info("client disconnected");

		disconnect();	
	}
	
	void onRoundDone(MessageRoundDone* message)
	{
		synchronized(server.roundMutex)
		{
			debug(networking)
				logger_.info("round {} done", message.which);
			
			// Check that we don't skip any rounds
			assert(message.which - whichRound == 1 ||
				   (message.which == 0 && whichRound == 0));
			
			whichRound = message.which;
		}	
	}
	
	void onSyncCheck(MessageSyncCheck* message)
	{
		if(cm.numberClients == 1)
			return;
	
		synchronized(syncCheckMutex)
			syncChecks.push(message.info);
		
		version(none) debug(networking)
			logger_.spam("check({}:{}): {}",
						message.info.file, message.info.line,
						message.info.number);	
	}
	
	// Disconnect handler
	void onDisconnect()
	{
		MessagePlayerDisconnect message;
		message.id = id;

		cm.disconnect(id);
		cm.broadcast(message);
	}
	
public:
	mixin MAllocator;

	this(player_id_t id, ClientManager cm,
	     SocketConduit conduit, NetworkServer server)
	{
		this.id = id;
		this.cm = cm;
		this.server = server;
		
		mutex = new Mutex;
		
		syncChecks.create(2000);
		syncCheckMutex = new Mutex;
		
		logger_ = Log["server.client.handler." ~ Integer.toString(id)];
		logger_.info("new client ({})", conduit.socket.remoteAddress);
		
		socket = new typeof(socket);
		socket.start(logger_, conduit);
		
		with(socket)
		{
			setMessageHandlers(&onPing,
				&onPong,
				&onSendInfo,
				&onSendVersion,
				&onReadyToStart,
				&onOrder,
				&onClientDisconnect,
				&onRoundDone,
				&onSyncCheck);
			
			setDisconnectHandler(&onDisconnect);
		}
		
		updateThread = new Thread(&update);
		updateThread.start();
	}
	
	~this()
	{
		syncChecks.release();
	}
	
	void release()
	{
		if(!socket || socket.stop)
		{
			logger_.warn("trying to release twice");
			return;
		}
		
		socket.release();
		updateThread.join();
		
		socket = null;
		updateThread = null;
	}
}

// ------------------------------------------------------------------------------------------------
// Client manager
// ------------------------------------------------------------------------------------------------
private final class ClientManager
{
	mixin MLogger;

private:
	uint _numberClients;

	ClientHandler[] clients;

public:
	this()
	{
		logger_.info("client manager initialized");
	}

	~this()
	{
		foreach(client; clients)
		{
			if(client)
				delete client;
		}
	}

	synchronized uint numberClients()
	{
		return _numberClients;
	}

	synchronized void spawn(player_id_t id, SocketConduit socket, NetworkServer server)
	{
		logger_.info("spawning client with id {}", id);
		
		if(id >= clients.length || id == 0) clients.length = id + 1;
		
		assert(numberClients < MAX_PLAYERS);
		_numberClients++;
		
		clients[id] = new ClientHandler(id, this, socket, server);
	}
	
	synchronized void disconnect(uint id)
	{
		assert(numberClients > 0);
		_numberClients--;
		
		clients[id].disconnected = true;
	}

	synchronized ClientHandler get(uint id)
	{
		return clients[id];
	}
	
	synchronized ClientHandler[] get()
	{
		return clients;
	}
	
	synchronized int opApply(int delegate(ref ClientHandler) dg)
	{
		int result = 0;
		
		foreach(client; clients)
		{
			if(!client || client.disconnected) continue;
			
			if(cast(bool)(result = dg(client)))
				break;
		}
		
		return result;
	}
	
	void broadcast(T)(T message)
	{
		synchronized(this)
		{
			foreach(client; this)
				client.socket.send(message);
		}
	}
}

// ------------------------------------------------------------------------------------------------
// Server
// ------------------------------------------------------------------------------------------------
final class NetworkServer : Thread
{
	mixin MLogger;
private:
	GameConfig config;

	ServerSocket listener;
	ClientManager cm;

	bool stop = false;
	
	ushort roundLength;
	ushort simulationSteps;
	
	// Wait for clients
	void accept()
	{
		logger_.info("accepting clients");
		
		// TODO: Create some timeout here
		for(uint i = 0; i != config.game.players.length; ++i)
		{
			cm.spawn(cast(player_id_t)i, listener.accept(), this);
		}
		
		logger_.info("all clients have connected");
	}
	
	// Start the next round
	void startRound(round_counter_t which, ushort _roundLength, ushort _simulationSteps)
	{
		debug(networking)
			logger_.info("starting round {} ({}, {})", which, _roundLength, _simulationSteps);
		
		MessageStartRound message;
		message.which = which;
		message.length = roundLength = _roundLength;
		message.simulationSteps = simulationSteps = _simulationSteps;
		
		cm.broadcast(message);
		
		++currentRound;
		
		//debug(networking)
		//	logger.info("current round now {}", currentRound);
	}
	
	// Initialize connections and broadcast initial game data
	void init()
	{
		// Wait for all clients to connect
		accept();

		// Wait for first ping
		logger_.info("waiting for all clients to answer the first ping");
		WaitPings: while(true)
		{
			Thread.yield();
			
			foreach(client; cm)
				if(!client.firstPong) continue WaitPings;
				
			break;
		}

		// Wait for client info (nick, civ, etc...)
		logger_.info("waiting for all clients to have sent their info");
		WaitNicks: while(true)
		{
			Thread.yield();
			
			foreach(client; cm)
				if(!client.infoReceived) continue WaitNicks;
				
			break;
		}

		// Broadcast game infos
		logger_.info("broadcasting game info");
		
		assert(config.game.players.length == cm.numberClients);
		
		int i = 0;
		foreach(client; cm)
		{
			config.game.players[i] = client.me;
			
			++i;
		}
		
		//logger.info("dude");
		cm.broadcast(MessageGameInfo(config.game));
		
		// Wait for clients to be ready
		logger_.info("waiting for all clients to be ready");
		WaitReady: while(true)
		{
			Thread.yield();
			
			foreach(client; cm)
				if(!client.ready) continue WaitReady;
				
			break;
		}
		
		logger_.info("everybody is ready");

		// Start the game
		logger_.info("starting game now");
		{
			MessageStartGame message;
			cm.broadcast(message);
		}
		
		gameStarted = true;

		// Start first round
		synchronized(roundMutex)
			startRound(0, MIN_ROUND_LENGTH, numberSimulationSteps(MIN_ROUND_LENGTH));
	}
	
	// Check for out of sync
	void compareSyncChecks()
	{
		if(cm.numberClients == 1)
			return;
			
		foreach(client; cm)
			client.syncCheckMutex.lock();
			
		scope(exit)
		{
			foreach(client; cm)
				client.syncCheckMutex.unlock();
		}
		
		ClientHandler firstClient;
			
		foreach(client; cm)
		{
			firstClient = client;
			break;
		}

		while(firstClient.syncChecks.count)
		{
			SyncCheckInfo info;

			{
				info = firstClient.syncChecks.top();
				
				if(info.round > minRound)
					break;
					
				firstClient.syncChecks.pop();
			}
			
			foreach(client; cm)
			{
				if(client is firstClient)
					continue;
				
				auto check = client.syncChecks.pop();
				
				if(check.round != info.round ||
				   check.line != info.line ||
				   check.number != info.number)
				{
					logger_.fatal("out of sync: {} vs. {}", check, info);
					assert(false);
				}
			}
		}
	}
	
	// Calculates the number of simulation steps for a round's length
	ushort numberSimulationSteps(ushort length)
	out(result)
	{
		//logger.info("steps: {}; length: {}", result, length);
		assert(result > 0);
	}
	body
	{
		//return 1;
		return cast(ushort)(SIMULATION_STEPS_PER_SECOND / (1000.0f / length));
	}

	ushort calcRoundLength()
	{
		return min(MAX_ROUND_LENGTH, max(MIN_ROUND_LENGTH, maxPing));
	}

	const uint MIN_ROUND_LENGTH = 100;
	const uint MAX_ROUND_LENGTH = 1000;
	const uint SIMULATION_STEPS_PER_SECOND = 10;

	void run()
	{
		try
		{
			init();
			
			while(!stop)
			{
				Thread.yield();
				
				synchronized(roundMutex) if(currentRound - minRound() <= 2)
				{
					compareSyncChecks();
					
					int length = calcRoundLength();
	
					startRound(currentRound, length,
					           numberSimulationSteps(length));
				}
			}
		}
		catch(Exception exception)
		{
			logger_.fatal("exception in main thread: {} ({}:{})",
			             exception, exception.file, exception.line);
			version(none) if(exception.info)
			{
				foreach(l; exception.info)
					logger_.fatal(l);
			}
		}
	}
	
	Mutex roundMutex;

	// This actually is the _next_ round which will be started
	round_counter_t currentRound;
	
	bool gameStarted = false;
	
	round_counter_t minRound()
	{
		round_counter_t result = round_counter_t.max;
		
		foreach(client; cm)
			result = min(result, client.whichRound);
			
		return result;
	}
	
	uint maxPing()
	{
		uint result = 0;
		
		foreach(client; cm)
			result = max(result, client.lastHighestPing);
			
		return result;
	}

public:
	this(GameConfig config)
	{
		this.config = config;
		
		cm = new ClientManager();
		roundMutex = new Mutex();

		logger_.info("creating server socket on port {}", config.multiplayer.port);
		
		bool loop = true;
		
		const tryCount = 10;
		uint tries = tryCount;
		
		while(loop)
		{
			try
			{
				listener = new ServerSocket(new InternetAddress(config.multiplayer.port), 32, true);
				loop = false;
			}
			catch(Exception exception)
			{
				logger_.warn("failed to create server socket: {} ({}/{})", exception, tries, tryCount);
				
				if((loop = --tries > 0) == 0)
					throw exception;
			}
		}
		
		assert(listener !is null);
			
		logger_.info("server socket created");

		super(&run);
		
		logger_.info("starting background thread");
		start();
		logger_.info("initialized");
	}
	
	~this()
	{
		assert(stop, "shutdown() must get called before the destructor");
		
		delete cm;
	}
	
	void shutdown()
	{
		logger_.info("shutting down");
		
		MessageServerShutdown message;
		cm.broadcast(message);
		
		stop = true;
		join();

		foreach(client; cm)
			client.release();
		
		listener.socket.shutdown(SocketShutdown.BOTH);
		listener.socket.detach();
		
		logger_.info("shutting down was successful");
	}
	
	void makeSaveGame(char[] name)
	{
		MessageMakeSaveGame message;
		message.when = currentRound;
		message.name = name;
		
		cm.broadcast(message);
	}
}
