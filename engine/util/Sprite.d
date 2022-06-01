module engine.util.Sprite;

import engine.image.Image;
import engine.util.Swap;
import engine.mem.Memory;
import engine.util.Vertex : VertexTexPos;
import engine.math.Vector;
import engine.math.Matrix;
import engine.math.Rectangle;
import engine.rend.Texture;
import engine.rend.Renderer;
import engine.rend.VertexContainer : Primitive, Usage, VertexContainer;
import engine.rend.VertexContainerFactory;

class Sprite
{
private:
	alias VertexTexPos Vertex;
	alias VertexContainer!(Vertex, Usage.StaticDraw) Container;

	Container vertices_;
	Texture _texture;
	Rect area;

	vec2 _scaling = vec2.one;

	void createBuffer(Vertex.Texture begin, Vertex.Texture end,
	                  bool reverse)
	{
		if(reverse)
			swap(begin.y, end.y);

		auto vertices = 
		[
			Vertex
			(
				Vertex.Texture(begin.x, begin.y),
				Vertex.Position(0, 0, 0)
			),
			Vertex
			(
				Vertex.Texture(end.x, begin.y),
				Vertex.Position(width, 0, 0)
			),
			Vertex
			(
				Vertex.Texture(end.x, end.y),
				Vertex.Position(width, height, 0)
			),
			Vertex
			(
				Vertex.Texture(begin.x, end.y),
				Vertex.Position(0, height, 0)
			)
		];

		vertices_ = createVertexContainer!(Container)(vertices.dup);
	}

public:
	mixin MAllocator;

	uint width() { return area.width; }
	uint height() { return area.height; }
	Texture texture() { return _texture; }
	Rect rect() { return area; }

	void scaling(vec2 s) { _scaling = s; }
	void scaling(vec2.flt s) { scaling = vec2(s, s); }

	this(char[] path, bool reverse = false)
	{
		this(Texture.get(path), reverse);
	}

	this(Texture _texture, bool reverse = false)
	{
		this(_texture, Rect(0, 0, _texture.width, _texture.height), reverse);
	}

	this(Texture _texture, Rect area, bool reverse = false)
	{
		this._texture = addRef(_texture);
		this.area = area;
		
		auto begin = vec2(cast(float)area.left / texture.width,
						  cast(float)area.top / texture.height);
		
		auto end = vec2(cast(float)area.right / texture.width,
						cast(float)area.bottom / texture.height);
						
		createBuffer(begin, end, reverse);
	}
	
	this(vec2i size, bool reverse = false)
	{
		area = Rect(0, 0, size.x, size.y);
		createBuffer(vec2.zero, vec2.one, reverse);
	}
	
	~this()
	{
		delete vertices_;
		
		if(texture)
			subRef(texture);
	}

	void render(Texture otherTexture = null)
	{
		renderer.setTexture(0, (otherTexture !is null) ? otherTexture : texture);
		vertices_.draw(Primitive.Quad);
	}
	
	void render(vec2 position, Texture otherTexture = null)
	{
		renderer.pushMatrix();
		renderer.translate(position.x, position.y, 0.0);
		renderer.scale(_scaling.tuple, 0.0);
		
		render(otherTexture);
		
		renderer.popMatrix();
	}
	
	void render(vec2i position, Texture otherTexture = null)
	{
		render(vec2.from(position), otherTexture);
	}
}
