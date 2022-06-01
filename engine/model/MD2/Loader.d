module engine.model.MD2.Loader;

import engine.model.MD2.Mesh;
import engine.model.MD2.Model : MD2Model;
import engine.model.Mesh : Mesh;
import engine.model.Model : registerLoader, Model;
import engine.rend.Texture : Texture;
import engine.util.Config : Config;

import tango.io.device.File : File;
import tango.io.FilePath : FilePath;
import xf.omg.core.LinearAlgebra : vec3, vec3ub;

static this()
{
	registerLoader(".md2.cfg", &loadMD2);
}

Model loadMD2(FilePath path)
{
	scope config = new Config(path.toString());
	scope file = new File(path.dup.folder ~ config.string("model"));
	scope(exit) file.close();
		
	// Read the header
	MD2Header header;
	file.read((cast(ubyte*)&header)[0 .. header.sizeof]);

	if(header.ident != 844121161 || header.ver != 8)
		throw new Exception("broken md2 file");
		
	// Read texture coordinates and triangles
	MD2TexCoord[] texCoords = new MD2TexCoord[header.numTexCoords];
	MD2Triangle[] triangles = new MD2Triangle[header.numTriangles];
		
	file.seek(header.offTexCoords);
	file.read((cast(ubyte*)texCoords.ptr)[0 .. MD2TexCoord.sizeof * texCoords.length]);

	file.seek(header.offTriangles);
	file.read((cast(ubyte*)triangles.ptr)[0 .. MD2Triangle.sizeof * triangles.length]);
		
	// Read frames
	MD2Frame[] frames = new MD2Frame[header.numFrames];
	
	{
		auto vertices = new MD2Vertex[header.numVertices];
		scope(exit) delete vertices;
		
		vec3 scale;
		vec3 translate;
		ubyte[16] name;
		
		file.seek(header.offFrames);
	
		foreach(ref frame; frames)
		{
			file.read((cast(ubyte*)&scale)[0 .. vec3.sizeof]);
			file.read((cast(ubyte*)&translate)[0 .. vec3.sizeof]);
			file.read(name[]);
			file.read((cast(ubyte*)vertices)[0 .. MD2Vertex.sizeof * vertices.length]);
				
			frame.positions = new vec3[header.numVertices];
				
			for(uint i = 0; i < header.numVertices; i++)
			{
				frame.positions[i] = scale * vertices[i].pos + translate;
				frame.boundingBox.addPoint(frame.positions[i]);
			}
		}
	}

	Mesh.Vertex[] vertices = new Mesh.Vertex[header.numTriangles * 3];

	for(size_t i = 0; i < header.numTriangles; i++)
	{
		for(size_t j = 0; j < 3; j++)
		{
			auto idx = i * 3 + j;

			vertices[idx].texture.x =
				cast(Mesh.Vertex.Texture.flt)texCoords[
					triangles[i].texCoords[j]].s / header.skinWidth;

			vertices[idx].texture.y =
				1 -
				cast(Mesh.Vertex.Texture.flt)
					texCoords[triangles[i].texCoords[j]].t / header.skinHeight;
		}
	}

	MD2Mesh[] meshes;
	meshes ~= new MD2Mesh(
		vertices,
		Texture(
			FilePath(path.folder)
			.append(config.string("texture"))),
		header,
		triangles,
		frames,
		header.numVertices);

	return new MD2Model(meshes);
}
