module defend.sim.Heightmap;

import tango.math.Math;

import xf.xpose2.Expose;
import xf.xpose2.Serialization;

import engine.image.Devil;
import engine.image.Image;
import engine.math.Rectangle;
import engine.math.Vector;
import engine.mem.Memory;
import engine.util.Resource : findResourcePath;

import defend.sim.Types;

class Heightmap
{
package:
	map_pos_t _size;

	// TODO: fixed point
	float maxHeight = 0;
	float[] heightMap;

	// TODO: decide if the randomization stuff can be pulled out of Heightmap,
	// to MapGenerator
	static float noise(int x)
	{
		x = (x << 13) ^ x;

		return (1.0f - ((x * (x * x * 15731 + 789221)
				+ 1376312589) &
				0x7fffffff) / 1073741824.0f);
	}

	static float cosInterpolate(float v1, float v2, float a)
	{
		float angle = a * PI;
		float prc = (1.0f - cos(angle)) * 0.5f;

		return v1 * (1.0f - prc) + v2 * prc;
	}

	float doOctave(uint o, float xf, float yf, int seed, float pers)
	{
		float freq = cast(float)pow(cast(real)2, o);
		float amp = cast(float)pow(cast(real)pers, o);

		float tx = xf * freq;
		float ty = yf * freq;

		int txi = cast(int)tx;
		int tyi = cast(int)ty;

		float fracx = tx - txi;
		float fracy = ty - tyi;

		final v1 = noise(txi + seed + 57 * tyi);
		final v2 = noise(txi + seed + 57 * tyi + 1);
		final v3 = noise(txi + seed + 57 * (tyi + 1));
		final v4 = noise(txi + seed + 57 * (tyi + 1) + 1);

		final i1 = cosInterpolate(v1, v2, fracx);
		final i2 = cosInterpolate(v3, v4, fracx);
		
		return cosInterpolate(i1, i2, fracy) * amp;
	}

public:
	mixin(xpose2("heightMap"));
	mixin xposeSerialization;
	
	void onUnserialized()
	{
		auto size = cast(int)sqrt(cast(float)heightMap.length);
		_size = map_pos_t(size, size);
	}

	this(map_pos_t _size, float maxHeight)
	{
		this._size = _size;
		this.maxHeight = maxHeight;

		heightMap.alloc((size.x + 1) * (size.y + 1));
	}

	~this()
	{
		heightMap.free();
	}

	map_pos_t size()
	{
		return _size;
	}

	void randomize(int seed, float noiseSize, float pers, int octaves)
	{
		for(uint x = 0; x < size.x; x++)
		{
			for(uint y = 0; y < size.y; y++)
			{
				final xf = (x / cast(float)size.x) * cast(float)noiseSize;
				final yf = (y / cast(float)size.y) * cast(float)noiseSize;
				final index = x + y * size.x;
				float total = 0.0f;

				for(uint o = 0; o < octaves; ++o)
					total += doOctave(o, xf, yf, seed, pers);

				int b = cast(int)(128 + total * 128);

				if(b < 0) b = 0;
				if(b > 255) b = 255;

				heightMap[index] = (b / 255.0) * maxHeight;
			}
		}
	}

	void loadFromImage(char[] file)
	{
		scope image = DevilImage.load(findResourcePath("heightmaps/" ~ file).fullPath);
		image.resize(size.x, size.y);

		for(uint x = 0; x < size.x; x++)
		{
			for(uint y = 0; y < size.y; y++)
			{
				final index = x + y * size.x;
				final red = cast(float)image.getRed(x, y);
				final white = cast(float)255.0;
				heightMap[index] = (red / white) * maxHeight;
			}
		}
	}

	void smooth()
	{
		assert(heightMap);

		float[] newMap;
		newMap.alloc((size.x + 1) * (size.y + 1));

		for(uint x = 0; x < size.x; x++)
		{
			for(uint y = 0; y < size.y; y++)
			{
				float totalHeight = 0.0f;
				int nodes = 0;
				final index = x + y * size.x;
				final neighbours = Rectangle!(int)(cast(int)x - 1, cast(int)y - 1, x + 1, y + 1);

				foreach(x1, y1; neighbours)
				{
					if(x1 >= 0 && x1 <= size.x &&
					   y1 >= 0 && y1 < size.y)
					{
						final index1 = x1 + y1 * size.x;
						totalHeight += heightMap[index1];
						++nodes;
					}
				}

				if(nodes == 0)
				{
					newMap[index] = heightMap[index];
					continue;
				}
				
				if(totalHeight != totalHeight)
					totalHeight = 1;

				newMap[index] = totalHeight / cast(float)nodes;
			}
		}

		heightMap.free();
		heightMap = newMap;
	}

	void multiply(Heightmap other)
	{
		for(uint x = 0; x < size.x; x++)
		{
			for(uint y = 0; y < size.y; y++)
			{
				final index = x + y * size.x;
				final indexOther = x + y * other.size.x;
				float a = heightMap[index] / maxHeight;
				float b = 1.0;

				if(x < other.size.x && y < other.size.y)
					b = other.heightMap[indexOther] / other.maxHeight;

				heightMap[index] = a * b * maxHeight;
			}
		}
	}

	void cap(float height)
	{
		maxHeight = 0.0;

		for(uint x = 0; x < size.x; x++)
		{
			for(uint y = 0; y < size.y; y++)
			{
				final index = x + y * size.x;

				heightMap[index] -= height;

				if(heightMap[index] < 0.0)
					heightMap[index] = 0.0;

				if(heightMap[index] > maxHeight)
					maxHeight = heightMap[index];
			}
		}
	}
	
	float getMaxHeight()
	{
		return maxHeight;
	}

	float getHeight(uint x, uint y)
	{
		assert(x < size.x);
		assert(y < size.y);

		return heightMap[x + y * size.x];
	}
	
	alias getHeight opIndex;

	void setHeight(uint x, uint y, float f)
	{
		assert(x < size.x);
		assert(y < size.y);

		heightMap[x + y * size.x] = f;
	}
	
	alias setHeight opIndexAssign;

	float[] floats()
	{
		return heightMap;
	}
}

// Util functions

float getHeightForImage(Heightmap heightmap, uint x, uint y, uint size)
{
	uint x2 = cast(uint)(cast(float)heightmap.size.x * (cast(float)x / cast(float)size));
	uint y2 = cast(uint)(cast(float)heightmap.size.y * (cast(float)y / cast(float)size));

	return heightmap.getHeight(x2, y2);
}

vec3 getNormalForImage(Heightmap heightmap, uint x, uint y, uint size)
{
	assert(size > 0);
	assert(x < size);
	assert(y < size);
	
	float x0, x1, y0, y1;
	float xl = 2.f;
	float yl = 2.f;
	
	if(x > 0)
	{
		x0 = getHeightForImage(heightmap, x - 1, y, size);
	}
	else
	{
		x0 = getHeightForImage(heightmap, x, y, size);
		xl *= .5f;
	}

	if(y > 0)
	{
		y0 = getHeightForImage(heightmap, x, y - 1, size);
	} 
	else
	{
		y0 = getHeightForImage(heightmap, x, y, size);
		yl *= .5f;
	}

	if(x+1 < size)
	{
		x1 = getHeightForImage(heightmap, x + 1, y, size);
	}
	else
	{
		x1 = getHeightForImage(heightmap, x, y, size);
		xl *= .5f;
	}

	if(y+1 < size)
	{
		y1 = getHeightForImage(heightmap, x, y + 1, size);
	}
	else
	{
		y1 = getHeightForImage(heightmap, x, y, size);
		yl *= .5f;
	}
	

	vec3 n1 = vec3(x0 - x1, xl, 0).normalized();
	vec3 n2 = vec3(0, yl, y1 - y0).normalized();
	vec3 normal = (n1 + n2).normalized();
	
	assert(normal.ok);
	assert(normal.length < 1.01f);
	
	return normal;
}
