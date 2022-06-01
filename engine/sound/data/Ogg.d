module engine.sound.data.Ogg;

import tango.stdc.stdio;
import tango.stdc.stringz;

import derelict.ogg.ogg;
import derelict.ogg.vorbis;
import derelict.ogg.vorbisfile;

import engine.sound.Data;

class OGG : Data
{
private:
	FILE* file;
	OggVorbis_File oggFile;
	int currentSection;
	ubyte[] buffer;

	const int bits = 16;
	int _size;
	int _frequency;
	int _channels;

public:
	this(char[] name)
	{
		if(!DerelictOgg.loaded)
		{
			char[] path = null;
			version(Windows) path = "libogg.dll";
		
			DerelictOgg.load(path);
		}
		
		if(!DerelictVorbis.loaded)
		{
			char[] path = null;
			version(Windows) path = "libvorbis.dll";
		
			DerelictVorbis.load(path);
		}
		
		if(!DerelictVorbisFile.loaded)
		{
			char[] path = null;
			version(Windows) path = "libvorbisfile.dll";
		
			DerelictVorbisFile.load(path);
		}

		file = fopen(toStringz(name), "rb");
	
		if(!file)
			throw new Exception("file not found: " ~ name);

		if(ov_open(file, &oggFile, null, 0) < 0)
			throw new Exception("'" ~ name ~ "' is not an ogg file");

		{
			vorbis_info* info = ov_info(&oggFile, -1);
			
			_frequency = info.rate;
			_channels = info.channels;
			_size = ov_pcm_total(&oggFile, -1) * (bits / 8) * _channels;
		}
	}
	
	override ubyte[] data(uint offset, uint len)
	{
		assert(offset + len <= size);
		
		ov_pcm_seek(&oggFile, offset / (bits / 8) / _channels);
		
		if(buffer.length < len)
			buffer.length = len;
		
		uint progress;
		while(progress < len)
			progress += ov_read(&oggFile, cast(byte*)buffer[progress .. len], len - progress, 0, 2, 1, &currentSection);

		return buffer;
	}
	
	override uint size()
	{
		return _size;
	}
	
	override uint frequency()
	{
		return _frequency;
	}
}
