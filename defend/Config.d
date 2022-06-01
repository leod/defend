module defend.Config;

import engine.math.Vector : vec3;
import engine.util.Config : CachedConfig;
import engine.util.Meta : toString;

const DEFEND_NAME = "Defend";
const DEFEND_CONFIG_NAME = "defend.cfg";
const DEFEND_DEMO_NAME = "demo.ddm";
const DEFEND_DEBUG_NAME = "debug.log";

enum {
	DEFEND_VERSION_MAJOR = 0,
	DEFEND_VERSION_MINOR = 0,
	DEFEND_VERSION_PATCH = 0,
	MAX_PLAYERS = 8,
	MAX_TEAMS = MAX_PLAYERS,
	MAX_NICK_LENGTH = 16,
	MAX_MSG_LENGTH = 256,
	MAX_OBJECT_NUMBER = 1000,
	MAX_ORDERED_OBJECTS = 200,
	MAX_COLORS = 8,
	HUD_HEIGHT = 150,
}

const DEFEND_VERSION = toString(DEFEND_VERSION_MAJOR) ~
	                 "." ~
	                 toString(DEFEND_VERSION_MINOR) ~
	                 "." ~
	                 toString(DEFEND_VERSION_PATCH);

// FIXME: Look at initialization syntax
vec3 playerColors[MAX_COLORS];

static this()
{
	playerColors[0] = vec3(0, 0, 1);
	playerColors[1] = vec3(1, 0, 0);
	playerColors[2] = vec3(0, 0, 1);
	playerColors[3] = vec3(1, 0, 1);
	playerColors[4] = vec3(1, 1, 0);
	playerColors[5] = vec3(0, 1, 1);
	playerColors[6] = vec3(0, 0, 0);
	playerColors[7] = vec3(1, 1, 1);
}

// catchable
class RuntimeException : Exception
{
	this(char[] msg)
	{
		super(msg);
	}
}

CachedConfig!("int graphics.shadowmapping.enable;"
			  "int graphics.shadowmapping.size;"
              "int graphics.shadowmapping.samples;"
              "int graphics.lighting;"
              "int graphics.objects_lightmap;"
              "int graphics.objects_glow;"
              "int graphics.terrain_use_shaders;") gDefendConfig;
