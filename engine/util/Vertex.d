module engine.util.Vertex;

public
{
	import engine.math.Vector;
}

import engine.rend.Vertex;

private
{
	alias Member!(vec3, Format.Position) PositionMember;
	alias Member!(vec2, Format.Texture) TextureMember;
	alias Member!(vec4, Format.Diffuse) ColorMember;
	alias Member!(vec3, Format.Normal) NormalMember;
}

alias Vertex!(TextureMember, PositionMember) VertexTexPos;
alias Vertex!(TextureMember, PositionMember, ColorMember) VertexTexPosCol;
alias Vertex!(TextureMember, PositionMember, NormalMember) VertexTexPosNor;

void calcNormals(T)(T[] vertices)
{
	static assert(hasPosition!(T));
	static assert(hasNormal!(T));

	for(size_t i = 0; i < vertices.length; i += 3)
	{
		auto v1 = &vertices[i];
		auto v2 = &vertices[i + 1];
		auto v3 = &vertices[i + 2];

		v1.normal = v2.normal = v3.normal = 
			cross(
				v2.position - v1.position,
				v3.position - v1.position)
			.normalized();
	}
}

