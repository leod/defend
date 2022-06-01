module defend.terrain.Patch;

import tango.math.Math : ceil;

import engine.util.Debug;
import engine.math.BoundingBox;
import engine.math.Matrix;
import engine.math.Misc;
import engine.math.Ray;
import engine.math.Rectangle;
import engine.math.Vector;
import engine.rend.IndexBuffer;
import engine.rend.opengl.Wrapper;
import engine.rend.Renderer;
import engine.rend.Texture;
import engine.scene.Camera;
import engine.scene.Graph;
import engine.scene.Node;
import engine.mem.Memory;
import engine.rend.VertexContainer;
import engine.rend.VertexContainerFactory;

import defend.sim.Heightmap;
import defend.terrain.Ranges;
import defend.terrain.Vertex;

class TerrainPatch : SceneNode
{
package:
	alias VertexContainer!(TerrainVertex, Usage.StaticDraw) Container;
	Container vertices_;
	
	IndexBuffer[4] indices; // levels of detail

	Heightmap heightmap;

	BoundingBox!(float) bbox;
	Rect rect;
	
	uint detailLevel = 0;

public:
	mixin MAllocator;

	float[3] minHeight;
	float[3] maxHeight;
	float minY;
	float maxY;

	bool intersectRay(Ray!(float) ray, ref float t, ref float u,
	                  ref float v, ref uint face)
	{
		float minT = float.max;
		uint currentFace = 0;
		
		for(uint i = 0; i < indices[0].length; i += 3)
		{
			uint index1 = indices[0].get(i);
			uint index2 = indices[0].get(i + 1);
			uint index3 = indices[0].get(i + 2);
			
			auto pos1 = vertices_.get(index1).position;
			auto pos2 = vertices_.get(index2).position;
			auto pos3 = vertices_.get(index3).position;

			bool result = ray.intersectTriangle(pos1, pos2, pos3, t, u, v);

			if(result && t < minT)
			{
				minT = t;
				face = currentFace;
				return true;
			}
			
			currentFace++;
		}
		
		if(minT != float.max)
			return true;
		else
			return false;
	}

	this(Heightmap heightmap, Rect rect)
	{
		super(null);
	
		this.heightmap = heightmap;
		this.rect = rect;

		final int width = rect.width;
		final int height = rect.height;
		final numberTriangles = width * height * 2;
		auto vertices = new TerrainVertex[numberTriangles];
		vertices_ = createVertexContainer!(Container)(vertices);
		bbox.max = vec3(-10_000, -10_000, -10_000);
		bbox.min = vec3( 10_000,  10_000,  10_000);

		minY = 10_000;
		maxY = 10_000;

		foreach(ref a; minHeight)
			a = 10_000;

		foreach(ref a; maxHeight)
			a = -10_000;

		for(int _z = rect.top, z = 0; _z <= rect.bottom; _z++, z++)
		{
			for(int _x = rect.left, x = 0; _x <= rect.right; _x++, x++)
			{
			    float h = heightmap.getHeight(_x, _z);
			    
			    minY = min(minY, h);
			    maxY = max(maxY, h);
			    
			    foreach(i, ref v; minHeight)
                {
                    if(h >= terrainMinRange[i] && h <= terrainMaxRange[i])
                        v = min(v, h);
                }
                
                foreach(i, ref v; maxHeight)
                {
                    if(h <= terrainMaxRange[i] && h <= terrainMaxRange[i])
                        v = max(v, h);
                }
			    
				vec2 tex1 = vec2(cast(float)_x / cast(float)heightmap.size.x,
				                 cast(float)_z / cast(float)heightmap.size.y);
				vec2 tex2 = tex1 * 16;
				vec2 tex3 = tex1;
                vec2 tex4 = tex3 * 32;
                
				vec3 pos = vec3(_x, h, -_z);

				vertices_.set(z * (width + 1) + x,
					          TerrainVertex(tex1, tex2, tex3, tex4, pos));
				
				bbox.addPoint(pos);
			}
		}
		
		vertices_.synchronize();

		//const uint lod = 10;
		
		int detail = 1;
		
		for(uint lod = 1; lod < indices.length + 1; lod++)
		{
			auto buffer = lod - 1;
			//auto detail = lod * 2;
			auto w = cast(int)ceil(rect.width / cast(float)(detail));
			auto h = cast(int)ceil(rect.height / cast(float)(detail));
			
			indices[buffer] = renderer.createIndexBuffer(w * h * 6);

			uint index = 0;

			for(int _z = rect.top, z = 0; _z < rect.bottom;_z += detail, z += detail)
			{
				for(int _x = rect.left, x = 0; _x < rect.right; _x += detail, x += detail)
				{
					void setIndex(int z, int x)
					{
						if(z > height)
							z = height;
							
						if(x > width)
							x = width;
					
						indices[buffer].set(index++, z * (width + 1) + x);
					}

					setIndex(z, x);
					setIndex(z, x + detail);
					setIndex(z + detail, x);
					
					setIndex(z + detail, x);
					setIndex(z, x + detail);
					setIndex(z + detail, x + detail);
				}
			}
			
			detail *= 2;
		}
	}

	~this()
	{
		foreach(buffer; indices) delete buffer;
		delete vertices_;
	}

	BoundingBox!(float) boundingBox()
	{
		return bbox;
	}
	
	Rect area()
	{
		return rect;
	}

	override void registerForRendering(Camera camera)
	{
		/*auto distance = camera.position.distance(bbox.min);
		
		if(distance < 30) detailLevel = 0;
		else if(distance < 50) detailLevel = 1;
		else if(distance < 60) detailLevel = 2;
		else detailLevel = 3;*/
		
		detailLevel = 0;
	
		visible = camera.frustum.boundingBoxVisible(bbox);
	}

	void render()
	{
		vertices_.draw(Primitive.Triangle, indices[detailLevel]);
	}
	
	void onHeightmapChange(int x, int y)
	{
		auto h = heightmap.getHeight(x, y);
		
		int x2 = x - rect.left;
		int y2 = y - rect.top;
		int idx = y2 * (rect.width + 1) + x2;
		
		auto v = vertices_.get(idx);
		v.position.y = h;
		
		//traceln("[{},{}]/[{},{}];r: {};v: {};i: {}", x, y, x2, y2, rect, v.position, idx);
		
		// TODO: bbox needs to be completely recalculated
		bbox.addPoint(v.position);
		
		// TODO: minHeight and maxHeight need to be completely recalculated
		foreach(i, ref f; minHeight)
		{
			if(h >= terrainMinRange[i] && h <= terrainMaxRange[i])
				f = min(f, h);
		}
		
		foreach(i, ref f; maxHeight)
		{
			if(h <= terrainMaxRange[i] && h <= terrainMaxRange[i])
				f = max(f, h);
		}
		
		vertices_.set(idx, v);
		vertices_.synchronize();
	}
}
