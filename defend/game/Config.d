module defend.game.Config;

import defend.sim.GameInfo;
import defend.Config;

enum GameMode
{
	SinglePlayer,
	MultiPlayer
}

struct SinglePlayerConfig
{

}

struct MultiPlayerConfig
{
	bool isServer = false;
	char[] server = "";
	uint port = 0;
}

struct GameConfig
{
	GameMode mode;
	bool recordDemo = false;
	char[] demoFile;
	
	const PLAYER_INDEX = 0; // index of the server's player in the game.players array
	GameInfo game;
	PlayerInfo me;

	union
	{
		SinglePlayerConfig singleplayer;
		MultiPlayerConfig multiplayer;
	}
}

GameConfig gameConfig;
