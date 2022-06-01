module engine.list.Queue;

import tango.core.Memory;

import engine.util.Array;
import engine.mem.Memory;
import engine.math.Misc;

struct Queue(T)
{
private:
	uint chunkSize;
	bool enlarge;

	T[] elements;
	
	uint writePosition;
	uint readPosition;

public:
	void create(uint chunkSize, bool enlarge = true)
	{
		this.chunkSize = chunkSize;
		this.enlarge = enlarge;
		
		elements.alloc(chunkSize);
		GC.addRange(elements.ptr, T.sizeof * elements.length);
		
		writePosition = readPosition = 0;	
	}
	
	void release()
	{
		GC.removeRange(elements.ptr);
		elements.free();	
	}
	
	void push(T element)
	{
		uint position = writePosition + 1;
		
		if(position == elements.length)
			position = 0;
		
		if(enlarge)
		{
			if(position == readPosition)
			{
				elements.realloc(elements.length + 1);
				
				GC.removeRange(elements.ptr);
				GC.addRange(elements.ptr, T.sizeof * elements.length);

				for(int i = elements.length - 1; i > position; i--)
					elements[i] = elements[i - 1];
				
				readPosition++;
			}
		}
		else
			assert(position != elements.length, "overflow");

		writePosition = position;
		elements[writePosition] = element;
	}
	
	T pop()
	{
		assert(writePosition != readPosition, "underflow");
		
		readPosition++;
		
		if(readPosition == elements.length)
			readPosition = 0;

		return elements[readPosition];
	}
	
	T top()
	{
		uint position = readPosition + 1;
		if(position == elements.length)
			position = 0;
		
		return elements[position];
	}

	void reset()
	{
		writePosition = 0;
		readPosition = 0;
	}
	
	uint bufferSize()
	{
		return elements.length;
	}
	
	uint count()
	{
		int delta = cast(int)writePosition - cast(int)readPosition;
		if(delta >= 0) return delta;
		
		return elements.length + delta;
	}

	bool empty()
	{
		return count == 0;
	}
	
	int opApply(int delegate(ref T) dg)
	{
		int result = 0;
		
		for(uint i = readPosition + 1; i <= writePosition; i++)
		{
			if(cast(bool)(result = dg(elements[i])))
				break;
		}
		
		return result;
	}
	
	int opApplyReverse(int delegate(ref T) dg)
	{
		if(writePosition == 0)
			return 0;
		
		int result = 0;
		
		for(uint i = writePosition - 1; i >= readPosition; i--)
		{
			if(cast(bool)(result = dg(elements[i])))
				break;
		}
		
		return result;
	}
}

unittest
{
	Queue!(uint) queue;
	queue.create(3);
	
	assert(queue.empty);
	
	queue.push(0);
	assert(!queue.empty);
	assert(queue.top == 0),
	
	queue.push(1);
	queue.push(2);
	
	assert(queue.count == 3);
	assert(queue.top == 0);
	assert(queue.pop() == 0);
	assert(queue.count == 2);
	
	queue.push(3);
	queue.push(4);
	
	assert(queue.count == 4);
	assert(queue.top == 1);
	assert(queue.pop() == 1);
	assert(queue.count == 3);
	
	queue.push(5);
	queue.push(6);
	queue.push(7);
	
	assert(queue.count == 6);
	assert(queue.top == 2);
	assert(queue.pop() == 2);
	assert(queue.count == 5);	
}
