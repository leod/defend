module engine.mem.FreeList;

template MFreeList()
{
	private alias typeof(this) T;
	
	private static T freelist;
	private T nextObject;

	static T allocate()
	{
		synchronized(T.classinfo)
		{
			if(freelist !is null)
			{
				T instance = freelist;
				freelist = instance.nextObject;

				static if(is(typeof(onAllocate)))
					instance.onAllocate();

				return instance;
			}
			else
			{
				T instance = new T;
				
				static if(is(typeof(onAllocate)))
					instance.onAllocate();
				
				return instance;
			}
		}
	}
	
	static void freeAll()
	{
		synchronized(T.classinfo)
		{
			T current = freelist;
			
			while(current)
			{
				auto temp = current;
				current = current.nextObject;
				
				delete temp;
			}
			
			freelist = null;
		}
	}
	
	static void preAlloc(int num)
	{
		synchronized(T.classinfo)
		{
			T[] cleanUp;
			cleanUp.length = num;

			while(num--) cleanUp[num] = allocate();
			
			foreach(t; cleanUp)
				t.free();
		}
	}
	
	void free()
	{
		synchronized(T.classinfo)
		{
			static if(is(typeof(onFree)))
				onFree();
			
			nextObject = freelist;
			freelist = this;
		}
	}
}
