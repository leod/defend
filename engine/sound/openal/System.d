module engine.sound.openal.System;

import derelict.openal.al;

import engine.list.BufferedArray;
import engine.math.Vector;
import engine.util.Array;
import engine.util.Log : MLogger;
import engine.sound.Buffer : Buffer;
import engine.sound.Data : Data;
import engine.sound.openal.Buffer : OALBuffer;
import engine.sound.openal.Source : OALSource;
import engine.sound.Sound : Sound;
import engine.sound.Source : Source;
import engine.sound.System : gSoundSystem, System;

class OALSound : Sound
{
	this(Data data)
	{
		data_ = data;
	}

	override
	{
		OALBuffer buffer()
		{
			return (cast(OALSystem)gSoundSystem).createBuffer(data_);
		}

		OALSource source()
		{
			return (cast(OALSystem)gSoundSystem).createSource(buffer);
		}

		Data data()
		{
			return data_;
		}
	}

private:
	const Data data_;
}

class OALSystem : System
{
	mixin MLogger;

private:
	bool initialized = true;

	ALCdevice* device;
	ALCcontext* context;

	void checkError()
	{
		auto error = alGetError();

		if(error)
			logger_.warn("error: {}", error);
	}

	OALSource.MemoryPool sourcePool;
	BufferedArray!(OALSource) sources;

public:
	this()
	{
		try
		{
			DerelictAL.load();
		}
		catch(Exception)
		{
			logger_.warn("failed to load openal");
		
			initialized = false;
			return;
		}

		device = alcOpenDevice(null);

		if(!device)
		{
			logger_.warn("couldn't open any device");
		
			initialized = false;
			return;
		}
		
		context = alcCreateContext(device, null);
		
		if(!context)
		{
			logger_.warn("failed to create context");
		
			initialized = false;
			return;
		}
		
		alcMakeContextCurrent(context);
		checkError();
		
		sourcePool.create(64);
		sources.create(64);

		//initialized = false;
		//logger.warn("disabled for debugging");
	}

	~this()
	{
		if(initialized)
		{
			foreach(source; sources)
				sourcePool.free(source);
		
			sourcePool.release();
			sources.release();

			if (!alcCloseDevice(device)) {
				logger_.warn("Unable to close OpenAL device");
			}
		}
	}

	override void setListenerPosition(vec3 v)
	{
		if(!initialized)
			return null;

		alListener3f(AL_POSITION, v.tuple);
	}

	override void setListenerVelocity(vec3 v)
	{
		if(!initialized)
			return null;

		alListener3f(AL_VELOCITY, v.tuple);
	}

	override void setListenerOrientation(vec3 d, vec3 u)
	{
		if(!initialized)
			return null;

		float[6] array = [ d.tuple, u.tuple ];

		alListenerfv(AL_ORIENTATION, array.ptr);
	}

	override void update()
	{
		loop: foreach(i, source; sources)
		{
			if(source.finished)
			{
				sources.remove(i);
				sourcePool.free(source);
				
				goto loop;
			}
		}
	}

	override void play(Source source_)
	{
		if(!initialized || source_ is null)
			return;
		
		auto source = cast(OALSource)source_;
		sources.append(source);
		
		alSourcePlay(source.id);
	}

	OALBuffer createBuffer(Data data)
	{
		if(!initialized)
			return null;

		debug
		{
			scope(exit)
				checkError();
		}

		return new OALBuffer(data);
	}

	OALSource createSource(OALBuffer buffer)
	{
		if(!initialized || buffer is null)
			return null;

		debug
		{
			scope(exit)
				checkError();
		}

		return sourcePool.allocate(cast(OALBuffer)buffer);
	}

	OALSound createSound(Data data)
	{
		return new OALSound(data);
	}
}
