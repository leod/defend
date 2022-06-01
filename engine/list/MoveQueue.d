module engine.list.MoveQueue;

import engine.util.Swap;
import engine.util.Array;
import engine.mem.Memory;

struct MoveQueue(T)
{
private:
	T[] entries;
	
public:
	void create(uint length)
	{
		entries.alloc(length);
	}
	
	void release()
	{
		entries.free();
	}

	uint length()
	{
		return entries.length;
	}
	
	T last()
	{
		return entries[$ - 1];
	}
	
	T first()
	{
		return entries[0];
	}
	
	T opIndex(uint index)
	{
		return entries[index];
	}
	
	T opIndexAssign(T data, uint index)
	{
		return entries[index] = data;
	}
	
	// Move each entry down by one index
	void pop()
	{
		for(uint i = 0; i < entries.length - 1; i++)
		{
		   swap(entries[i], entries[i + 1]);
		}
	}
	
	int opApply(int delegate(ref T) dg)
	{
		int result = 0;
		
		for(uint i = 0; i < entries.length; i++)
		{
			if(cast(bool)(result = dg(entries[i])))
				break;
		}
		
		return result;
	}
}

unittest
{
	MoveQueue!(uint) queue;
	queue.create(5);
	
	assert(queue.length == 5);
	
	queue[0] = 1;
	queue[1] = 2;
	queue[2] = 3;
	queue[3] = 4;
	queue[4] = 5;
	
	for(uint i = 0; i < 10000; i++)
	{
		assert(queue[0] == 1);
		assert(queue[1] == 2);
		assert(queue[2] == 3);
		assert(queue[3] == 4);
		assert(queue[4] == 5);
		
		assert(queue.first == 1);
		assert(queue.last == 5);
		
		queue.pop();
		
		assert(queue[0] == 2);
		assert(queue[1] == 3);
		assert(queue[2] == 4);
		assert(queue[3] == 5);
		assert(queue[4] == 1);
		
		assert(queue.first == 2);
		assert(queue.last == 1);
		
		queue.pop();
		
		assert(queue[0] == 3);
		assert(queue[1] == 4);
		assert(queue[2] == 5);
		assert(queue[3] == 1);
		assert(queue[4] == 2);
		
		assert(queue.first == 3);
		assert(queue.last == 2);
		
		queue.pop();
		
		assert(queue[0] == 4);
		assert(queue[1] == 5);
		assert(queue[2] == 1);
		assert(queue[3] == 2);
		assert(queue[4] == 3);
		
		assert(queue.first == 4);
		assert(queue.last == 3);
		
		queue.pop();
		
		assert(queue[0] == 5);
		assert(queue[1] == 1);
		assert(queue[2] == 2);
		assert(queue[3] == 3);
		assert(queue[4] == 4);
		
		assert(queue.first == 5);
		assert(queue.last == 4);
		
		queue.pop();
		
		assert(queue[0] == 1);
		assert(queue[1] == 2);
		assert(queue[2] == 3);
		assert(queue[3] == 4);
		assert(queue[4] == 5);
		
		assert(queue.first == 1);
		assert(queue.last == 5);
	}
}
