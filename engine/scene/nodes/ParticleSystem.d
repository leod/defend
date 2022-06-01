module engine.scene.nodes.ParticleSystem;

import tango.core.Traits;
import tango.core.Tuple;
import tango.math.random.Kiss;

import engine.util.Profiler;
import engine.mem.Memory;
import engine.util.Array;
import engine.util.Singleton;
import engine.mem.MemoryPool;
import engine.math.Vector;
import engine.math.Matrix;
import engine.scene.Node;
import engine.scene.Camera;
import engine.scene.Graph;
import engine.rend.opengl.Wrapper;
import engine.rend.Texture;
import engine.rend.Renderer;
import engine.image.Image;
import engine.image.Devil;
import engine.list.LinkedList;
import engine.list.BufferedArray;

interface IParticleSystem
{
	void spawn(vec3 position, size_t num);
	void updateParticles();
}

class ParticleSystem(Manager, alias System)
	: SceneNode, IParticleSystem
{
private:
	// Allocates particles and manages them in a list
	Manager list;
	
	// Initializes, renders and updates particles
	mixin System!(Manager.ParticleT) system;

	static if(is(typeof(system.create)))
		alias ParameterTupleOf!(system.create) SystemCreateTuple;
	else
		alias Tuple!() SystemCreateTuple;

public:
	mixin MAllocator;

	this(SceneNode parent, SystemCreateTuple t)
	{
		super(parent);
	
		static if(is(typeof(list.create)))
			list.create();
		
		static if(is(typeof(system.create)))
			system.create(t);
	}
	
	~this()
	{
		static if(is(typeof(list.release)))
			list.release();
		
		static if(is(typeof(system.release)))
			system.release();
	}

	void spawn(vec3 position, size_t num)
	{
		for(size_t i = 0; i < num; ++i)
			system.spawn(position, list.spawn());
	}
	
	void updateParticles()
 	{
		foreach(particle; list)
		{
			if(system.update(particle))
				list.markUnused(particle);
		}
	}
}

template MParticleBase()
{
	vec3 position = vec3.zero;
	vec3 velocity = vec3.zero;
	vec3 acceleration = vec3.zero;
	vec4 color = vec4.zero;
	float size = 0;
}

struct BufferedArrayManager(alias Base)
{
	struct Type
	{
		mixin Base;
		
		bool alive = false;
	}
	
	alias Type* ParticleT;
	
	BufferedArray!(Type) array;

	void create()
	{
		array.create();
	}
	
	void release()
	{
		array.release();
	}

	int opApply(int delegate(ref ParticleT) dg)
	{
		int result = 0;
		
		for(auto i = 0; i < array.length; ++i)
		{
			auto x = i in array;
			
			if(!x.alive)
				continue;
		
			if(cast(bool)(result = dg(x)))
				break;
		}
		
		return result;
	}
	
	ParticleT spawn()
	{
		foreach(k, v; array)
		{
			if(v.alive)
				continue;
				
			auto p = k in array;
			*p = Type.init;
			p.alive = true;
				
			return p;
		}
		
		Type p = Type.init;
		p.alive = true;
		
		array.append(p);
		
		return (array.length - 1) in array;
	}
	
	void markUnused(ParticleT p)
	{
		p.alive = false;
	}
}

struct IntrusiveListManager(alias Base)
{
	class ParticleT
	{
		mixin Base;
		mixin MLinkedList!(ParticleT);
		mixin MMemoryPool!(ParticleT, PoolFlags.Initialize);
	}
	
	static this()
	{
		with(ParticleSystemManager)
		{
			initFunctions ~= function { pool.create(512); };
			releaseFunctions ~= function { pool.release(); };
		}
	}
	
	static ParticleT.MemoryPool pool;
	ParticleT.LinkedList list;
	
	void release()
	{
		foreach(p; list)
			pool.free(p);
	}
	
	int opApply(int delegate(ref ParticleT) dg)
	{
		int result = 0;
		auto particle = list.first;
	
		while(particle)
		{
			auto next = particle.next;
			
			if(cast(bool)(result = dg(particle)))
				return result;
			
			particle = next;
   		}
		
		return result;
	}
	
	ParticleT spawn()
	{
		return list.attach(pool.allocate());
	}
	
	void markUnused(ParticleT p)
	{
		list.detach(p);
		pool.free(p);
	}	
}

template MSpriteRenderer(ParticleT)
{
	mat4 currentModelview;

	public override void registerForRendering(Camera camera)
	{
		if(sceneGraph.cameraData.shadowMap)
			return;
	
		sceneGraph.passBlended.add(camera, this, &render);
		currentModelview = camera.modelview;
	}

	private void render()
	{
		renderer.setRenderState(RenderState.Blending, true);
		renderer.setBlendFunc(BlendFunc.SrcAlpha, BlendFunc.OneMinusSrcAlpha);

		auto matData = currentModelview.ptr;

		vec3 right = vec3(matData[0], matData[4], matData[8]);
		vec3 up = vec3(matData[1], matData[5], matData[9]);

		renderer.setTexture(0, texture);

		// TODO: don't use GL directly
		glBegin(GL_QUADS);
		
		foreach(p; list)
		{
			auto s = p.size / 2;

			glColor4f(p.color.tuple);
			
			glTexCoord2f(0, 0);
			glVertex3f((p.position + (right + up) * -s).tuple);
			
			glTexCoord2f(1, 0);
			glVertex3f((p.position + (right - up) * s).tuple);
			
			glTexCoord2f(1, 1);
			glVertex3f((p.position + (right + up) * s).tuple);
			
			glTexCoord2f(0, 1);
			glVertex3f((p.position + (up - right) * s).tuple);
		}
		
		glEnd();

		renderer.setRenderState(RenderState.Blending, false);
	}
}

template MSmokeSystem(ParticleT)
{
	void create(char[] path)
	{
		scope inImage = DevilImage.load(Texture.findResourcePath(path).fullPath);
		auto outImage = new Image(inImage.width, inImage.height, ImageFormat.RGBA);
		
		for(auto x = 0; x < inImage.width; x++)
		{
			for(auto y = 0; y < inImage.height; y++)
			{
				outImage.setRed(x, y, inImage.getRed(x, y));
				outImage.setGreen(x, y, inImage.getGreen(x, y));
				outImage.setBlue(x, y, inImage.getBlue(x, y));
				outImage.setAlpha(x, y, inImage.getRed(x, y));
			}
		}

		texture = renderer.createTexture(outImage);
	}
	
	~this()
	{
		delete texture;
	}

	void spawn(vec3 position, ParticleT p)
	{
		p.position = position;
		p.size = (2.5f + 1 - 2 * Kiss.instance.toReal() / 5) * 0.8;
		
		p.velocity = vec3(1 - 2 * Kiss.instance.toReal(),
			1 - 2 * Kiss.instance.toReal(),
			1 - 2 * Kiss.instance.toReal());
		p.velocity *= 3;
		p.velocity = p.velocity.normalized() * 0.2;

		p.color = vec4(1, 1, 1, 0.5 + 0.5 * Kiss.instance.toReal());
	}
	
	bool update(ParticleT p)
	{
		const time = 0.1;
		
		p.velocity += p.acceleration * time;
		p.position += p.velocity * time;

		p.color.a -= 0.045 * time;
		p.size += 0.1 * time;
		p.velocity -= p.velocity * time * 0.2f;
		p.position += p.velocity * time;
		
		if(p.color.a < 0)
			return true;
		
		return false;		
	}
	
	mixin MSpriteRenderer!(ParticleT);
}

alias ParticleSystem!(IntrusiveListManager!(MParticleBase), MSmokeSystem) SmokeParticleSystem;

template MSparkParticle()
{
	mixin MParticleBase;
	
	int energy;
	vec3 addPos;
	float factor;
}

template MSparkSystem(ParticleT)
{
	float size, range, maxFactor;
	int maxEnergy;
	
	void create(char[] file, float size, float range, float maxFactor, int maxEnergy)
	{
		texture = Texture(file);
	
		this.size = size;
		this.range = range;
		this.maxFactor = maxFactor;
		this.maxEnergy = maxEnergy;
	}
	
	void release()
	{
		subRef(texture);
	}
	
	void spawn(vec3 position, ParticleT p)
	{
		float r = Kiss.instance.toInt(80, 100) / range;
		
		p.position = position;
		p.velocity = vec3(Kiss.instance.toReal(), Kiss.instance.toReal(),
			Kiss.instance.toReal()) * r - vec3.one * 0.5 * r;
		p.size = size;
		p.energy = maxEnergy;
		p.addPos = position;
		p.color = vec4.one;
		
		if(maxFactor)
			p.factor = maxFactor - maxFactor / Kiss.instance.toInt(1, 6);
		else
			p.factor = 0;
	}
	
	bool update(ParticleT p)
	{
		p.position += p.velocity;
				
		if(maxFactor)
			p.addPos = p.position - p.factor * p.velocity;
		
		p.color.a = 0.4f * p.energy / maxEnergy;
		
		if(--p.energy == 0)
			return true;
		
		return false;
	}
	
	mixin MSpriteRenderer!(ParticleT);
}

alias ParticleSystem!(IntrusiveListManager!(MSparkParticle), MSparkSystem) SparkParticleSystem;

class ParticleSystemManager
{
private:
	IParticleSystem[char[]] systems;
	
public:
	static void function()[] initFunctions, releaseFunctions;

	this()
	{
		foreach(f; initFunctions)
			f();
	}
	
	~this()
	{
		foreach(f; releaseFunctions)
			f();
	}

	void addSystem(char[] name, IParticleSystem system)
	{
		systems[name] = system;
	}
	
	IParticleSystem opIndex(char[] name)
	{
		return systems[name];
	}
	
	void update()
	{
		profile!("particles.update")
		({
			foreach(system; systems)
				system.updateParticles();
		});
	}
}

ParticleSystemManager particles;
