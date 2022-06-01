module engine.util.ThreadPool;

import tango.core.Traits;
import tango.core.Thread;
import tango.core.sync.Mutex;
import tango.core.sync.Condition;
import tango.util.log.Trace;

import engine.util.FreeList;
import engine.list.LinkedList;

deprecated class ThreadPool
{
private:
	static class Runnable
	{
		mixin MFreeList;
		mixin MLinkedList!(Runnable);
		
		void delegate() dg;
	}

	bool stop = false;

	Runnable.LinkedList queue;
	Mutex mutex;
	Condition condition;
	Worker[] threads;

	final class Worker : Thread
	{
		bool finished = false;
		
		this()
		{
			super(&run);
		}
		
		void run()
		{
			try
			{
				while(!stop)
				{
					Runnable task;
					
					synchronized(mutex)
					{
						while(!stop && queue.empty)
							condition.wait();
						
						if(!stop)
						{
							assert(queue.first !is null);
							task = queue.detach(queue.first);
						}
					}
					
					if(stop)
						break;

					task.dg();

					synchronized(Runnable.classinfo)
						task.free();
				}

				finished = true;
			}
			catch(Exception exception)
			{
				Trace.formatln("thread pool worker, exception: {}", exception);
			}
		}
	}
	
public:
	this(uint numThreads)
	{
		mutex = new Mutex;
		condition = new Condition(mutex);
		
		for(uint i = 0; i < numThreads; i++)
			threads ~= new Worker;
		
		foreach(thread; threads)
		{
			thread.start();
			assert(!thread.finished);
		}
	}
	
	void dispose()
	{
		while(!queue.empty)
			Thread.yield();
		
		stop = true;

		outer: while(true)
		{
			synchronized(mutex)
				condition.notifyAll();
			
			foreach(thread; threads)
				if(!thread.finished)
				{
					Thread.yield();
					continue outer;
				}
			
			break;
		}
		
		debug foreach(thread; threads)
			assert(thread.finished);
		
		Runnable.freeAll();
	}
	
	void exec(void delegate() dg)
	{
		Runnable task;
		
		synchronized(Runnable.classinfo)
			task = Runnable.allocate();
		
		synchronized(mutex)
		{
			task.dg = dg;
			
			queue.attach(task);
			condition.notify();
		}
	}
}

struct Future(T, P...)
{
private:
	alias T delegate(P) dg_t;
	dg_t dg;

	T _result;
	P params;
	
	bool finished = false;
	
	void run()
	{
		_result = dg(params);
		finished = true;
	}
	
public:
	static void opCall(ThreadPool threadPool, dg_t dg, P params)
	{
		Future result;
		result.dg = dg;
		result.params = params;
		
		threadPool.exec(&result.run);
		
		return result;
	}
	
	T result()
	{
		while(!finished)
			Thread.yield();
			
		return _result;
	}
}

/*struct PoolApply(T)
{
	alias ParameterTupleOf!(ParameterTupleOf!(typeof(T.opApply))[0]) ParamTuple;

	
	T data;
	
	Future!(int, T)[] workers;
	uint workersUsed = 0;

	int opApply(int delegate(T) dg)
	{
		workersUsed = 0;
		
		foreach(element; data)
		{
			workersUsed++;
			
			if(workersUsed < workers.length)
				workers.length = workersUsed;
			
			workers[$ - 1](dg, element);
		}
		
		foreach(worker; workers)
			worker.result();
		
		return 0;
	}
}

PoolApply!(T) poolApply(T)(T data)
{
	PoolApply!(T) result;
	result.data = data;
	
	return result;
}*/

version(UnitTest)
	import tango.util.log.Trace;

unittest
{
	/*auto threadPool = new ThreadPool(4);
	scope(exit) threadPool.dispose();
	
	int k;
	const num = 100;
	
	for(int i = 0; i < num; i++)
		threadPool.exec({ ++k; });
	
	int func(int x)
	{
		return 3 * x;
	}
	
	auto future1 = Future!(int, int)(threadPool, &func, 2);
	auto future2 = Future!(int, int)(threadPool, &func, 3);
	auto future2 = Future!(int, int)(threadPool, &func, 4);
	
	assert(future1.result == 6);
	assert(future2.result == 9);
	assert(future3.result == 12);

	assert(k == num);*/
}
