module engine.mem.MemoryPool;

public
{
	import tango.core.sync.Mutex;
	
	import engine.mem.Memory;
}

debug = stats;

debug(stats) public import engine.math.Misc;

enum PoolFlags
{
	Nothing = 2,
	GlobalPool = 4, // Create a global pool called T.memoryPool
	Initialize = 8, // Call constructors/destructors of the pooled objects in allocate()/free()
	Synchronize = 16, // Synchronize in allocate()/free()
	CallReuseFunc = 32 // Call T.reuse() in allocate() (only when not using Initialize)
}

template MMemoryPool(T, PoolFlags flags =
	PoolFlags.GlobalPool | PoolFlags.Initialize)
{
	import engine.util.Log : MLogger;

	private struct PoolStats
	{
		uint allocs;
		uint peekUsage;

		uint nonPoolAllocs;
		uint nonPoolPeekUsage;
	}

	static assert(is(T == class));
	
	// internal allocators and deallocators
	new(size_t size, void[] block)
	{
		assert(block.length == T.classinfo.init.length);
		assert(block.length == size);
		
		return block.ptr;
	}
	
	delete(void*)
	{
		
	}

	debug(stats)
		mixin MLogger;

	struct MemoryPool
	{
	private:
		size_t maxObjects;
		
		void[] memoryBlock;
		
		void[][] stack; // stack of free objects
		size_t stackIndex;
	
		void push(void[] p)
		{
			assert(p.length == T.classinfo.init.length);
			stack[stackIndex++] = p;
		}
		
		void[] pop()
		{
			return stack[--stackIndex];
		}
	
		Mutex mutex;
	
		debug
		{
			uint balance;
			uint nonPoolBalance;
		}
		
		debug(stats)
			PoolStats stats;
	
		bool isFromPool(void* block)
		{
			return block >= memoryBlock.ptr &&
			       block < memoryBlock.ptr + T.classinfo.init.length * maxObjects;
		}
	
	public:
		const globalPool = flags & PoolFlags.GlobalPool;
		const initialize = flags & PoolFlags.Initialize;
		const doSynch = flags & PoolFlags.Synchronize;
		const callReuseFunc = flags & PoolFlags.CallReuseFunc;
		
		static if(callReuseFunc)
		{
			static assert(!initialize);
			static assert(is(typeof(T.reuse)));
		}

		void create(size_t maxObjects)
		{
			assert(mutex is null);
		
			this.maxObjects = maxObjects;
			mutex = new Mutex;
		
			memoryBlock.alloc(T.classinfo.init.length * maxObjects);
			stack.alloc(maxObjects);
			
			for(auto i = 0, j = 0; i < maxObjects;
				++i, j += T.classinfo.init.length)
			{
				auto block = memoryBlock[j .. j + T.classinfo.init.length];
				
				static if(!initialize)
					new(block) T;
				
				push(block);
			}
		}

		void release()
		{
			assert(mutex !is null);
		
			debug
			{
				if(balance != 0)
					logger_.warn("not all objects have been freed ({} remaining)", balance);
			}
			
			static if(!initialize)
			{
				for(auto i = 0, j = 0; i < maxObjects;
					i++, j += T.classinfo.init.length)
				{
					auto object = cast(T)memoryBlock[j .. j +
						T.classinfo.init.length].ptr;
					
					delete object;
				}
			}
			
			.free(memoryBlock);
			.free(stack);
			
			debug(stats)
			{
				logger_.trace("allocs: {}; peek usage: {}; non pool allocs: {}; non pool peek usage: {}",
					stats.allocs, stats.peekUsage, stats.nonPoolAllocs, stats.nonPoolPeekUsage);
				
				stats = PoolStats.init;
			}
			
			delete mutex;
		}
		
		T allocate(U...)(U params)
		{
			static if(!initialize)
				static assert(!params.length);

			assert(mutex !is null);
			
			static if(doSynch)
			{
				mutex.lock();
				scope(exit) mutex.unlock();
			}
			
			debug
			{
				++balance;
				
				debug(stats)
				{
					++stats.allocs;
					stats.peekUsage = max(balance, stats.peekUsage);
				}
			}
			
			if(!stackIndex)
			{
				debug
				{
					++nonPoolBalance;
				
					debug(stats)
					{
						++stats.nonPoolAllocs;
						stats.nonPoolPeekUsage = max(nonPoolBalance,
							stats.nonPoolPeekUsage);
					}
				}
				
				void[] memory;
				memory.alloc(T.classinfo.init.length);
				
				return new(memory) T(params);
			}
			
			auto block = pop();
			
			assert(block !is null, "block is null");
			assert(isFromPool(block.ptr), "block is not from pool");
			
			static if(initialize)
			{
				auto object = new(block) T(params);
			}
			else
			{
				auto object = cast(T)block.ptr;
				
				static if(callReuseFunc)
					object.reuse(params);
			}
			
			return object;
		}
		
		void free(T object)
		in
		{
			assert(object !is null);
		}
		body
		{
			assert(mutex !is null);
		
			auto memory = (cast(void*)object)[0 ..
				T.classinfo.init.length];
		
			static if(doSynch)
			{
				mutex.lock();
				scope(exit) mutex.unlock();
			}
		
			debug
			{
				assert(balance > 0, T.stringof);
				--balance;
			}
			
			if(!isFromPool(cast(void*)object))
			{
				debug
				{
					assert(nonPoolBalance > 0);
					--nonPoolBalance;
				}
				
				delete object;
				.free(memory);
				
				return;
			}
			
			static if(initialize)
				delete object;
			
			push(memory);
		}
	}
	
	static if(MemoryPool.globalPool)
	{
		static
		{
			MemoryPool memoryPool;

			T allocate(U...)(U params)
			{
				return memoryPool.allocate(params);
			}

			void free(T object)
			{
				memoryPool.free(object);
			}
		}
	}
		
	// Initialize the global pool in a static constructor?
}
