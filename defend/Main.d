module defend.Main;

import tango.math.random.Random;
import tango.util.ArgParser;
import tango.util.Convert;
import tango.core.Exception;
import tango.core.Memory;
import tango.core.Thread;
import tango.core.stacktrace.TraceExceptions;
import tango.io.Console;
import tango.io.Stdout;

import engine.core.TaskManager : TaskManager, taskManager;
import engine.math.Vector : vec2i, vec3;
import engine.input.Input : InputChannel;
import engine.input.SDL : SDLInputWriter;
import engine.rend.opengl.Renderer : OGLRenderer;
import engine.rend.Renderer : RendererConfig, Renderer, Shader, renderer;
import engine.scene.Graph : sceneGraph;
import engine.sound.openal.System : OALSystem;
import engine.sound.System : gSoundSystem;
import engine.util.Config : Config;
import engine.util.Environment : gSearchPath, SearchPath;
import engine.util.FPS : FPSCounter;
import engine.util.GameState : gameState;
import engine.util.HardwareTimer : HardwareTimer;
import engine.util.Lang : Lang;
import engine.util.Log : ConsoleAppender, FileAppender, Log, Logger, LogLevel;

import defend.Config : gDefendConfig, RuntimeException, DEFEND_CONFIG_NAME, DEFEND_DEBUG_NAME,
                       DEFEND_DEMO_NAME, DEFEND_NAME, DEFEND_VERSION;
import defend.demo.Demo : Demo;
import defend.editor.Editor : Editor;
import defend.game.Config : GameMode, GameConfig, gameConfig;
import defend.game.Game : Game;
import defend.sim.GameInfo : PlayerInfo, TerrainInfo;

import xf.hybrid.Font : FontMngr;
import xf.hybrid.Hybrid : gui;

// for build tools:
import engine.util.SigHandler;
import engine.model.MD2.Loader;
import engine.model.OBJ.Loader;
import engine.hybrid.OGLWidgets;
import defend.sim.Import;
import defend.effects.All;

import defend.terrain.Decals, defend.common.MouseBase; // tmp

class ArgumentException : Exception
{
	this(char[] msg)
	{
		super(msg);
	}
}

int main(char[][] args)
{
	GC.disable();

	Log.add(new ConsoleAppender);

	gSearchPath = new SearchPath(args);

	try
	{
		final debugPath = gSearchPath.file(DEFEND_DEBUG_NAME);

		if (Path.exists(debugPath)) {
			Path.remove(debugPath);
		}

		Log.add(new FileAppender(debugPath));
	}

	catch (Exception)
	{
	}

	final logger = Log["main"];

	// Print a header
	logger.info("{} {} (built {})", DEFEND_NAME, DEFEND_VERSION, __DATE__);

	gui.resetVfs(Path.parse(gSearchPath.find("verdana.ttf", &gSearchPath.abort)[0]).path);

	// Load the config
	{
		// Parse the arguments, but only for a config argument
		scope parser = new ArgParser((char[] value, uint ordinale)
		{
			// Ignore unhandled arguments here
		});

		char[] config;
		parser.bindPosix("config", (char[] value)
		{
			config = value;
		});

		parser.parse(args[1 .. $]);

		// Load the config
		gDefendConfig = new typeof(gDefendConfig)(
			gSearchPath.find(
				config ? config : DEFEND_CONFIG_NAME,
				&gSearchPath.abort,
				"please specify a valid path via --config"
			)[0]
		);
	}

	// Initialize the language
	Lang.load(gDefendConfig("general").string("language"));

	// Parse arguments
	{
		// Settings
		enum GameStateType { Undefined, Game, Demo, Editor }
		GameStateType gameStateType;
		char[] demoFile = gSearchPath.file(DEFEND_DEMO_NAME);
		bool showHelp = false;

		GameConfig gameConfig;
		
		// Set default values for the game config
		with(gameConfig)
		{
			// TODO: add arguments to set the terrain type
			game.terrain = TerrainInfo("four players", 128, 1337);
			//gameConfig.terrainInfo = TerrainInfo(true, "", "four players", 128, (new Random).next(1000));
			
			game.withFogOfWar = false;
			game.resources[] = 1_000_000;
			game.players.length = 1;
			game.players[GameConfig.PLAYER_INDEX] = me =
				PlayerInfo(-1, gDefendConfig("player").string("name"), 0, 0,
			               gDefendConfig("player").string("civ"));
		
			mode = GameMode.MultiPlayer;
			recordDemo = true;
			demoFile = gSearchPath.file(DEFEND_DEMO_NAME);

			with(multiplayer)
			{
				isServer = true;
				server = "localhost";
				port = gDefendConfig("net").integer("port");
			}
		}

		scope parser = new ArgParser((char[] value, uint)
		{
			logger.warn("unknown argument: {}", value);
			showHelp = true;
		});
		
		with(parser)
		{
			bindPosix("config", (char[])
			{
				// Has been handled before
			});
		
			bindPosix("h", (char[])
			{
				showHelp = true;
			});
		
			bindPosix("help", (char[])
			{
				showHelp = true;
			});
		
			bindPosix("multiplayer", (char[])
			{
				if(gameStateType != GameStateType.Undefined)
					throw new ArgumentException("conflicting arguments");
					
				gameStateType = GameStateType.Game;
			});
			
			bindPosix("singleplayer", (char[])
			{
				if(gameStateType != GameStateType.Undefined)
					throw new ArgumentException("conflicting arguments");
					
				throw new ArgumentException("singleplayer not yet supported");
			});
			
			bindPosix("play-demo", (char[] file)
			{
				if(gameStateType != GameStateType.Undefined)
					throw new ArgumentException("conflicting arguments");
				
				gameStateType = GameStateType.Demo;
				demoFile = file;
			});
			
			bindPosix("record", (char[] file)
			{
				gameConfig.recordDemo = true;
				demoFile = file;
			});
			
			bindPosix("server", (char[])
			{
				gameConfig.multiplayer.isServer = true;
			});
			
			bindPosix("host", (char[] host)
			{
				gameConfig.multiplayer.isServer = false;
				gameConfig.multiplayer.server = host;
			});
			
			bindPosix("port", (char[] port)
			{
				gameConfig.multiplayer.port = to!(uint)(port);
			});
			
			bindPosix("player-count", (char[] count)
			{
				gameConfig.game.players.length = to!(uint)(count);
				
				if(gameConfig.game.players.length == 0)
					throw new ArgumentException("need at least one player (player-count argument)");
			});
			
			bindPosix("editor", (char[])
			{
				gameStateType = GameStateType.Editor;
			});
			
			bindPosix("savegame", (char[] name)
			{
				if (!Path.exists(name)) {
					throw new ArgumentException("savegame does not exist");
				}
			
				gameConfig.game.useSaveGame = true;
				gameConfig.game.saveGame = name;
			});
		}
		
		parser.parse(args[1 .. $]);
	
		gameConfig.recordDemo = gameConfig.multiplayer.isServer;
		
		// Create a backup of the previous demo file, if there is one
		if(gameConfig.recordDemo)
		{
			if (Path.exists(gameConfig.demoFile)) {
				Path.copy(gameConfig.demoFile, gameConfig.demoFile ~ ".bak");
			}
		}
	
		// Show help?
		if(showHelp)
		{
			char[] helpText =
			"  --config=FILE\t\tuse FILE as the config instead of config.ini\n"
			"  --help\t\tshow this help text\n"
			"  --multiplayer\t\tmultiplayer mode\n"
			"  --singleplayer\tsingleplayer mode, not yet available\n"
			"  --play-demo=FILE\tplay a demo from FILE\n"
			"  --record=FILE\t\trecord a demo to FILE\n"
			"  --server\t\tcreate a server\n"
			"  --host=HOST\t\tconnect to HOST\n"
			"  --port=PORT\t\tset the port for multiplayer\n"
			"  --player-count\tnumber of players which have to connect to the server\n"
			"  --editor\t\tdirectly start the editor\n"
			"  --savegame=FILE\t\tuse a savegame";
			
			Stderr.newline;
			Stderr(helpText).newline;
			
			return 1;
		}
	
		// Evaluate the settings
		//if(gameConfig.playerCount == 1 &&
		//	gameConfig.multiplayer.isServer)
		//	gameConfig.mode = GameMode.SinglePlayer;
		
		switch(gameStateType)
		{
		case GameStateType.Demo:
			assert(demoFile !is null);
		
			logger.info("playing demo \"{}\"", demoFile);
		
			if(!Path.exists(demoFile))
				throw new ArgumentException(
					"demo file \"" ~ demoFile ~ "\" does not exist");
			
			gameState.change(new Demo(demoFile));
			
			break;
		
		case GameStateType.Editor:
			logger.info("starting editor");
			
			gameState.change(new Editor);
			
			break;
		
		case GameStateType.Game:
		default:
			if(gameConfig.recordDemo)
			{
				logger.info("recording demo \"{}\"", demoFile);
				gameConfig.demoFile = demoFile;
			}
			
			.gameConfig = gameConfig;
			gameState.change(new Game);
		}
	}

	// Mirror config settings to shader defines
	if(gDefendConfig.graphics.shadowmapping.enable)
	{
		Shader.define("SHADOWMAPPING");
		Shader.define("SHADOWMAPPING_SAMPLES",
			to!(char[])(gDefendConfig.graphics.shadowmapping.samples));
	}

	if(gDefendConfig.graphics.lighting)
		Shader.define("NORMAL_LIGHTING");
	
	if(gDefendConfig.graphics.objects_lightmap)
		Shader.define("OBJECTS_LIGHTMAP");

	if(gDefendConfig.graphics.objects_glow)
		Shader.define("OBJECTS_GLOW");

	// Create the renderer
	FontMngr.windowSize = vec2i(gDefendConfig("screen").integer("width"), gDefendConfig("screen").integer("height"));
	
	logger.info("creating renderer");

	{
		RendererConfig config;
		config.title = DEFEND_NAME;
		config.dimension = vec2i(gDefendConfig("screen").integer("width"),
		                         gDefendConfig("screen").integer("height"));
		config.fullscreen = cast(bool)gDefendConfig("screen").integer("fullscreen");

		// renderer is global
		renderer = new OGLRenderer(config);
	}

	scope(exit)
		delete renderer;

	// Create the global input channel
	logger.info("creating input manager");
	InputChannel.global = new InputChannel;
	new SDLInputWriter(InputChannel.global, renderer.window);

	// Create the sound system
	logger.info("creating sound system");
	gSoundSystem = new OALSystem();

	// Create the scene graph
	logger.info("creating scene graph");
	sceneGraph();
	
	logger.info("starting main loop");

	// Main loop
	HardwareTimer timer;
	ulong frameTime;
	
	while(!gameState.exit)
	{
		timer.start();
		
		InputChannel.global.dispatch();
		taskManager.update(cast(double)frameTime * 0.000001);

		FPSCounter.update();
		
		Thread.yield();
		
		timer.stop();
		frameTime = timer.microseconds();
	
		logger.spam("end of frame, needed {} microseconds", frameTime);
	}
	
	try
	{
		gameState.shutdown;
	}
	catch(FinalizeException e)
	{
		char[] recurse(Exception e)
		{
			return e.toString() ~ (e.file ? "(" ~ e.file ~ ":" ~ to!(char[])(e.line) ~ ")" : "") ~ (e.next ? " => " ~ recurse(e.next) : "");
		}
		
		logger.fatal("finalize exception: {}", recurse(e));
	}
	
	delete renderer;
	delete gSoundSystem;

	logger.info("program execution finished normally");
	
	return 0;
}
