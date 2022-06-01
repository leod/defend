module engine.util.Profiler;

import tango.core.Thread;

import engine.util.HardwareTimer;

// From deadlock

struct ProfilingData
{
	int parent = -1;
	int id;
	ulong calls = 0;
	ulong time = 0; // Time in microseconds
	char[] name;
	HardwareTimer timer;
}

ProfilingData*[] profilingData;

private
{
	uint nextID = 0;
	
	Object mutex;
	ThreadLocal!(int*) _currentBlock;
	int block = -1;
	
	int currentBlock()
	{
		// TODO: comment out when multi-threaded profiling is needed
		return block;
		
		if(_currentBlock.val is null)
		{
			_currentBlock.val = new int;
			*(_currentBlock.val) = -1;
		}
			
		return *(_currentBlock.val);
	}
	
	void currentBlock(int val)
	{
		block = val;
		return;
		
		if(_currentBlock.val is null)
		{
			_currentBlock.val = new int;
			*(_currentBlock.val) = -1;
		}
			
		*(_currentBlock.val) = val;
	}
	
	static this()
	{
		mutex = new Object;
		_currentBlock = new ThreadLocal!(int*);
	}
}

ProfilingData* currentProfilingBlock()
{
	foreach(data; profilingData)
	{
		if(data.id == currentBlock)
			return data; 
	}
	
	assert(false);
}

void resetProfilingData()
{
	foreach(data; profilingData)
	{
		with(*data)
		{
			parent = -1;
			calls = 0;
			time = 0;
		}
	}
}

template profile(char[] name)
{
	T profile(T)(T delegate() dg)
	{
		debug
		{
			static ProfilingData data;
			static int id;
			static bool initialized = false;
			
			if(!initialized) synchronized(mutex)
			{
				initialized = true;
				id = nextID++;
				data.name = name;
				data.id = id;
				profilingData ~= &data;
			}
			
			data.calls++;
			int parent = currentBlock;
			
			if(parent != id)
				data.parent = parent;
			
			currentBlock = id;
			
			data.timer.start;
			
			static if(is(T == void))
				dg();
			else
				T result = dg();
			
			data.timer.stop;
			data.time += data.timer.microseconds;
				
			currentBlock = parent;
			
			static if(!is(T == void))
				return result;
		}
		else
		{
			static if(is(T == void))
				dg();
			else
				return dg();		
		}
	}
}

version = Benchmarks;

// for quickly profiling blocks
version(Benchmarks)
{
	import engine.util.Log : MLogger;

	scope class Benchmark
	{
	private:
		// TODO: Benchmark does not support multi-threading (use TLS)
		HardwareTimer timer;
		char[] name;

	public:
		mixin MLogger;

		this(char[] name)
		{
			this.name = name;
			
			timer.start;
			logger_.indent();
		}
		
		~this()
		{
			timer.stop;
			logger_.outdent();
			
			logger_.trace("{}: {}s ({}ms)", name, timer.microseconds / (1000f*1000f), timer.microseconds / 1000f);
		}
	}
}
else
{
	scope class Benchmark
	{
		this(char[])
		{
			
		}
	}
}
