module engine.util.Cast;

template objCast(NewType)
{
	NewType objCast(OldType)(OldType object)
	{
		debug
		{
			assert(object !is null);
		
			auto result = cast(NewType)object;
			
			assert(result !is null, "object of type `" ~
				object.classinfo.name ~ 
				"' was expected to be of type `" ~
				NewType.classinfo.name ~ "'");
			
			return result;
		}
		else
		{
			return cast(NewType)cast(void*)object;
		}
	}
}

template objCast(NewType : NewType[])
{
	NewType[] objCast(OldType)(OldType[] objects)
	{
		debug
		{
			foreach(object; objects)
				assert(object !is null);
		
			auto result = cast(NewType[])objects;
			
			foreach(object; result)
			{
				assert(object !is null, "object of type `" ~
					object.classinfo.name ~
					"' was expected to be of type `" ~
					NewType.classinfo.name ~ "'");
			}
			
			return result;
		}
		else
		{
			return cast(NewType[])cast(void[])objects;
		}
	}
}

R delegate(T) fpToDg(R, T...)(R function(T) fp)
{
	assert(fp);

    struct Dg
    {
        R opCall(T t)
        {
            return (cast(R function(T))this)(t);
        }
    }
    
    R delegate(T) t;
    t.ptr = fp;
    t.funcptr = &Dg.opCall;
    
    return t;
}
