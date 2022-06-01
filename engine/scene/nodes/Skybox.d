module engine.scene.Skybox;

import engine.rend.Renderer;
import engine.rend.Texture;
import engine.rend.IndexBuffer;
import engine.rend.VertexArray;
import engine.scene.Graph;
import engine.scene.Node;
import engine.scene.Camera;
import engine.util.Vertex;

private
{
	alias VertexTexPos vertex;
}

class Skybox : SceneNode
{
private:
	VertexArray[] vertices;
	Texture[] textures;
	
public:
	this(SceneNode parent, char[][] files ...)
	{
		super(parent);
	
		textures.length = files.length;
		vertices.length = files.length;

		foreach(i, file; files)
		{
			textures[i] = addRef(file);
			textures[i].clamp();
			vertices[i] = renderer.createVertexArray(vertex.format, 4, VertexArrayUsage.StaticDraw);
		}
		
		float onePixel = 1.0 / (textures[0].width * 1.5);
		float l = 10.0;
		float t = 1.0; //- onePixel;
		float o = 0.0; //+ onePixel;
		
		vertices[0].setVertices([vertex(-l, -l, -l, o, t), vertex(l, -l, -l, t, t),
		                         vertex(l, l, -l, t, o), vertex(-l, l, -l, o, o)]);
								 
		vertices[1].setVertices([vertex(l, -l, -l, o, t), vertex(l, -l, l, t, t),
		                         vertex(l, l, l, t, o), vertex(l, l, -l, o, o)]);
								 
		vertices[2].setVertices([vertex(l, -l, l, o, t), vertex(-l, -l, l, t, t),
		                         vertex(-l, l, l, t, o), vertex(l, l, l, o, o)]);
								 
		vertices[3].setVertices([vertex(-l, -l, l, o, t), vertex(-l, -l, -l, t, t),
		                         vertex(-l, l, -l, t, o), vertex(-l, l, l, o, o)]);
								 
		vertices[4].setVertices([vertex(l, l, l, o, o), vertex(-l, l, l, o, t),
		                         vertex(-l, l, -l, t, t), vertex(l, l, -l, t, o)]);
		
		vertices[5].setVertices([vertex(-l, -l, l, o, o), vertex(l, -l, l, o, t),
		                         vertex(l, -l, -l, t, t), vertex(-l, -l, -l, t, o)]);
								 
		foreach(array; vertices)
			array.synchronize();
	}
	
	~this()
	{
		foreach(texture; textures)
			subRef(texture);
		
		foreach(array; vertices)
			delete array;
	}
	
	override void process(Camera camera)
	{
		sceneGraph.addToRender(RenderPass.Skybox, this);
	}
	
	override void render()
	{
		foreach(i, array; vertices)
		{
			renderer.setTexture(0, textures[i]);
			renderer.draw(array, null, PrimitiveType.Quad);
		}
	}
}
