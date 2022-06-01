module engine.util.RefCount;

template MRefCount(alias onDestroy)
{
	alias typeof(this) T;
	
	uint refCount;
	
	static T acquire(T object)
	{
		++object.refCount;
		return object;
	}
	
	static void release(T object)
	{
		if(--object.refCount == 0)
			onDestroy(object);
	}
}

T addRef(T)(T object) { return T.acquire(object); }
void subRef(T)(T object) { T.release(object); }
