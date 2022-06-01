module engine.mem.ArrayPool;

import engine.mem.Memory;
import engine.list.Queue;

struct ArrayPool(T)
{
private:
	uint _size;
	uint _length;
	uint _used;

	T[] buffer;
	Queue!(T*) freeParts;
	
public:
	uint size() { return _size; }
	uint length() { return _length; }
	uint used() { return _used; }

	void create(uint _size, uint _length)
	{
		this._size = _size;
		this._length = _length;

		buffer.alloc(size * length);
		freeParts.create(length + 1);
		
		for(uint i = 0; i < length; i++)
			freeParts.push(buffer.ptr + i * size);
	}
	
	void release()
	{
		.free(buffer);
		freeParts.release();
	}
	
	T[] allocate()
	in
	{
		assert(used < length);
	}
	out(result)
	{
		assert(result.length == size);
	}
	body
	{
		_used++;
		
		return freeParts.pop[0 .. size];
	}
	
	void free(T[] buf)
	in
	{
		assert(buf.length == size);
		assert(used > 0);
	}
	body
	{
		_used--;
		
		buf[0 .. $] = T.init;
		freeParts.push(buf.ptr);
	}
}

version(UnitTest)
	import engine.util.UnitTest;

unittest
{
	ArrayPool!(int) pool;
	pool.create(5, 10);
	
	assert(pool.size == 5);
	assert(pool.length == 10);
	
	auto slice = pool.allocate();
	assert(slice[0] == int.init);
	assert(slice[1] == int.init);
	assert(slice[2] == int.init);
	assert(slice[3] == int.init);
	assert(slice[4] == int.init);
	
	assert(pool.used == 1);
	assert(slice.length == 5);
	
	slice[0] = 5;
	pool.free(slice);
	
	slice = pool.allocate();
	assert(slice[0] == int.init);
	assert(slice[1] == int.init);
	assert(slice[2] == int.init);
	assert(slice[3] == int.init);
	assert(slice[4] == int.init);
	
	int[][] slices;
	slices.length = pool.length - 1;
	
	foreach(ref s; slices)
	{
		s = pool.allocate();
	}
	
	assertException!(AssertException)(pool.allocate());
}
