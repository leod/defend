module engine.list.BufferedArray;

import tango.core.Memory;

import engine.util.Swap;
import engine.mem.Memory;
import engine.list.Sort : sort;

struct BufferedArray(T)
{
private:
	uint chunkSize = 1024;
	bool useGC = false;
	bool shrink = false;

	T[] buffer;
	uint top = 0; // Number of used slots in the buffer

	// Create or resize the memory buffer
	void arrangeBuffer()
	{
		uint delta = buffer.length - top;
		bool change;
		uint newSize;
		bool firstChange = (buffer.length == 0);
		
		// Do we need to enlarge the buffer?
		if(delta == 0)
		{
			change = true;
			newSize = buffer.length + chunkSize;
		}
		
		// Do we need to shrink the buffer?
		if(shrink)
		{
			if(delta > chunkSize)
			{
				change = true;
				newSize = buffer.length - chunkSize;
			}
		}
		
		// Resize the buffer
		if(change)
		{
			buffer.realloc(newSize);
			
			if(useGC)
			{
				if(!firstChange)
						GC.removeRange(cast(void*)buffer.ptr);
				
				GC.addRange(cast(void*)buffer.ptr, T.sizeof * buffer.length);
			}
		}
	}

public:
	void create(uint chunkSize = 1024, bool useGC = false, bool shrink = false)
	{
		this.chunkSize = chunkSize;
		this.useGC = useGC;
		this.shrink = shrink;
		
		// Create the buffer
		arrangeBuffer();		
	}
	
	void release()
	{
		if(buffer)
		{
			buffer.free();
			
			if(useGC)
				GC.removeRange(cast(void*)buffer.ptr);
		}
	}

	/**
	 * Append an element to the list
	 */
	BufferedArray* append(T element)
	{
		// Check if the buffer needs to be resized
		arrangeBuffer();
		
		// Add the element to the buffer
		buffer[top] = element;
		top++;
		
		return this;
	}
	
	alias append opCat;
	alias append opCatAssign;
	
	/**
	 * Convert to array (does not consume memory)
	 */
	T[] toArray()
	{
		return buffer[0 .. top];
	}
	
	/**
	 * Return an element of the list
	 */
	T get(uint index)
	in
	{
		assert(index < top, "index out of bounds");
	}
	body
	{
		return buffer[index];
	}
	
	alias get opIndex;
	
	T* opIn_r(uint index)
	{
		return &buffer[index];
	}
	
	/**
	 * Number of elements
	 */
	uint length()
	{
		return top;
	}
	
	/**
	 * Reset the list
	 */
	void reset()
	{
		top = 0;
		arrangeBuffer();
	}
	
	/**
	 * Removes an element by its index
	 */
	void remove(uint index)
	{
		assert(top > index);
		scope(exit) top--;
		
		if(top == 1) return;
		
		buffer[index] = buffer[top - 1];
	}
	
	/**
	 * Removes n elements from the top of the list
	 */
	void pop(uint n = 1)
	in
	{
		assert(n <= top); 
	}
	body
	{
		top -= n;
		arrangeBuffer();
	}
	
	/** 
	 * Sort the list
	 */
	void sort(bool delegate(T, T) c)
	{
		.sort(toArray(), c);
	}
	
	/**
	 * foreach
	 */
	int opApply(int delegate(ref T) dg)
	{
		int result = 0;
		
		for(uint i = 0; i < top; i++)
		{
			if(cast(bool)(result = dg(buffer[i])))
				break;
		}
		
		return result;
	}
	
	/+int opApply(int delegate(ref T*) dg)
	{
		int result = 0;
		
		for(uint i = 0; i < top; i++)
		{
			if(cast(bool)(result = dg(&buffer[i])))
				break;
		}
		
		return result;
	}+/
	
	int opApply(int delegate(ref uint, ref T) dg)
	{
		int result = 0;
		
		for(uint i = 0; i < top; i++)
		{
			if(cast(bool)(result = dg(i, buffer[i])))
				break;
		}
		
		return result;
	}
}

unittest
{
	BufferedArray!(uint) list;
	list.create(5);
	
	list ~= 99;
	list ~= 5;
	list ~= 5;
	list ~= 100;
	list ~= 101;
	list ~= 20;
	
	list.sort((uint t1, uint t2) { return t1 < t2; });

	assert(list[0] == 5);
	assert(list[1] == 5);
	assert(list[2] == 20);
	assert(list[3] == 99);
	assert(list[4] == 100);
	assert(list[5] == 101);
	
	list.remove(3);
	
	assert(list[0] == 5);
	assert(list[1] == 5);
	assert(list[2] == 20);
	assert(list[4] == 100);
	assert(list[3] == 101);
	
	list.append(2);
	
	assert(list[0] == 5);
	assert(list[1] == 5);
	assert(list[2] == 20);
	assert(list[4] == 100);
	assert(list[3] == 101);
	assert(list[5] == 2);
	
	list.remove(0);
	
	assert(list[0] == 2);
	assert(list[4] == 100);
	
	list.remove(0);
	list.remove(0);
	list.remove(0);
	list.remove(0);
	
	assert(list.length == 1);
	list.remove(0);
	assert(list.length == 0);
}
