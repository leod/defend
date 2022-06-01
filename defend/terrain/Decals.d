module defend.terrain.Decals;

import tango.math.Math;

import engine.rend.Renderer;
import engine.rend.VertexContainer;
import engine.rend.VertexContainerFactory;
import engine.rend.Vertex;
import engine.math.Vector;
import engine.util.Debug;
import engine.mem.Memory;

import defend.sim.Heightmap;

class Decals
{
public:
	enum Type
	{
		Blood,
		Unchi
	}

private:
	alias .Vertex!(Member!(vec3, Format.Position),
	               Member!(vec2, Format.Texture),
	               Member!(vec3, Format.Diffuse)) Vertex;
	alias .VertexContainer!(Vertex, Usage.DynamicDraw) VertexContainer;
	
	const MAX_DECALS = 1024;
	
	struct Container
	{
		VertexContainer vertices;
		int numUsed;
	}
	
	Container[Type.max + 1] containers; // TODO: one container for each patch or something
	
	Heightmap heightmap;
	
public:
	this(Heightmap heightmap)
	{
		this.heightmap = heightmap;
		
		foreach(ref c; containers)
		{
			Vertex[] hack; hack.length = MAX_DECALS * 4;
			c.vertices = createVertexContainer!(typeof(c.vertices))(hack);
		}
	}
	
	~this()
	{
		foreach(ref c; containers)
			delete c.vertices;
	}
	
	void add(Type type, vec2 pos)
	{
	/+	int decalSize = 1; // tmp
	
		void addVertex(vec2 offset)
		{
			Vertex vertex;
		}
	
		int leftX = cast(int)floor(pos.x);
		int rightX = cast(int)ceil(pos.x);
		int topY = cast(int)floor(pos.y);
		int bottomY = cast(int)ceil(pos.y);
		
		Vertex v;
		
		v.position.x = pos.x;
		v.position.z = -pos.y;
		v.position.y = heightmap[cast(
		
		vec2i start = vec2i.from(pos);
		
		for(int x = 0; x < decalSize; ++x)
		{
			for(int y = 0; y < decalSize; ++y)
			{
				Vertex makeVertex(vec2i p)
				{
					vec2 f = pos + vec2.from(p);
					vec2i i = vec2i.from(f);
				
					Vertex v;
					v.texture = vec2(cast(float)p.x / decalSize,
									 1.0f - cast(float)p.y / decalSize);
					v.position.x = f.x;
					v.position.z = -f.y;
					
					vec2i b = p;
					
					if(i.x < f.x)
					{
						assert(i < heightmap.size.width);
						b.x = i.x + 1;
					}
					else if(i.x > f.x)
					{
						assert(i > 0);
						
					}
					
					return v;
				}
				
				void addVertex(vec2i p)
				{
					containers[type].vertices.set(containers[type].numUsed++,
				                                  makeVertex(p));
				}

				addVertex(vec2i(x, y));
				addVertex(vec2i(x + 1, y));
				addVertex(vec2i(x + 1, y + 1));
				addVertex(vec2i(x, y + 1));
			}
		}
		
		containers[type].vertices.synchronize();+/
	}
	
	import engine.rend.opengl.Wrapper;
	
	void render()
	{
		renderer.setTexture(0, Texture.get("blood.png"));
		renderer.setRenderState(RenderState.Blending, true);
		
		scope(exit)
		{
			renderer.setTexture(0, null);
			renderer.setRenderState(RenderState.Blending, false);
		}
		
		glPolygonOffset(-20, -20);
		glEnable(GL_POLYGON_OFFSET_FILL);
		containers[Type.Blood].vertices.draw(Primitive.Quad, null, 0, containers[Type.Blood].numUsed);
		glDisable(GL_POLYGON_OFFSET_FILL);
	}
}
