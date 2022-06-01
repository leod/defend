module engine.sound.openal.Source;

import derelict.openal.al;

import engine.mem.Memory;
import engine.mem.MemoryPool;
import engine.sound.Source : Source;
import engine.sound.openal.Buffer : OALBuffer;

package class OALSource : Source
{
package:
	uint id;
	OALBuffer buffer;
	
	bool finished()
	{
		int state;
		alGetSourcei(id, AL_SOURCE_STATE, &state);
		
		return state != AL_PLAYING;
	}
	
public:
	mixin MMemoryPool!(OALSource, PoolFlags.Initialize);
	
	this(OALBuffer buffer)
	{
		this.buffer = buffer;
		
		alGenSources(1, &id);
		alSourcei(id, AL_BUFFER, buffer.id);
	}
	
	~this()
	{
		alDeleteSources(1, &id);
	}
	
	override void setPosition(float x, float y, float z)
	{
		alSource3f(id, AL_POSITION, x, y, z);
	}
	
	override void setVelocity(float x, float y, float z)
	{
		alSource3f(id, AL_VELOCITY, x, y, z);
	}
}
