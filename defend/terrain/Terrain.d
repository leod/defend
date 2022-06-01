module defend.terrain.Terrain;

import tango.math.Math : sin, cos, PI;

import engine.util.Debug;
import engine.math.Ray;
import engine.math.Misc;
import engine.math.Vector;
import engine.math.Epsilon;
import engine.math.Rectangle;
import engine.math.BoundingBox;
import engine.scene.Node;
import engine.scene.Graph;
import engine.scene.effect.Effect;
import engine.scene.effect.Library;
import engine.scene.effect.Node;
import engine.scene.Camera;
import engine.scene.nodes.CullNode;
import engine.util.Log : MLogger;
import engine.util.Config;
import engine.mem.Memory;
import engine.util.Profiler;
import engine.util.Cast;
import engine.util.Profiler;
import engine.rend.Texture;
import engine.rend.Renderer;
import engine.rend.Shader;
import engine.image.Image;
import engine.image.Devil;
import engine.util.MT;
import engine.util.Wrapper;

import defend.Config;
import defend.sim.Core;
import defend.sim.Types;
import defend.sim.GameInfo;
import defend.terrain.Vertex;
import defend.terrain.Patch;
import defend.terrain.Ranges;
import defend.terrain.Decals;
import defend.terrain.FogOfWarRend;
import defend.terrain.ITerrain;

// Effect for rendering the terrain
abstract class TerrainEffect : Effect
{
	Heightmap heightmap;
	Texture[3] diffuseMaps;
	TerrainPatch[] patches;
	Texture lightmap;

	this(char[] name, int score)
	{
		super("terrain", name, score);
	}

	abstract void initMaps();
	abstract void releaseMaps();
	abstract void renderOrthogonal();
	abstract void registerForRendering(Camera, SceneNode);
	abstract void onHeightmapChange(int x, int y);

	static this()
	{
		gEffectLibrary.addEffectType("terrain");
	}
}

class Terrain : SceneNode, ITerrain
{
	mixin MLogger;

private:
	uint patchCount;
	
	TerrainPatch[] patches;
	Heightmap _heightmap;
	map_pos_t size;

	void heightmap(Heightmap h) { _heightmap = h; }

	Texture detailTexture;

	Texture[3] diffuseMaps;
	
	void createLightmap()
	{
		scope b = new Benchmark("lightmap");
		const uint size = 128;
		scope image = new Image(size, size, ImageFormat.RGB);
	
		bool rayIntersection(Ray!(float) ray)
		{
			vec3 dir = ray.direction;
			vec3 pos = ray.origin + dir;
			
			while(pos.x > 0 && cast(uint)pos.x < size &&
				  pos.z > 0 && cast(uint)pos.z < size)
			{
				if(getHeightForImage(heightmap, cast(uint)pos.x, cast(uint)pos.z, size) > pos.y)
					return true;
				
				pos += dir;
			}
			
			return false;
		}

		uint dir = 180; //random!(uint)(0, 360);
		
		Ray!(float) rayProto;
		rayProto.direction.x = cos(dir * PI / 180);
		rayProto.direction.y = 0.3; //(100 - random!(uint)(0, 60)) / cast(float)100;
		rayProto.direction.z = sin(dir * PI / 180);
		rayProto.direction = rayProto.direction.normalized();
		
		auto tp = new ThreadPoolT(4);
		scope(exit) tp.finish();
		
		{
			foreach(z; mtFor(tp, 0, size))
			{
				for(uint x = 0; x < size; ++x)
				{
					Ray!(float) ray = rayProto;
					ray.origin.x = x,
					ray.origin.y = getHeightForImage(heightmap, x, z, size);
					ray.origin.z = z;
					
					vec3 normal = getNormalForImage(heightmap, x, z, size);
					vec3 col = vec3(.15, 0.2, .25) * normal.y; // ambient

					if(!rayIntersection(ray))
					{
						float dot = dot(ray.direction, normal);
						if(dot < 0.f) dot = 0.f;
						col += vec3(1.4, 1.1, 0.9) * dot;
					}
					
					col *= 1.5f;
					
					ubyte f2ub(float f)
					{
						if(f <= 0.f) return 0;
						if(f >= 2.f) return 255;
						return cast(ubyte)(f * 127.5f);
					}
					
					image.setRGB(x, z, f2ub(col.x), f2ub(col.y), f2ub(col.z));
				}
			}
		}
		
		// Smoothing
		
		const int steps = 1;
		for(uint i = 0; i < steps; i++)
		{
			ubyte[] temp = image.data.dup;
			
			//foreach(channel; mtFor(tp, 0, 3))
			for(uint channel = 0; channel < 3; ++channel)
			{
				for(uint y = 1; y < image.width - 1; y++)
				{
					for(uint x = 1; x < image.height - 1; x++)
					{
						ubyte b1 = image.getByte(x, y, channel);
						ubyte b2 = image.getByte(x, y, -3 + channel);
						ubyte b3 = image.getByte(x, y, -image.width * 3 + channel);
						ubyte b4 = image.getByte(x, y, 3 + channel);
						ubyte b5 = image.getByte(x, y, image.width * 3 + channel);

						ubyte c = cast(ubyte)((cast(uint)b1 + b2 + b3 + b4 + b5) / 5);
						temp[(y * image.width + x) * 3 + channel] = c;
					}
				}
			}
			
			image.data = temp;
			delete temp;
		}
		
		lightmapTexture = renderer.createTexture(image);
	}
	
	void createPatches()
	{
		auto patchWidth = (size.x - 1) / cast(float)patchCount;
		auto patchHeight = (size.y - 1) / cast(float)patchCount;

		for(uint y = 0; y < patchCount; ++y)
		{
			for(uint x = 0; x < patchCount; ++x)
			{
				patches ~= new TerrainPatch(heightmap,
								            Rect(cast(int)(x * patchWidth),
									             cast(int)(y * patchHeight),
									             cast(int)((x + 1) * patchWidth),
									             cast(int)((y + 1) * patchHeight)));
			}
		}
	}
	
	void loadDiffuseMaps()
	{
		diffuseMaps[0] = Texture("grass.png");
		diffuseMaps[1] = Texture("mountain.png");
		diffuseMaps[2] = Texture("snow.png");
	}

	void createCullTree()
	{
		void areaPatches(Rect area, void delegate(TerrainPatch) dg)
		{
			for(uint x = area.left; x < area.right; x++)
				for(uint y = area.top; y < area.bottom; y++)
					dg(patches[y * patchCount + x]);
		}
		
		void delegate(Rect, SceneNode) forwardCreatePart;
		
		void callSub(Rect area, SceneNode parent)
		{
			const uint numChildsRoot = 2;
			uint partRight = area.left + area.width / numChildsRoot;
			uint partBottom = area.top + area.height / numChildsRoot;

			forwardCreatePart(Rect(area.left, area.top, partRight, partBottom), parent);
			forwardCreatePart(Rect(area.left, partBottom, partRight, area.bottom), parent);
			forwardCreatePart(Rect(partRight, area.top, area.right, partBottom), parent);
			forwardCreatePart(Rect(partRight, partBottom, area.right, area.bottom), parent);
		}
		
		void createPart(Rect area, SceneNode parent)
		{
			//logger.indent();
			//scope(exit) logger.outdent();
		
			//logger.info("{} ({}|{})", area, area.width, area.height);
		
			// If this area is only containing one patch, we're at the bottom of the hierarchy
			if(area.width == 1 && area.height == 1)
			{
				areaPatches(area, (TerrainPatch patch)
				{
					parent.addChild(patch);
				});
				
				return;
			}
			
			// Create a bounding box surrounding all the patches in this area
			//logger.info("new cull node");
			
			auto cullNode = new CullNode(parent);
			
			areaPatches(area, (TerrainPatch patch)
			{
				cullNode.boundingBox.addPoint(patch.bbox.min);
				cullNode.boundingBox.addPoint(patch.bbox.max);
			});

			// Split the area into 4 parts and recurse
			callSub(area, cullNode);
		}
		
		forwardCreatePart = &createPart;
		callSub(Rect(0, 0, patchCount, patchCount), this);
	}

	mixin MEffectSupport!(TerrainEffect, "terrain") mainEffect;

	Texture lightmapTexture;
	FogOfWarRend _fogOfWarRend;
	
	Decals _decals;
	
public:
	mixin MAllocator;

	override Heightmap heightmap() { return _heightmap; }
	override Decals decals() { return _decals; }

	this(SceneNode parent, GameObjectManager gameObjects, GameInfo gameInfo, Heightmap heightmap)
	{
		super(parent);
		
		this.heightmap = heightmap;
		size = heightmap.size;
		patchCount = 8;

		logger_.info("loading diffuse maps");
		loadDiffuseMaps();
		
		logger_.info("creating patches");
		createPatches();
		
		logger_.info("creating lightmap");
		createLightmap();
		
		logger_.info("creating cull tree");
		createCullTree();
		
		if(gameInfo.withFogOfWar)
		{
			logger_.info("creating fog of war renderer");
			_fogOfWarRend = new FogOfWarRend(gameObjects, lightmapTexture);
		}
		
		_decals = new Decals(heightmap);
		
		mainEffect.load();
		
		mainEffect.best.heightmap = heightmap;
		mainEffect.best.diffuseMaps[] = diffuseMaps;
		mainEffect.best.patches = patches;
		mainEffect.best.initMaps();
		
		logger_.info("initialized");
	}

	~this()
	{
		delete patches;
		delete _decals;
		delete _fogOfWarRend;
		
		if(heightmap) delete _heightmap;
		if(lightmapTexture) delete lightmapTexture;
		if(detailTexture) subRef(detailTexture);
		
		mainEffect.best.releaseMaps();
		
		foreach(texture; diffuseMaps)
		{
			if(!texture) continue;
			subRef(texture);
		}
	}

	override void registerForRendering(Camera camera)
	{
		if(sceneGraph.cameraData.shadowMap)
			return;
	
		debug if(sceneGraph.debugNodeVisible(this))
			sceneGraph.passSolid.add(camera, this, &renderDebug);
		
		mainEffect.best.lightmap = _fogOfWarRend ? _fogOfWarRend.texture : lightmapTexture;
		mainEffect.register(camera);
	}

	import engine.rend.opengl.Wrapper;
	
	debug void renderDebug()
	{
		glPolygonOffset(-20, -20);
		glEnable(GL_POLYGON_OFFSET_LINE);
		
		/+renderer.setRenderState(RenderState.Wireframe, true);
		//renderer.setRenderState(RenderState.Blending, true);
		renderer.setColor(vec4(1, 1, 1, 0.5));

		renderer.translate(0, 0, 0);

		foreach(patch; patches)
			if(patch.visible) patch.render();
	
		//renderer.setRenderState(RenderState.Blending, false);
		renderer.setRenderState(RenderState.Wireframe, false);+/

		foreach(patch; patches)
			if(patch.visible) renderer.drawBoundingBox(patch.boundingBox, vec3(1, 0, 0));
		
		glDisable(GL_POLYGON_OFFSET_LINE);
		
		version(none) for(uint x = 0; x < dimension.x; x++)
		{
			for(uint y = 0; y < dimension.y; y++)
			{
				auto visible = fogOfWar.isVisible(x, y);
				
				if(visible)
				{
					auto pos = getWorldPos(x, y);
					renderer.drawLine(pos, pos + vec3(0, 1, 0), vec3(1, 0, 0));
				}
			}
		}
	}
	
	override void renderOrthogonal() // for mini map
	{
		//mainEffect.best.renderOrthogonal();
	}
	
	override void iteratePatches(bool delegate(TerrainPatch) dg)
	{
		foreach(patch; patches)
			if(!dg(patch)) return;
	}
	
	float getHeight(uint x, uint y)
	{
		assert(heightmap !is null);
		
		return heightmap.getHeight(x, y);
	}
	
	override vec3 getWorldPos(map_pos_t p)
	{
		return getWorldPos(p.x, p.y);
	}
	
	override vec3 getWorldPos(vec2i p)
	{
		return getWorldPos(cast(uint)p.x, cast(uint)p.y); // i'll remove those useless uints someday
	}
	
	override vec3 getWorldPos(uint x, uint y)
	{
		return vec3(x, getHeight(x, y), -cast(int)y);
	}
	
	bool within(uint x, uint y)
	{
		return x >= 0 && y >= 0 && x < size.x && y < size.y;
	}
	
	bool within(vec2i p)
	{
		return within(p.x, p.y);
	}
	
	bool within(int x, int y)
	{
		return x >= 0 && y >= 0 && x < size.x && y < size.y;
	}
	
	override bool within(vec2us p)
	{
		return within(p.x, p.y);
	}
	
	bool within(ushort x, ushort y)
	{
		return x >= 0 && y >= 0 && x < size.x && y < size.y;
	}
	
	override map_pos_t dimension()
	{
		return size;
	}
	
	override Texture lightmap()
	{
		return _fogOfWarRend ? _fogOfWarRend.texture : lightmapTexture;
	}
	
	override Texture fogOfWarTexture()
	{
		//assert(fogOfWarRend !is null);
		if(!_fogOfWarRend)
			return null;
		
		return _fogOfWarRend.texture;
	}
	
	void changeHeightmap(int x, int y, float h)
	{
		heightmap.setHeight(x, y, h);
		mainEffect.best.onHeightmapChange(x, y);
		
		foreach(patch; patches)
		{
			if(x >= patch.rect.left && y >= patch.rect.top && x <= patch.rect.right && y <= patch.rect.bottom)
				patch.onHeightmapChange(x, y);
		}
	}
	
	bool intersectRay(Ray!(float) ray, ref map_pos_t mapPos)
	{
		float minT = 20_000;
		bool hasIntersection = false;

		foreach(patch; patches)
		{
			if(!patch.visible)
				continue;

			auto bbox = patch.boundingBox;

			// Parameters for patch.intersectRay
			float t, u, v;
			uint face;

			if(ray.intersectBoundingBox(patch.boundingBox) &&
			   patch.intersectRay(ray, t, u, v, face) &&
			   t < minT)
			{
				uint numberTiles = face / 2;
				uint numberRowTiles = patch.area.right - patch.area.left;
				uint y = numberTiles / numberRowTiles;
				uint x = numberTiles - y * numberRowTiles;

				if(face % 2 == 0) // Upper left face hit
				{
					if(u > 0.5)
						x++;
					else if(v > 0.5)
						y++;
				}
				else // Lower right face hit
				{
					if(u + v < 0.5)
						y++;
					else if(u > 0.5)
						x++;
					else
					{
						x++;
						y++;
					}
				}

				auto p = map_pos_t(patch.area.left + x, patch.area.top + y);
				
				if(within(p))
				{
					mapPos = p;
					minT = t;
					hasIntersection = true;
				}
			}
		};
		
		return hasIntersection;
	}
}
