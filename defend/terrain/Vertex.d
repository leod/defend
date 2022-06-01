module defend.terrain.Vertex;

public import engine.math.Vector;
import engine.rend.Vertex;

alias Vertex!(
	Member!(vec2, Format.Texture, 4),
	Member!(vec3, Format.Position)
) TerrainVertex;
	
	
/+
struct TerrainVertex
{
	static VertexFormat format;

	static this()
	{
		format = (new VertexFormat(TerrainVertex.sizeof)).
				add(VertexUsage.Texture1).
				add(VertexUsage.Texture2).
				add(VertexUsage.Texture3).
				add(VertexUsage.Texture4).
				add(VertexUsage.Position);
	}

	static TerrainVertex opCall(vec2 texture1, vec2 texture2,
	                            vec2 texture3, vec2 texture4,
	                            vec3 position)
	{
		TerrainVertex result;
		result.texture1 = texture1;
		result.texture2 = texture2;
		result.texture3 = texture3;
		result.texture4 = texture4;
		result.position = position;

		return result;
	}

	vec2 texture1;
	vec2 texture2;
	vec2 texture3;
	vec2 texture4;
	vec3 position;
}
+/
