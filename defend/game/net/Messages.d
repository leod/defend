module defend.game.net.Messages;

import engine.net.tcp.Message;

import defend.Config;
import defend.sim.Gateway : SyncCheckInfo;
import defend.sim.Round : round_counter_t;
import defend.sim.Types;
import defend.sim.GameInfo;

align(1):

struct MessagePing // client <-> server
{
	mixin MMessage!(MessagePing);
}

struct MessagePong // client <-> server
{
	mixin MMessage!(MessagePong);
}

struct MessageSay
{
	mixin MMessage!(MessageSay);
	
	char[] text;
}

struct MessageClientDisconnect // client -> server
{
	mixin MMessage!(MessageClientDisconnect);
}

struct MessagePlayerDisconnect // server -> client
{
	mixin MMessage!(MessagePlayerDisconnect);
	
	player_id_t id;
}

struct MessageServerShutdown // server -> client
{
	mixin MMessage!(MessageServerShutdown);
}

struct MessageRequestVersion // server -> client
{
	mixin MMessage!(MessageRequestVersion);
}

struct MessageSendVersion // client -> server
{
	mixin MMessage!(MessageSendVersion);
	
	ushort major;
	ushort minor;
	ushort patch;
}

struct MessageRequestInfo // server -> client
{
	mixin MMessage!(MessageRequestInfo);
}

struct MessageSendInfo // client -> server
{
	mixin MMessage!(MessageSendInfo);
	
	PlayerInfo info;
}

struct MessageClientID // server -> client
{
	mixin MMessage!(MessageClientID);
	
	player_id_t id;
}

struct MessageStartRound // server -> client
{
	mixin MMessage!(MessageStartRound);
	
	round_counter_t which;
	
	ushort length; // Length in MS
	ushort simulationSteps;
}

struct MessageReadyToStart // client -> server
{
	mixin MMessage!(MessageReadyToStart);
}

struct MessageGameInfo // server -> client
{
	mixin MMessage!(MessageGameInfo);
	
	GameInfo info;
}

struct MessageOrder // client <-> server
{
	mixin MMessage!(MessageOrder);
	
	round_counter_t round;
	
	object_id_t[] targets;
	ubyte[] order;
}

struct MessageStartGame // server -> client
{
	mixin MMessage!(MessageStartGame);
}

struct MessageRoundDone // client -> server
{
	mixin MMessage!(MessageRoundDone);
	
	round_counter_t which;
}

struct MessageSyncCheck // client -> server
{
	mixin MMessage!(MessageSyncCheck);
	
	SyncCheckInfo info;
}

struct MessageMakeSaveGame // server -> client
{
	mixin MMessage!(MessageMakeSaveGame);
	
	round_counter_t when; // make savegame at end of the round 'when'
	char[] name;
}
