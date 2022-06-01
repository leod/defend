module engine.scene.Graph;

import tango.core.Array : sort;
import tango.util.Convert;

import engine.image.Image;
import engine.util.Array;
import engine.util.Debug;
import engine.util.Log : MLogger;
import engine.util.Profiler;
import engine.util.Singleton;
import engine.util.Swap;
import engine.math.Frustum;
import engine.math.Matrix;
import engine.math.Rectangle;
import engine.math.Vector;
import engine.rend.Framebuffer;
import engine.rend.Renderer;
import engine.rend.Texture;
import engine.scene.Camera;
import engine.scene.Node;
import engine.scene.passes.Blended;
import engine.scene.passes.Solid;
import engine.scene.RenderPass;

private final class CameraData
{
package:
	//BufferedArray!(NodeHolder)[RenderPass.max + 1] renderPasses;
	bool active = true;
	
public:
	vec3 clearColor;

	char[] name;
	Camera core;
	Framebuffer framebuffer; // The framebuffer that is rendered to (not available for the main camera)
	bool shadowMap;
	
	bool isMain()
	{
		return framebuffer is null;
	}
	
	char[] toString() { return to!(char[])(cast(int)cast(void*)core); }
}

final class Graph
{
	mixin MLogger;

private:
	SceneNode _root;

	// All cameras
	CameraData[] cameras;

	// Render pass types
	RenderPass[] passes;

public:
	mixin MSingleton;

	// Current render pass
	RenderPass renderPass;
	
	// Current camera
	CameraData cameraData;
	
	// Debug data like bounding boxes visible?
	bool debugVisible;
	
	// Render passes
	RenderPass passSolid;
	RenderPass passBlended;
	
	// Initialize the scene graph
	this()
	{
		_root = new SceneNode(null);
		
		passSolid = addRenderPass(new RenderPassSolid);
		passBlended = addRenderPass(new RenderPassBlended);
	}
	
	// Add a new render pass
	RenderPass addRenderPass(RenderPass pass)
	in
	{
		foreach(p; passes)
			assert(p !is pass);
	}
	body
	{
		passes ~= pass;
		
		passes.sort((RenderPass a, RenderPass b)
		{
			return a.priority < b.priority;
		});
		
		return pass;
	}
	
	void removeRenderPass(RenderPass pass)
	{
		passes.removeElement(pass);
	}
	
	// Resetting the graph
	void reset()
	{
		logger_.info("full reset");
		
		foreach(cam; cameras)
		{
			logger_.info("deleting camera {}", cam.name);

			delete cam.core;
			delete cam.framebuffer; // orly
			delete cam;
		}
		
		cameras.length = 0;
		
		debug foreach(key, cam; cameras)
			assert(false);
		
		logger_.info("deleting nodes");
		
		delete _root;
		_root = new SceneNode(null);
	}

	bool isCamera(char[] name)
	{
		foreach(cam; cameras) if(cam.name == name) return true;

		return false;
	}


	// Add a new camera
	CameraData addCamera(char[] name, Camera core, vec3 clearColor,
	                     Framebuffer framebuffer = null, bool shadowMap = false)
	in
	{	
		if(shadowMap)
			assert(framebuffer !is null);
	}
	body
	{
		logger_.info("adding camera {}", name);
		
		CameraData data = new CameraData;
		data.name = name;
		data.active = true;
		data.clearColor = clearColor;
		data.core = core;
		data.framebuffer = framebuffer;
		data.shadowMap = shadowMap;

		cameras ~= data;

		// Ensure that only one main camera exists
		debug
		{
			uint c;
			foreach(ref cam; cameras)
			{
				if(cam.active && cam.isMain)
					c++;
			}

			assert(c < 2, "there mustn't be more than one main camera");
		}

		// Ensure that the main camera is the last entry in the camera list
		foreach(i, cam; cameras)
		{
			if(cam.isMain)
			{
				swap(cameras[$ - 1], cameras[i]);
				break;
			}
		}
		
		return data;
	}

	// Returns a camera by its name
	CameraData getCamera(char[] name)
	{
		foreach(camera; cameras)
			if(camera.name == name)
				return camera;
				
		assert(false);
	}
	
	// Debug data visible?
	bool debugNodeVisible(SceneNode node)
	{
		return debugVisible || node.debugVisible;
	}

	SceneNode root()
	{
		return _root;
	}

	// Update all cameras and nodes
	void update()
	{
		logger_.spam("updating");
	
		profile!("graph.update")
		({
			foreach(cam; cameras)
			{
				if(!cam.active)
					continue;
				
				cam.core.update();
			}
			
			root.doUpdate();
		});
	}

	// Render anything, for each camera
	void render()
	{
		// Render for each camera
		foreach(cam; cameras)
		{
			if(!cam.active)
				continue;

			logger_.spam("camera {}", cam.name);
			
			cameraData = cam;
			auto camera = cameraData.core;

			// Let nodes register themselves to be rendered
			profile!("process")
			({
				root.doRegisterForRendering(camera);
			});

			// Set the current camera's matrices
			renderer.setMatrix(camera.projection, MatrixType.Projection);
			renderer.setMatrix(camera.modelview, MatrixType.Modelview);

			// Render
			if(cam.framebuffer)
			{
				renderer.setFramebuffer(cam.framebuffer);
				renderer.clear(cam.clearColor);
			}
			
			profile!("render")
			({
				foreach(pass; passes)
				{
					logger_.spam("pass {} ({}): {} nodes", pass, cast(void*)pass, pass.count);
				
					pass.renderAll();
					pass.reset();
				}
			});

			if(cam.framebuffer)
				renderer.unsetFramebuffer(cam.framebuffer);
		}
	}
}

alias SingletonGetter!(Graph) sceneGraph;
