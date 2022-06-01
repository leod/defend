module engine.scene.effect.Library;

import tango.core.Array : sort;

import engine.util.Singleton;
import engine.util.Log : MLogger;

import engine.scene.effect.Effect;

class EffectLibrary
{
	mixin MLogger;

private:
	struct EffectInfo
	{
		Effect[] impls;
		
		Effect best;
		Effect[] allSupported;
	}
	
	EffectInfo[char[]] effects;
	
public:
	mixin MSingleton;

	void addEffectType(char[] name)
	{
		effects[name] = EffectInfo.init;
	}

	void addEffect(Effect effect)
	{
		effects[effect.type].impls ~= effect;
	}

	Effect best(char[] name)
	{
		auto effect = effects[name].best;
		
		if(!effect)
			throw new Exception("no supported effect implements " ~ name);
		
		if(!effect.initialized)
		{
			effect.init();
			effect.initialized = true;
		}
		
		return effect;
	}
	
	Effect[] allSupported(char[] name)
	{
		auto effects = effects[name].allSupported;
		
		foreach(effect; effects)
		{
			if(!effect.initialized)
			{
				logger_.info("initializing {}", effect.name);
				effect.init();
				effect.initialized = true;
			}
		}
		
		return effects;
	}

	void init()
	{
		foreach(name, ref effect; effects)
		{
			if(!effect.impls.length)
				continue;
		
			foreach(impl; effect.impls)
				if(impl.supported)
					effect.allSupported ~= impl;
			
			if(!effect.allSupported.length)
			{
				logger_.info("no supported effect implements {}", name);
				continue;
			}
			
			effect.allSupported.sort((Effect a, Effect b)
			{
				return a.score > b.score;
			});
			
			effect.best = effect.allSupported[0];
			
			logger_.trace("best effect implementing {} is {}", name,
			             effect.best.name);
		}
	}
	
	void initEffects()
	{

	}
	
	void releaseEffects()
	{
		foreach(ref effect; effects)
			foreach(impl; effect.allSupported)
				if(impl.initialized)
					impl.release();
	}
}

alias SingletonGetter!(EffectLibrary) gEffectLibrary;
