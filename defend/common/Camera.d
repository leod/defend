module defend.common.Camera;

import tango.io.Stdout;
import tango.math.Math;

import engine.input.Input;
import engine.math.Frustum;
import engine.math.Matrix;
import engine.math.Ray;
import engine.math.Rectangle;
import engine.math.Vector;
import engine.rend.Renderer;
import engine.rend.Window;
import engine.scene.Camera;
import engine.mem.Memory;
import engine.util.Wrapper;
import engine.util.Cast;

// tmp
//version = MoveShadowCamera;

import engine.scene.Graph;
import engine.scene.cameras.StaticCamera;

import defend.sim.Core;
import defend.terrain.Patch;
import defend.terrain.Terrain;

class MainCamera : Camera
{
private:
	float yaw = 0.0, pitch = 0.0, roll = 0.0;
	vec3 dir, up, right;
	vec3 pos;
	float minDistance = 15;

	GameObjectManager gameObjects;
	Terrain _terrain;

	Terrain terrain()
	{
		if(gameObjects)
			return objCast!(Terrain)(gameObjects.terrain);
			
		return _terrain;
	}
	
	Frustum!(float) _frustum;
	
	// The modelview matrix
	mat4 _modelview = mat4.identity;
	
	// Projection matrix
	mat4 _projection = mat4.identity;

	// Input
	MouseReader mouse;
	KeyboardReader keyboard;

	void inputUpdate()
	{
		const w = 10;
		const speed = 1.0f;
		
		auto p = mouse.mousePos;
		
		if(p.x < w) scroll(vec3(-speed, 0, 0));
		if(p.x > renderer.width - w) scroll(vec3(speed, 0, 0));
		if(p.y < w) scroll(vec3(0, 0, speed));
		if(p.y > renderer.height - w / 2) scroll(vec3(0, 0, -speed));
	}

	float inputSpeed(KeyboardInput input)
	{
		if(input.mod & KeyboardInput.Modifier.LShift)
			return 1.5;

		return 0.1;
	}

	void inputMoveLeft(KeyboardInput input)
	{
		if(input.mod & KeyboardInput.Modifier.LCtrl)
		{
			yaw += inputSpeed(input) * 0.05;
				return;
		}

		scroll(vec3(-inputSpeed(input), 0, 0));
		
		version(MoveShadowCamera)
		{
			auto c = cast(StaticCamera)sceneGraph.getCamera("shadow").core;
			c.position = c.position + vec3(-0.1, 0, 0);
		}
	}

	void inputMoveRight(KeyboardInput input)
	{
		if(input.mod & KeyboardInput.Modifier.LCtrl)
		{
			yaw -= inputSpeed(input) * 0.05;
			return;
		}
		
		version(MoveShadowCamera)
		{
			auto c = cast(StaticCamera)sceneGraph.getCamera("shadow").core;
			c.position = c.position + vec3(0.1, 0, 0);
		}

		scroll(vec3(inputSpeed(input), 0, 0));
	}

	void inputMoveUp(KeyboardInput input)
	{
		if(input.mod & KeyboardInput.Modifier.LCtrl)
		{
			version(MoveShadowCamera)
			{
				auto c = cast(StaticCamera)sceneGraph.getCamera("shadow").core;
				c.rotation = c.rotation + vec3(0.005, 0, 0);
			}
		
			pitch += inputSpeed(input) * 0.05;
			return;
		}
	
		version(MoveShadowCamera)
		{
			auto c = cast(StaticCamera)sceneGraph.getCamera("shadow").core;
			c.position = c.position + vec3(0, 0, 0.1);
		}
	
		scroll(vec3(0, 0, inputSpeed(input)));
	}

	void inputMoveDown(KeyboardInput input)
	{
		if(input.mod & KeyboardInput.Modifier.LCtrl)
		{
			version(MoveShadowCamera)
			{
				auto c = cast(StaticCamera)sceneGraph.getCamera("shadow").core;
				c.rotation = c.rotation + vec3(-0.005, 0, 0);
			}
		
			pitch -= inputSpeed(input) * 0.05;
			return;
		}

		version(MoveShadowCamera)
		{
			auto c = cast(StaticCamera)sceneGraph.getCamera("shadow").core;
			c.position = c.position + vec3(0, 0, -0.1);
		}
	
		scroll(vec3(0, 0, -inputSpeed(input)));
	}

	void inputZoomIn(KeyboardInput input)
	{
		version(MoveShadowCamera)
		{
			auto c = cast(StaticCamera)sceneGraph.getCamera("shadow").core;
			c.position = c.position + vec3(0, 0.1, 0);
		}
	
		minDistance -= inputSpeed(input);

		if(minDistance < 2)
			minDistance = 2;
		
		//collision();
	}

	void inputZoomOut(KeyboardInput input)
	{
		version(MoveShadowCamera)
		{
			auto c = cast(StaticCamera)sceneGraph.getCamera("shadow").core;
			c.position = c.position + vec3(0, -0.1, 0);
		}
	
		minDistance += inputSpeed(input);

		//if(minDistance > 15)
		//	minDistance = 15;
	}

	void checkCollision()
	{
		if(pos.z < -cast(int)terrain.dimension.y + 18)
			pos.z = -cast(int)terrain.dimension.y + 18;

		if(pos.z >= 0)
			pos.z = 0;

		if(pos.x <= 0)
			pos.x = 0;

		if(pos.x > terrain.dimension.x - 18)
			pos.x = terrain.dimension.x - 18;

		auto rayDown = Ray!(float)(vec3(pos.x, 10_000, pos.z), vec3(0, -1, 0));

		terrain.iteratePatches(
		(TerrainPatch patch) 
		{
			if(pos.x >= patch.area.left &&
			   pos.x < patch.area.right &&
			   -pos.z >= patch.area.top &&
			   -pos.z < patch.area.bottom)
			{
				float t, u, v;
				uint face;

				if(patch.intersectRay(rayDown, t, u, v, face))
				{
					pos.y = 10_000 + minDistance - t;
					return false;
				}
			}

			return true;
		});
		
		/*foreach(object; gameObjects)
		{
			auto bbox = object.sceneNode.boundingBox.expanded(2);
		
			if(bbox.checkCollision(pos) && bbox.max.y > minDistance)
			{
				pos.y = bbox.max.y;
				return;
			}
		}*/
	}

	void calcMatrices()
	{
		float sinyaw = sin(yaw);
		float cosyaw = cos(yaw);
		float sinpitch = sin(pitch);
		float cospitch = cos(pitch);
		float sinroll = sin(roll);
		float cosroll = cos(roll);

		right = vec3(cosyaw * cosroll + sinyaw * sinpitch *
					 sinroll, sinroll * cospitch,
					 cosyaw * sinpitch * sinroll - sinyaw * cosroll);

		up = vec3(sinyaw * sinpitch * cosroll - cosyaw * sinroll,
				  cosroll * cospitch,
				  sinroll * sinyaw + cosroll * cosyaw * sinpitch);

		dir = vec3(cospitch * sinyaw, -sinpitch, cospitch * cosyaw);

		_modelview = createMat4(right.x, up.x, dir.x, 0.0,
		                        right.y, up.y, dir.y, 0.0,
		                        right.z, up.z, dir.z, 0.0,
		                        -(dot(pos, right)),
		                        -(dot(pos, up)),
		                        -(dot(pos, dir)),
		                        1.0);
		
		frustum.create(_modelview, projection);
	}

public:
	mixin MAllocator;

	this(GameObjectManager gameObjects)
	{
		this.gameObjects = gameObjects;
		_frustum = new Frustum!(float);

		mouse = new MouseReader(InputChannel.global);
		
		// only allow scrolling with the mouse if the game is running fullscreen
		if(renderer.config.fullscreen)
			mouse.updateHandler = &inputUpdate;

		keyboard = new KeyboardReader(InputChannel.global);
		keyboard.keyHoldHandlers[KeyType.Left] = &inputMoveLeft;
		keyboard.keyHoldHandlers[KeyType.Right] = &inputMoveRight;
		keyboard.keyHoldHandlers[KeyType.Up] = &inputMoveUp;
		keyboard.keyHoldHandlers[KeyType.Down] = &inputMoveDown;
		keyboard.keyHoldHandlers[KeyType.A] = &inputMoveLeft;
		keyboard.keyHoldHandlers[KeyType.D] = &inputMoveRight;
		keyboard.keyHoldHandlers[KeyType.W] = &inputMoveUp;
		keyboard.keyHoldHandlers[KeyType.S] = &inputMoveDown;
		keyboard.keyHoldHandlers[KeyType.PageUp] = &inputZoomIn;
		keyboard.keyHoldHandlers[KeyType.PageDown] = &inputZoomOut;

		right = vec3(1, 0, 0);
		up = vec3(0, 1, 0);
		dir = vec3(0, 0, 1);

		position = vec3(0, 0, 0);
		rotate(vec3(-1, 0, 0));
	}
	
	void setTerrain(Terrain terrain)
	{
		_terrain = terrain;
	}

	~this()
	{
		delete _frustum;
		
		mouse.remove();
		keyboard.remove();
	}

	Frustum!(float) frustum()
	{
		return _frustum;
	}

	mat4 modelview()
	{
		return _modelview;
	}

	mat4 projection()
	{
		return _projection;
	}

	void update()
	{
		checkCollision();
		calcMatrices();
		
		version(MoveShadowCamera)
		{
			auto c = cast(StaticCamera)sceneGraph.getCamera("shadow").core;
			synchronized(Stdout) Stdout(c.position, c.rotation).newline;
		}
	}

	vec3 position()
	{
		return pos;
	}
		
	void projection(mat4 m)
	{
		_projection = m;
	}

	void rotation(vec3 v)
	{
		pitch = v.x;
		yaw = v.y;
		roll = v.z;
	}

	void rotate(vec3 v)
	{
		pitch += v.x;
		yaw += v.y;
		roll += v.z;
	}

	void scroll(vec3 v)
	{
		void move(vec3 v)
		{
			auto newPos = pos + v;
		
			/*foreach(object; gameObjects)
			{
				auto bbox = object.sceneNode.boundingBox.expanded(2);
			
				if(bbox.checkCollision(newPos))
					return;
			}*/
			
			pos = newPos;
		}
		
		move(right * v.x);
		move(dir * v.y);
		move(up * v.z);
	}

	void position(vec3 v)
	{
		pos = v;
	}

	void move(vec3 v)
	{
		pos += v;
	}
}
