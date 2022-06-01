module engine.util.Singleton;

template MSingleton()
{
	private static typeof(this) _instance;
	
	public static typeof(this) instance()
	{
		static if(is(typeof(new typeof(this))))
		{
			if(!_instance)
				_instance = new typeof(this);
		}
		
		assert(_instance !is null);
		
		return _instance;
	}
}

T SingletonGetter(T)()
{	
	return T.instance;
}
