module engine.mem.Memory;

import engine.util.Log : Log, Logger;

import tango.core.Runtime;
import tango.core.sync.Mutex : Mutex;
import stdlib = tango.stdc.stdlib;
import Integer = tango.text.convert.Integer;

//debug = collect;
debug = usage;
debug = objectUsage;
//debug = verboseUsage;

debug(usage)
{
	import engine.util.Array;

	// leak detection
	int memoryUsage;
	int[char[]] objectUsage;
	
	Mutex usageMutex;
	
	static this() 
	{
		usageMutex = new Mutex;
	}
	
	int getMemoryUsage()
	{
		return memoryUsage;
	}
	
	char[] objectUsageToString()
	{
		usageMutex.lock();
		scope(exit) usageMutex.unlock();
	
		char[] result;
		
		foreach(key, val; objectUsage)
		{
			if(val == 0)
				continue;
			
			result ~= key ~ ": " ~ Integer.toString(val) ~ "; ";
		}
			
		return result;
	}
	
	int[char[]] objectUsageSave;
	
	void saveObjectUsage()
	{
		objectUsageSave = objectUsage.dupAA();
	}
	
	void dumpObjectUsageDiff()
	{
		int[char[]] diff;
	
		foreach(k, v; objectUsage)
			diff[k] += v;
			
		foreach(k, v; objectUsageSave)
			diff[k] -= v;
			
		char[] str;
		
		foreach(k, v; diff)
		{
			if(v != 0)
				str ~= k ~ ": " ~ Integer.toString(v) ~ "; ";
		}
			
		gMemoryLogger.trace("object usage diff: {}", str.length ? str : "none");
	}
}
else
{
	int getMemoryUsage() { return -1; }
	char[] objectUsageToString() { return "unknown"; }
	void saveObjectUsage() {}
	void dumpObjectUsageDiff() {}
}

private Logger gMemoryLogger;

static this()
{
	gMemoryLogger = Log["memory"];
}

// use this for objects which you explicitly delete
template MAllocator(bool verbose = false)
{
	import engine.util.Log : LogLevel;
	import engine.mem.Memory : gMemoryLogger, memoryUsage, objectUsage, usageMutex;

	import tango.core.Exception : OutOfMemoryException;
	import tango.core.Memory : GC;
	import stdlib = tango.stdc.stdlib;

	static if(verbose)
		const _allocator_verbose = true;
	else
	{
		debug(verboseUsage)
			const _allocator_verbose = true;
		else
			const _allocator_verbose = false;
	}

	static size_t _allocator_count = 0;

	new(size_t size)
	{
		debug(usage)
		{
			usageMutex.lock();
			scope(exit) usageMutex.unlock();
		
			memoryUsage += this.classinfo.init.length;
			
			debug(objectUsage)
			{
				objectUsage[typeof(this).stringof]++;
			}

			gMemoryLogger.level = LogLevel.Trace;

			static if(_allocator_verbose)
			{
				memoryLogger.trace("allocating {} bytes for an instance of {}", size, this.classinfo.name);
				
				++_allocator_count;

				assert(objectUsage[typeof(this).stringof] == _allocator_count);
			}
		}
		
		void* block = stdlib.malloc(size);
		
		if(!block)
			throw new OutOfMemoryException(__FILE__, __LINE__);
		
		GC.addRange(block, size);
		
		return block;
	}
	
	delete(void* block)
	{
		debug(usage)
		{
			usageMutex.lock();
			scope(exit) usageMutex.unlock();
		
			memoryUsage -= this.classinfo.init.length;
		
			debug(objectUsage)
				objectUsage[typeof(this).stringof]--;
			
			static if(_allocator_verbose)
			{
				memoryLogger.trace("freeing {} bytes for an instance of {}",
					this.classinfo.init.length, this.classinfo.name);
		
				--_allocator_count;

				assert(objectUsage[typeof(this).stringof] == _allocator_count);
			}
		}
		
		stdlib.free(block);
		
		GC.removeRange(block);
	}
}

struct GCStats
{
	size_t poolsize;     // total size of pool
	size_t usedsize;     // bytes allocated
	size_t freeblocks;   // number of blocks marked FREE
	size_t freelistsize; // total of memory on free lists
	size_t pageblocks;   // number of blocks marked PAGE
}

extern(C) GCStats gc_stats();

void dumpGCStats()
{
	auto stats = gc_stats();
	
	gMemoryLogger.trace("GC stats:\nPool size: {} ({}kb)\nUsed size: {} ({}kb)\n"
	                    "Free blocks: {}\nFreelist size: {}\nPage blocks: {}",
	                    stats.poolsize, stats.poolsize / 1024, stats.usedsize,
	                    stats.usedsize / 1024, stats.usedsize, stats.freeblocks,
	                    stats.freelistsize, stats.pageblocks);
}

debug(collect) bool collectHandler(Object object)
{
	if(!Runtime.isHalting())
		gMemoryLogger.trace("collecting {}", object.classinfo.name);
	
	return true;
}

static this()
{
	debug(collect)
		Runtime.collectHandler = &collectHandler;
}

// Functions for allocating arrays
void alloc(T, U = int)(ref T[] array, U numItems, bool init = true) 
in
{
	assert(array is null);
	assert(numItems >= 0);
}
out
{
	assert(array.length == numItems);
}
body
{
	debug(usage)
	{
		usageMutex.lock();
		scope(exit) usageMutex.unlock();
	
		memoryUsage += T.sizeof * numItems;
		
		debug(objectUsage)
			objectUsage[(T[]).stringof] += numItems;

		debug(verboseUsage)
			gMemoryLogger.trace("allocating {} bytes (T: {}[])", T.sizeof * numItems, T.stringof);
	}

	array = (cast(T*)stdlib.malloc(T.sizeof * numItems))[0 .. numItems];
	
	static if(is(typeof(T.init)))
	{
		if(init)
			array[] = T.init;
	}
}

T clone(T)(T array)
{
	T res;
	res.alloc(array.length, false);
	res[] = array[];
	
	return res;
}

void realloc(T, U = int)(ref T[] array, U numItems, bool init = true)
in
{
	assert(numItems >= 0);
}
out
{
	assert(array.length == numItems);
}
body
{
	debug(usage)
	{
		usageMutex.lock();
		scope(exit) usageMutex.unlock();
	
		memoryUsage += T.sizeof * (cast(int)numItems - cast(int)array.length);
		
		debug(objectUsage)
			objectUsage[(T[]).stringof] += (cast(int)numItems - cast(int)array.length);
		
		debug(verboseUsage)
			gMemoryLogger.trace("reallocating {} bytes (T: {}[])", T.sizeof * numItems, T.stringof);
	}
	
	size_t oldLen = array.length;
	array = (cast(T*)stdlib.realloc(array.ptr, T.sizeof * numItems))[0 .. numItems];

	static if(is(typeof(T.init)))
	{
		if(init && numItems > oldLen)
			array[oldLen .. numItems] = T.init;
	}
}

void free(T)(ref T[] array)
out
{
	assert(array.length == 0);
}
body
{
	if(array is null)
		return;
	
	debug(usage)
	{
		usageMutex.lock();
		scope(exit) usageMutex.unlock();
	
		memoryUsage -= T.sizeof * array.length;
		
		debug(objectUsage)
			objectUsage[(T[]).stringof] -= array.length;
	
		debug(verboseUsage)
			gMemoryLogger.trace("freeing {} bytes (T: {}[])", T.sizeof * array.length, T.stringof);
	}
	
	stdlib.free(array.ptr);
	array = null;
}

void append(T)(ref T[] array, T value)
{
	array.realloc(array.length + 1);
	array[$ - 1] = value;
}
