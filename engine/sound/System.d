module engine.sound.System;

import engine.math.Vector : vec3;
import engine.sound.Buffer : Buffer;
import engine.sound.Data : Data;
import engine.sound.data.Ogg : OGG;
import engine.sound.data.Wav : WAV;
import engine.sound.Source : Source;
import engine.util.Resource : MResource;

// Global sound system instance
System gSoundSystem;

abstract class Sound
{
	mixin MResource;

	static Sound loadResource(ResourcePath path)
	{
		Data data;

		switch (Path.parse(path.fullPath).ext)
		{
			case "wav":
				data = new WAV(path.fullPath);
				break;
					
			case "ogg":
				data = new OGG(path.fullPath);
				break;
					
			default:
				assert(false);
		}

		return gSoundSystem.createSound(data);
	}

	/**
	 * Play a sound.
	 */
	void play()
	{
		gSoundSystem.play(source);
	}

	/**
	 * Get the sound buffer
	 */
	Buffer buffer();

	/**
	 * Get the sound source
	 */
	Source source();

	/**
	 * Get the sound data
	 */
	Data data();
}

/**
 * Interface for sound systems
 */
interface System
{
	/**
	 * Set the listener's position.
	 */
	void setListenerPosition(vec3 v);

	/**
	 * Set the listener's velocity.
	 */
	void setListenerVelocity(vec3 v);

	/**
	 * Set the listener's orientation.
	 */
	void setListenerOrientation(vec3 d, vec3 u);

	/**
	 * Update sources etc.
	 */
	void update();

	/**
	 * Play a sound source.
	 */
	void play(Source source);

	/**
	 * Create a sound from sound data.
	 */
	Sound createSound(Data data);
}
