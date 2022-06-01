module engine.util.MT;

import tango.core.Atomic;
import tango.stdc.stdlib : alloca;
import tango.core.Thread;

public
{
	import tango.core.ThreadPool;
}

import engine.util.Meta : ForeachTypeOf;

alias ThreadPool!(void*) ThreadPoolT;

struct Future(RetT, Args...)
{
private:
	alias RetT delegate(Args) dg_t;
	
	dg_t dg;
	Args args;
	
	Atomic!(bool) finished;
	RetT result_; // should be Atomic too, kinda, but Atomic requires T <= (void*).sizeof
	
	void run(void*)
	{
		result_ = dg(args);
		finished.store(true);
	}
	
public:
	static Future opCall(ThreadPoolT threadPool, dg_t dg, Args args)
	{
		Future future;
		future.dg = dg;
		future.args = args;
		
		threadPool.append(dg, null);
	}
	
	RetT result()
	{
		while(!finished.load())
			{} // sleep?
		
		return result_;
	}
}

Future!(RetT, Args) future(RetT, Args...)(ThreadPoolT threadPool,
                                          RetT delegate(Args) dg,
                                          Args args)
{
	return Future!(RetT, Args)(threadPool, dg, args);
}

struct MTApply(T)
{
	alias ForeachTypeOf!(T) ArgT;
	
	ThreadPoolT threadPool;
	T t;
	
	static MTApply opCall(ThreadPoolT threadPool, T t)
	{
		MTApply result;
		result.threadPool = threadPool;
		result.t = t;
		
		return result;
	}
	
	int opApply(int delegate(ref ArgT) dg)
	{
		ArgT[] values;
		int count;

		static if(is(typeof(t.length)))
		{
			count = t.length;
		}
		else
		{
			foreach(v; t) ++count;
		}
		
		values = (cast(ArgT*)alloca(ArgT.sizeof * count))[0 .. count];
		
		Atomic!(int) numLeft;
		numLeft.store(count);
			
		void run(void* idx)
		{
			dg(values[cast(int)idx]);
			numLeft.decrement();
		}
		
		int i = 0;
		
		foreach(v; t)
		{
			values[i] = v;
			threadPool.append(&run, cast(void*)i);
			
			++i;
		}
		
		while(numLeft.load() > 0)
			{}
			
		return 0;
	}
}

MTApply!(T) mtApply(T)(ThreadPoolT threadPool, T t)
{
	return MTApply!(T)(threadPool, t);
}

struct MTFor
{
	ThreadPoolT threadPool;
	int from, to;
	int numPerTask;
	
	static MTFor opCall(ThreadPoolT threadPool, int from, int to, int numPerTask = 0)
	{
		assert(to >= from);
	
		MTFor result;
		result.threadPool = threadPool;
		result.from = from;
		result.to = to;
		
		if(numPerTask == 0)
		{
			result.numPerTask = (to - from) / 4;
			
			if(result.numPerTask == 0) // (to - from) < 4
				result.numPerTask = 1;
		}
		else
			result.numPerTask = numPerTask;

		return result;
	}
	
	int opApply(int delegate(ref int) dg)
	{
		if(to == from)
			return 0;
	
		assert(numPerTask > 0);
	
		Atomic!(int) numLeft;
		int numTasks = (to - from) / numPerTask;
		
		assert(numTasks > 0);
		numLeft.store(numTasks - 1);
		
		void run(int idx)
		{
			int i, start;
			i = start = idx * numPerTask;
			
			while(i < to && i - start < numPerTask)
			{
				dg(i);
				++i;
			}
		}
		
		void task(void* arg)
		{
			run(cast(int)arg);
			numLeft.decrement();
		}
		
		for(int i = 0; i < numTasks - 1; ++i)
			threadPool.append(&task, cast(void*)i);
		
		run(numTasks - 1);
		
		while(numLeft.load() > 0)
			{}
			
		return 0;
	}
}

MTFor mtFor(ThreadPoolT threadPool, int from, int to, int numPerTask = 0)
{
	return MTFor(threadPool, from, to, numPerTask);
}

version(UnitTest)
	import engine.util.Debug;

unittest
{
	auto pool = new ThreadPoolT(4);
	scope(exit) pool.finish();
	
	int c;
	
	void foo(void*)
	{
		++c;
	}
	
	c = 0;
	
	for(int i = 0; i < 10; ++i)
		pool.append(&foo, null);
		
	while(pool.pendingJobs > 0) {}
		
	assert(c == 10);
	
	c = 0;
	
	foreach(i; mtApply(pool, [1, 2, 3, 4, 5][]))
		++c;
		
	assert(c == 5);
		
	struct WeirdIterable
	{
		int start, end;
		
		int opApply(int delegate(ref int) dg)
		{
			for(int i = start; i < end; ++i)
				dg(i);
				
			return 0;
		}
	}
	
	WeirdIterable it;
	it.start = 0;
	it.end = 100;
	
	c = 0;
	
	foreach(i; mtApply(pool, it))
		++c;
		
	assert(c == 100);
}
