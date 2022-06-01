module defend.game.Game;

import tango.core.Memory;
import tango.core.Thread;
import tango.io.Console;
import tango.io.Stdout;
import tango.util.Convert;
import tango.time.WallClock : Clock = WallClock;
import tango.text.convert.Format;
import Integer = tango.text.convert.Integer;

import engine.core.TaskManager;
import engine.math.Vector;
import engine.input.Input;
import engine.rend.Renderer;
import engine.scene.Graph;
import engine.scene.cameras.StaticCamera;
import engine.sound.System : gSoundSystem;
import engine.util.Log : MLogger;
import engine.mem.Memory;
import engine.util.Profiler;
import engine.util.GameState;
import engine.util.Resource : resourcesDump = dump;
import engine.util.Statistics;

import defend.Config;
import defend.common.Graphics;
import defend.demo.Recorder;
import defend.game.SinglePlayer;
import defend.game.Config;
import defend.game.hud.Hud;
import defend.game.net.Client;
import defend.game.net.Server;
import defend.sim.Gateway;
import defend.sim.Sim;
import defend.sim.Core;
import defend.terrain.Terrain;

class Game : GameState
{
	mixin MLogger;

	// Configuration
	GameConfig config;

	// Communication stuff
	NetworkServer server;
	SinglePlayerServer singlePlayer;
	Gateway gateway;
	bool gatewayShutdown = false;
	
	// Simulation
	Simulation simulation;
	
	// Terrain
	Terrain terrain;

	// Are we currently rendering as wireframe?
	bool wireframe = false;

	/* This is set to true if the communication gateway decides to
	   start the game */
	bool startGame = false;

	// Hud
	Hud hud;

	// Demo recorder
	DemoRecorder demoRecorder;
	
	// Input
	KeyboardReader keyboard;

	// Graphics setups
	Graphics graphics;
	
	// Make a screenshot?
	bool makeScreenshot = false;

	// Initializes singleplayer mode
	void initSinglePlayer()
	{
		singlePlayer = new SinglePlayerServer(config);
		gateway = singlePlayer.getGateway(config.me.nick);
	}

	// Initializes multiplayer mode
	void initMultiPlayer()
	{
		auto address = config.multiplayer.server;

		if(config.multiplayer.isServer)
		{
			logger_.info("creating server");
			server = new NetworkServer(config);
			address = "localhost";
		}

		logger_.info("creating client");
		gateway = new NetworkClient(address, config.multiplayer.port, config.me);
	}

	// Slots
	void onStartGame()
	{
		startGame = true;
	}

	void onGatewayShutdown(bool fatal)
	{
		if(fatal) logger_.warn("lost connection to gateway");
		if(!fatal) logger_.info("server closed connection");

		/* TODO: Change to another gamestate here, maybe go back
		   to the menu again */
		gatewayShutdown = true;
		gameState.exit = true;
	}

	void onGameInfo(GameInfo info)
	{
		logger_.info("creating terrain");

		terrain = new Terrain(sceneGraph.root,
					          simulation.gameObjects,
					          info,
					          simulation.heightmap);
		simulation.setTerrain(terrain);
	}
	
	// Initializes the communication between multiple players
	void initPlayerCommunication()
	{
		// If using a savegame, synch its game info with ours
		if(config.game.useSaveGame)
		{
			logger_.info("synching game info with savegame {}", config.game.saveGame);
		
			char[] name = config.game.saveGame;
		
			config.game = Simulation.getGameInfoFromSaveGame(name);
			config.game.useSaveGame = true;
			config.game.saveGame = name;
		}
	
		// Create network server and client, if requested
		if(config.mode != GameMode.MultiPlayer)
			initSinglePlayer();
		else
			initMultiPlayer();

		// Create the simulation
		simulation = new Simulation(gateway);
		
		// Create demo recorder, if requested
		if(config.recordDemo)
			demoRecorder = new DemoRecorder(gateway, config.demoFile);
		
		// Connect our own signals
		gateway.onStartGame.connect(&onStartGame);
		gateway.onGatewayShutdown.connect(&onGatewayShutdown);
		simulation.onGameInfo.connect(&onGameInfo);
			
		// And finally start the gateway
		gateway.start();
		
		if(singlePlayer)
			singlePlayer.start();
	}

	// Rendering
	void render()
	{
		logger_.spam("rendering");
	
		renderer.begin();

		// First the 3D objects
		if(wireframe)
			renderer.setRenderState(RenderState.Wireframe, true);

		graphics.render();
		
		renderer.setMatrix(graphics.mainCamera.modelview, MatrixType.Modelview);
		renderer.setMatrix(graphics.mainCamera.projection, MatrixType.Projection);
		simulation.gameObjects.render();

		if(wireframe)
			renderer.setRenderState(RenderState.Wireframe, false);

		// And then the 2D objects
		profile!("hud.render")
		({
			renderer.setRenderState(RenderState.DepthTest, false);
			renderer.orthogonal();
			renderer.identity();
			hud.render();
			renderer.setRenderState(RenderState.DepthTest, true);
		});

		profile!("flip")
		({
			if(makeScreenshot)
			{
				auto now = Clock.toDate();
				auto d = now.date;
				auto t = now.time;
			
				renderer.screenshot(Format("shots/{}-{:d2}-{:d2}-{:d2}_{:d2}_{:d2}.png",
										   d.year, d.month, d.day,
										   t.hours, t.minutes, t.seconds));
										   
				makeScreenshot = false;
			}
		
			renderer.end();
			renderer.clear();
		});
	}
	
	// Logging
	void logMemoryUsage()
	{
		logger_.trace("manual memory {}kb, gc {}kb, overall {}kb",
		              getMemoryUsage() / 1024,
		              gc_stats().poolsize / 1024,
		              (getMemoryUsage() + gc_stats().poolsize) / 1024);
	}
	
	void logObjectUsage()
	{
		logger_.trace("object usage is: {}",
		              objectUsageToString());
	}
	
	// Input
	void toggleWireframe(KeyboardInput)
	{
		wireframe = !wireframe;
	}
	
	void toggleSceneGraphDebug(KeyboardInput)
	{
		sceneGraph.debugVisible = !sceneGraph.debugVisible;
	}
	
	void inputExit(KeyboardInput)
	{
		gameState.exit = true;
	}
	
	void screenshot(KeyboardInput)
	{
		/* needs to be done in the render function,
		   because glReadPixels accesses the backbuffer */
		makeScreenshot = true;
	}
	
	void debugMemory(KeyboardInput)
	{
		logMemoryUsage();
		//logObjectUsage();
		
		GC.collect();
		
		//logMemoryUsage();
	}
	
	bool doPrintStatistics = false;
	
	void printStatistics()
	{
		if(doPrintStatistics)
		{
			statistics.dump();
			doPrintStatistics = false;
		}
		
		statistics.reset();
	}
	
	void setPrintStatistics(KeyboardInput)
	{
		doPrintStatistics = true;
	}
	
	void toggleSpam(KeyboardInput)
	{
		Log.level = (Log.level == LogLevel.Spam) ?  LogLevel.Trace : LogLevel.Spam;
	}
	
	void makeSaveGame(KeyboardInput)
	{
		if(server is null)
		{
			logger_.warn("only server can request save games");
			return;
		}
		
		server.makeSaveGame("test.sav");
	}

	override void init()
	{
		config = gameConfig;
		
		GC.collect();
		
		logMemoryUsage();
		//logObjectUsage();
		
		logger_.info("initializing communication");
		initPlayerCommunication();

		// Initialize graphics
		graphics = new Graphics;
		graphics.init(simulation.gameObjects);

		gateway.ready();
		logger_.info("waiting for communication process to finish");
		while(!startGame)
		{
			gateway.update();
			Thread.yield();
		}
		logger_.info("communication process finished");

		// Move the camera to the first object we find
		foreach(object; simulation.gameObjects)
		{
			if(object.owner == gateway.id)
			{
				Stdout(object.mapPos).newline;
				
				graphics.mainCamera.position =
					terrain.getWorldPos(object.mapPos) + vec3(3, 0, 8);
				break;
			}
		}

		// Create the HUD
		hud = new Hud(simulation.gameObjects);
		
		// Disable the GC
		logMemoryUsage();
		
		GC.collect();
		//GC.disable();

		// Initialize input
		keyboard = new KeyboardReader(InputChannel.global);
		
		keyboard.keyDownHandlers[KeyType.L] = &toggleWireframe;
		keyboard.keyDownHandlers[KeyType.G] = &toggleSceneGraphDebug;
		keyboard.keyDownHandlers[KeyType.Escape] = &inputExit;
		keyboard.keyDownHandlers[KeyType.F5] = &screenshot;
		keyboard.keyDownHandlers[KeyType.V] = &debugMemory;
		keyboard.keyDownHandlers[KeyType.K] = &makeSaveGame;
		keyboard.keyDownHandlers[KeyType.B] = &setPrintStatistics;
		keyboard.keyDownHandlers[KeyType.M] = &toggleSpam;
		
		//dumpGCStats();
		
		//sceneGraph.debugVisible = true;
		
		taskManager.addRepeatedTask(&InputChannel.global.update, 100);
		taskManager.addRepeatedTask(&simulation.gameObjects.update, 100);
		taskManager.addRepeatedTask(&sceneGraph.update, 60);
		taskManager.addRepeatedTask(&gateway.update, 10);
		taskManager.addRepeatedTask(&hud.update, 30);
		taskManager.addRepeatedTask(&renderer.window.update, 60);
		taskManager.addRepeatedTask(&gSoundSystem.update, 15);
		taskManager.addPostFrameTask(&render);
		taskManager.addPostFrameTask(&printStatistics);
	}

	override void done()
	{
		logger_.info("game shutting down");
		logMemoryUsage();

		if(server !is null)
		{
			logger_.info("shutting down server");

			server.shutdown();
		}

		logger_.info("disconnecting gateway");
		gateway.disconnect();

		delete hud;
		delete simulation;
		delete gateway;
		delete server;
		delete singlePlayer;
		
		keyboard.remove();
		
		if(demoRecorder)
			delete demoRecorder;
		
		graphics.release();

		//GC.enable();
		GC.collect();

		logMemoryUsage();
		//logObjectUsage();
		
		// print out a list of loaded resources, for debugging
		resourcesDump();

		//dumpGCStats();
	}
}
