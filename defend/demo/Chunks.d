module defend.demo.Chunks;

import defend.Config;
import defend.sim.Types;
import defend.sim.GameInfo;

align(1):

enum ChunkType : ubyte
{
	GameInfo,
	StartGame,
	CreateObject,
	Order,
	StartRound
}

struct ChunkHeader
{
	typeof(ChunkType.init) type;
	uint length;
}

struct ChunkGameInfo
{
	GameInfo info;
}

struct ChunkStartGame
{
	uint urmum = 42;
}

struct ChunkOrder
{
	object_id_t[] targets;
	ubyte[] order;
}

struct ChunkStartRound
{
	ushort length;
	ushort simulationSteps;
}
