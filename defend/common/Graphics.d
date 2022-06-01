module defend.common.Graphics;

import tango.math.Math;

import engine.core.TaskManager;
import engine.util.Profiler;
import engine.math.Vector;
import engine.rend.Renderer;
import engine.scene.Graph;
import engine.scene.effect.Library;
import engine.scene.nodes.ParticleSystem;
import engine.scene.cameras.StaticCamera;

import defend.sim.Core;
import defend.Config : gDefendConfig;
import defend.common.Camera : MainCamera;

// Class for setting up all the graphics stuff
class Graphics
{
private:
	MainCamera _mainCamera;
	
public:
	void init(GameObjectManager gameObjects)
	{	
		// Initialize effects
		gEffectLibrary.init();
		gEffectLibrary.initEffects();
	
		// Create particle systems
		particles = new ParticleSystemManager;
		particles.addSystem("smoke", new SmokeParticleSystem(sceneGraph.root, "smoke.bmp"));
		particles.addSystem("blood", new SparkParticleSystem(sceneGraph.root, "blood.png", 0.09, 500.0, 1.0, 10));
		
		_mainCamera = new MainCamera(gameObjects);
		_mainCamera.projection = mat4.perspective(gDefendConfig("screen").integer("fov"),
		                                          renderer.config.aspect, 1, 300);
		sceneGraph.addCamera("main", _mainCamera, vec3(0, 0, 0), null);
		
		// Set tasks
		taskManager.addRepeatedTask(&particles.update, 20);
	}

	void render()
	{
		profile!("graph.render")(&sceneGraph.render);
	}
	
	void release()
	{
		gEffectLibrary.releaseEffects();
		sceneGraph.reset();
		delete particles;
	}
	
	MainCamera mainCamera()
	{
		return _mainCamera;
	}
}
