module engine.util.Array;

import engine.mem.Memory;

T dupAA(T : K[V], K, V)(T t)
{
	T r;
	
	foreach(k, v; t)
		r[k] = v;
		
	return r;
}

bool hasElement(T)(T[] array, T what)
{
	foreach(element; array)
	{
		if(element == what)
			return true;
	}
	
	return false;
}

T[] removeElement(T, U)(ref T[] array, U what, bool changeLength = true)
{
	foreach(int i, element; array)
	{
		if(element == what)
		{
			array = array.remove(i, changeLength);
			break;
		}
	}
	
	return array;
}

void swapRemove(T)(ref T[] array, int index)
{
	array[index] = array[$ - 1];
	array.length = array.length - 1;
}

// From Jarrett, thanks!

T[] copyFrom(T)(T[] self, T[] other)
{
	assert(self.length == other.length);
	
	for(size_t i = 0; i < self.length; i++)
		self[i] = other[i];
		
	return self;
}

T[] remove(T)(T[] self, int index, bool changeLength = true)
{
	assert(self.length > 0);

	self[index .. $ - 1].copyFrom(self[index + 1 .. $]);
	if(changeLength) self.length = self.length - 1;
	
	return self;
}

unittest
{
	assert([1, 2, 3, 4].remove(3) == [1, 2, 3]);
	assert([1, 2, 3, 4].remove(0) == [2, 3, 4]);
	assert([1, 2, 3, 4].remove(1) == [1, 3, 4]);
	assert([1].remove(0) == cast(int[])[]);
}

// -----------------------------------------------------------------------

struct Array2D(T)
{
private:
	T[] data;

	int _width;
	int _height;

	struct Iterator
	{
		Array2D* array;
		int x, y, w, h;
		
		int opApply(int delegate(ref T) dg)
		{
			for(int _x = x; _x < x + w; _x++)
			{
				for(int _y = y; _y < y + h; _y++)
				{
					if(auto result = dg(array.data[_x + _y * array.width]))
						return result;
				}
			}
			
			return 0;
		}
		
		int opApply(int delegate(ref int, ref int, ref T) dg)
		{
			for(int _x = x; _x < x + w; _x++)
			{
				for(int _y = y; _y < y + h; _y++)
				{
					if(auto result = dg(_x, _y, array.data[_x + _y * array.width]))
						return result;
				}
			}
			
			return 0;
		}
	}

public:
	void create(int width, int height)
	{
		this._width = width;
		this._height = height;
	
		data.alloc(width * height);
	}
	
	void release()
	{
		data.free();
	}
	
	uint width()
	{
		return _width;
	}
	
	uint height()
	{
		return _height;
	}
	
	T opIndex(int x, int y)
	{
		assert(x + y * width < data.length);
		return data[x + y * width];
	}
	
	T opIndexAssign(T value, int x, int y)
	{
		return data[x + y * width] = value;
	}
	
	void fill(T value, int x, int y, int w, int h)
	{
		foreach(ref x; iterate(x, y, w, h))
			x = value;
	}
	
	Iterator iterate(int x, int y, int w, int h)
	{
		Iterator result = void;
		result.array = this;
		result.x = x;
		result.y = y;
		result.w = w;
		result.h = h;
		
		return result;
	}
	
	Iterator iterate()
	{
		return iterate(0, 0, width, height);
	}
	
	void reset()
	{
		data[] = T.init;
	}
}
