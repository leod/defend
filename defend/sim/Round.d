module defend.sim.Round;

import engine.list.Queue;
import engine.mem.MemoryPool;
import engine.mem.Memory;

import defend.sim.Types;

class OrderData
{
	mixin MMemoryPool!(OrderData, PoolFlags.GlobalPool);

	object_id_t[] targetBuffer;
	
	// slice
	object_id_t[] targets;

	ubyte[] dataBuffer;
	
	// slice
	ubyte[] data;

	~this()
	{
		.free(targetBuffer);
		.free(dataBuffer);
	}
	
	void set(object_id_t[] t, ubyte[] d)
	{
		if(targetBuffer.length < t.length)
			targetBuffer.realloc(t.length, false);
 
		targetBuffer[0 .. t.length] = t[];
		targets = targetBuffer[0 .. t.length];

		if(dataBuffer.length < d.length)
			dataBuffer.realloc(d.length, false);

		dataBuffer[0 .. d.length] = d[];
		data = dataBuffer[0 .. d.length];		
	}
}

alias int round_counter_t;

class Round
{
private:
	Queue!(OrderData) list;
	
public:
	mixin MAllocator;

	bool mayBeStarted;
	round_counter_t whichRound;
	ushort length;
	ushort simulationSteps;

	this()
	{
		list.create(256);
	}

	~this()
	{
		while(!list.empty)
			OrderData.free(list.pop);

		list.release();
	}

	void push(object_id_t[] targets, ubyte[] data)
	{
		auto container = OrderData.allocate();
		container.set(targets, data);

		list.push(container);
	}

	void reset()
	{
		foreach(d; list)
			OrderData.free(d);

		list.reset();

		mayBeStarted = false;
	}

	uint count()
	{
		return list.count;
	}

	int opApply(int delegate(ref OrderData) dg)
	{
		return list.opApply(dg);
	}

	int opApplyReverse(int delegate(ref OrderData) dg)
	{
		return list.opApplyReverse(dg);
	}
}
