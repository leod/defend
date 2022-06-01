module defend.sim.GameInfo;

import Integer = tango.text.convert.Integer;

import xf.xpose2.Expose;
import xf.xpose2.Serialization;

public
{
	import defend.sim.Resource;
}

alias short player_id_t;
alias ubyte player_color_t;
alias ubyte player_team_t;

const player_id_t NEUTRAL_PLAYER = -1;

struct PlayerInfo
{
	bool exists;

	player_id_t id;
	player_color_t color;
	player_team_t team;
	char[] civ;

	char[] nick;

	static PlayerInfo opCall(player_id_t id, char[] nick,
	                         player_color_t color, player_team_t team,
	                         char[] civ)
	{
		PlayerInfo result;
		result.id = id;
		result.nick = nick;
		result.color = color;
		result.team = team;
		result.civ = civ;

		return result;
	}
	
	char[] toString()
	{
		return "id = " ~ Integer.toString(id) 
		 ~ "; nick = " ~ nick
		 ~ "; team = " ~ Integer.toString(team)
		  ~ "; civ = " ~ civ;
	}
	
	mixin(xpose2("
		exists | id | color | team | civ | nick
	"));
	mixin xposeSerialization;
}

struct TerrainInfo
{
	bool isRandom;
	
	//union
	//{
		// not random
		char[] file;
		
	//	struct
	//	{
			// random
			char[] generatorType;
			ushort dimension;
			ushort seed;
	//	}
	//}
	
	static TerrainInfo opCall(char[] generatorType, ushort dimension, ushort seed)
	{
		TerrainInfo result;
		result.isRandom = true;
		result.generatorType = generatorType;
		result.dimension = dimension;
		result.seed = seed;
		
		return result;
	}
	
	mixin(xpose2("
		isRandom
		file
		generatorType | dimension | seed
	"));
	mixin xposeSerialization;
}

struct GameInfo
{
	bool isMapSave;

	bool useSaveGame;
	
	//union
	//{
	//	struct
	//	{
			TerrainInfo terrain;
			int speed;
			ResourceArray resources; // initial resources
			PlayerInfo[] players;
			bool withFogOfWar;
	//	}
		
		char[] saveGame; // saveGame == map
	//}
	
	mixin(xpose2("
		useSaveGame
		terrain | speed | resources | players | withFogOfWar
		saveGame
	"));
	mixin xposeSerialization;
}
