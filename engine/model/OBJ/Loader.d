module engine.model.obj.Loader;

import engine.model.Instance : Instance;
import engine.model.Mesh : Mesh;
import engine.model.Model : Model, registerLoader;
import engine.model.obj.Mesh : ObjMesh, ObjInstance;
import engine.model.obj.Model : ObjModel;
import engine.rend.IndexBuffer : IndexBuffer;
import engine.rend.Texture : Texture;
import engine.rend.VertexContainer : Primitive;
import engine.util.Vertex : calcNormals;
import engine.util.RefCount : addRef;

import tango.core.Traits : isFloatingPointType;
import tango.io.FilePath : FilePath;
import tango.io.device.File : File;
import tango.io.stream.Lines : Lines;
import tango.text.convert.Float : toFloat;
import tango.text.convert.Integer : toInt;
import tango.text.Util : lines, patterns, split;

import tango.util.log.Trace;

private
{
	alias char Char;
	alias Char[] Line;

	/*
		Put the numers spllited by <delim> in <part> into the
		<container> and skip empty parts if <skip> is true, otherwise
		fill 0
	*/
	void toNum(T)(Line part, ref T container, Line delim, bool skip)
	{
		alias typeof(T.dim) Size;
		alias T.flt Type;
		static assert(isFloatingPointType!(Type)); // only reals in models

		Size i = 0;

		foreach(part; patterns(part, delim))
		{
			if(T.dim == i)
				break;

			if(!part.length)
			{
				if(skip)
					continue;
				else
					container.cell[i++] = cast(Type)0;
			}

			container.cell[i++] = toFloat(part);
		}
	}
}

static this()
{
	registerLoader(".obj", &loadObj);
}

static Model loadObj(FilePath path)
{
	struct Material
	{
		static Material opCall(FilePath texturePath)
		{
			Material material;
			material.texture = Texture(texturePath);
			return material;
		}

		Texture texture;
	}

	uint faceAmount;
	Mesh.Vertex.Position[] positions;
	Mesh.Vertex.Normal[] normals;
	Mesh.Vertex.Texture[] textures;
	Mesh.Vertex[] tempVertices;
	ObjMesh[] meshes;
	Material[Line] materials;
	Material* currentMaterial;
	Instance.BoundingBox meshBox;
	Instance.BoundingBox modelBox;
	auto objPath = FilePath(path.parent);

	void finishedMesh()
	{
		if(!normals.length)
			calcNormals(tempVertices);

		meshes ~= new ObjMesh(
			(3 == faceAmount) ? Primitive.Triangle : Primitive.Quad,
			currentMaterial ? currentMaterial.texture : null,
			tempVertices);
	//		meshBox);
	}

	void parseMTL(FilePath mtlPath)
	{
		char[] lastname;

		foreach(line; new Lines!(char)(new File(mtlPath.toString)))
		{
			if(8 > line.length)
				continue;

			switch(line[0 .. 6])
			{
			case "newmtl":
				lastname = line[7 .. $];
				break;
			case "map_Kd":
				materials[lastname.dup] = Material(
					objPath.dup.append(line[7 .. $]));
				break;
			default:
				break;
			}
		}
	}

	foreach(line; new Lines!(char)(new File(path.toString)))
	{
		if(!line.length || '\n' == line[0] || '\r' == line[0])
			continue;

		switch(line[0])
		{
			case 'o':
			case 'g':
				if(!faceAmount)
					break;

				finishedMesh();
				tempVertices = [];
				faceAmount = 0;
				currentMaterial = null;
				break;
			case 'v':
				if(3 > line.length)
					continue;

				Char next = line[1];

				if('t' != next && 'n' != next && ' ' != next)
					continue;

				size_t offset = ' ' == next ? 2 : 3;

				switch(next)
				{
				case 't':
					alias Mesh.Vertex.Texture MTexture;
					MTexture texture = MTexture.zero;
					toNum(line[offset .. $], texture, " ", true);
					texture.y = 1 - texture.y;
					textures ~= texture;
					break;
				case 'n':
					alias Mesh.Vertex.Normal MNormal;
					MNormal normal = MNormal.zero;
					toNum(line[offset .. $], normal, " ", true);
					normals ~= normal;
					break;
				case ' ':
					alias Mesh.Vertex.Position MPosition;
					MPosition position = MPosition.zero;
					toNum(line[offset .. $], position, " ", true);
					positions ~= position;
					break;
				default:
					// unknown next char after v in object file
					assert(false);
					break;
				}
				break;
			case 'f':
				if(3 > line.length)
					continue;

				if(!faceAmount)
					foreach(c; line)
						if(' ' == c)
							++faceAmount;

				foreach(lpart; patterns(line[2 .. $], " "))
				{
					Mesh.Vertex vertex;
					ubyte i;

					foreach(npart; patterns(lpart, "/"))
					{
						size_t num = toInt(npart);

						if(!num)
							continue;

						num -= 1;

						switch(i)
						{
						case 0:
							vertex.position = positions[num];

							modelBox.addPoint(vertex.position);
							meshBox.addPoint(vertex.position);
							break;
						case 1:
							vertex.texture = textures[num];
							break;
						case 2:
							vertex.normal = normals[num];
							break;
						default:
							assert(false);
							break;
						}

						++i;
					}

					tempVertices ~= vertex;
				}

				break;
			case 'm':
				if(7 < line.length && "mtllib" == line[0 .. 6])
					parseMTL(objPath.dup.append(line[7 .. $]));
				break;
			case 'u':
				if(7 < line.length && "usemtl" == line[0 .. 6])
				{
					currentMaterial = line[7 .. $] in materials;
					assert(currentMaterial);
				}
				break;
			default:
				break;
		}
	}

	finishedMesh();

	return new ObjModel(meshes, modelBox);
}
