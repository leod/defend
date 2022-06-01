module engine.scene.effect.Node;

// Effect support for scene nodes
template MEffectSupport(T, char[] name, bool array = false)
{
	import engine.util.Cast;
	import engine.scene.Camera;
	import engine.scene.effect.Library;

	static if(!array)
	{
		T best;
		
		void load()
		{
			best = objCast!(T)(gEffectLibrary.best(name));
		}
		
		void register(Camera camera)
		{
			best.registerForRendering(camera, this);
		}
	}
	else
	{
		T[] allSupported;
		
		void load()
		{
			allSupported = objCast!(T[])(gEffectLibrary.allSupported(name));
		}
		
		void register(Camera camera)
		{
			foreach(effect; allSupported)
				effect.registerForRendering(camera, this);
		}
	}
}
