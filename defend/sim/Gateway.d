module defend.sim.Gateway;

import tango.util.Convert;

import engine.math.Vector;
import engine.util.Signal;

public
{
	import defend.sim.Types;
	import defend.sim.Round;
	import defend.sim.GameInfo;
}

//debug = syncChecks;

struct SyncCheckInfo
{
	round_counter_t round;

	char[] file;
	int line;
	
	uint number;
	
	char[] toString()
	{
		return "round: " ~ to!(char[])(round) ~ "; file: " ~ file ~
		       "; line: " ~to!(char[])(line) ~ "; number: " ~ to!(char[])(number);
	}
}

abstract class Gateway
{
public:
	/* Start the gateway. This should be called after all signals have
	   been connected. */
	abstract void start();

	// Send an object message
	abstract void sendOrder(object_id_t[] targets, ubyte[] data);

	// Disconnect the gateway
	abstract void disconnect();

	// Returns the gateway's ID
	abstract player_id_t id();

	/* Update the gateway. This is the point where the signals should
	   be emitted */
	abstract void update();

	// Tell the gateway that you're ready to start the game
	abstract void ready();

	// Client has done all simulation steps of this round
	abstract void roundDone();

	// Try to start the next round, returns true if it could be started
	abstract bool startRound();
	
	/* Check that the simulation is not out of sync with other clients.
	   Note that this is only a debugging technique and is not needed in release builds. */
	abstract void checkSync(SyncCheckInfo info);
	
	final void checkSync(char[] file, uint line, int number = -1)
	{
		debug(syncChecks)
		{
			SyncCheckInfo info;
			info.file = file;
			info.line = line;
			info.number = number;
		
			checkSync(info);
		}
	}
	
	// Chat message
	Signal!(player_id_t, char[], bool) onChatMessage;

	// All players have connected and the game will start now
	Signal!() onStartGame;

	// Server has sent terrain information
	Signal!(GameInfo) onGameInfo;

	// A player has disconnected
	Signal!(player_id_t) onPlayerDisconnect;

	// The gateway has found out which ID it has
	Signal!(player_id_t) onGatewayID;

	// Emitted when the gateway shuts down
	Signal!(bool) onGatewayShutdown;

	// Start the next round
	Signal!(Round) onStartRound;
	
	// Server requested us to make a savegame
	Signal!(char[]) onMakeSaveGame;
}
