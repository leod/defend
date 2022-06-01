module defend.demo.Demo;

import tango.core.Thread : Fiber;
import tango.io.Stdout;

import engine.core.TaskManager;
import engine.input.Input;
import engine.math.Matrix;
import engine.math.Vector;
import engine.rend.Renderer;
import engine.scene.Graph;
import engine.util.GameState;

import defend.common.Graphics;
import defend.common.Camera;
import defend.demo.Player;
import defend.sim.Sim;
import defend.sim.Gateway;
import defend.sim.Map;
import defend.terrain.Terrain;

class Demo : GameState
{
	char[] path;

	DemoPlayer demoPlayer;
	Simulation simulation;
	Graphics graphics;
	Terrain terrain;
	
	this(char[] path)
	{
		this.path = path;
	}

	void onGameInfo(GameInfo info)
	{
		terrain = new Terrain(sceneGraph.root,
					          simulation.gameObjects,
					          info,
					          simulation.heightmap);
		simulation.setTerrain(terrain);
	}

	void render()
	{
		renderer.begin();

		graphics.render();

		renderer.end();
		renderer.clear();
	}

	void init()
	{
		Stdout(path).newline;
		demoPlayer = new DemoPlayer(path);
		simulation = new Simulation(demoPlayer);

		graphics = new Graphics;
		graphics.init(simulation.gameObjects);
		
		simulation.onGameInfo.connect(&onGameInfo);

		demoPlayer.init();
		assert(terrain !is null);

		taskManager.addRepeatedTask(&InputChannel.global.update, 100);
		taskManager.addRepeatedTask(&simulation.gameObjects.update, 30);
		taskManager.addRepeatedTask(&sceneGraph.update, 60);
		taskManager.addRepeatedTask(&renderer.window.update, 60);
		taskManager.addPostFrameTask(&render);
	}

	void done()
	{
		delete simulation;
		
		graphics.release();
	}
}
