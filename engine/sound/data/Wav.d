module engine.sound.data.Wav;

import tango.io.device.File;

import engine.mem.Memory;
import engine.sound.Data;

private extern(C)
{
	struct RIFFHeader
	{
		char[4] riff;
		uint size;
		char[4] format;
	}

	struct ChunkHeader
	{
		char[4] type;
		uint size;
	}

	struct WaveFormat
	{
		short format;
		short channels;
		uint samples;
		uint bytes;
		short blockalign;
		short bits;
		short size;
	}
}

class WAV : Data
{
private:
	ubyte[] _data = null;
	uint _size;
	
public:
	override ubyte[] data(uint offset, uint len) { return _data[offset .. len]; }
	override uint size() { return _data.length; }
	override uint frequency() { return 11024; }
	
	this(char[] name)
	{
		//assert(false, "gtfo");
	
		scope file = new File(name);
		scope(exit) file.close();
		
		{
			RIFFHeader header;
			file.input.read((cast(void*)&header)[0 .. header.sizeof]);
			
			if(header.riff != "RIFF" || header.format != "WAVE")
				throw new Exception("'" ~ name ~ "' is not a wav file");
			
			_size = header.size;
		}	
		
		WaveFormat format;
		bool hasFormat;

		while(true)
		{
			ChunkHeader header;
			if(file.input.read((cast(void*)&header)[0 .. header.sizeof]) == File.Eof)
				break;

			switch(header.type)
			{
			case "fmt ":
				assert(header.size <= format.sizeof);
				file.input.read((cast(void*)&format)[0 .. header.size]);
				hasFormat = true;
				
				break;
				
			case "data":
				assert(_data is null);
				assert(hasFormat);

				_data.alloc(header.size);
				file.input.read(_data);
				
				break;
				
			default:
				file.seek(header.size, File.Anchor.Current);
			}
		}
	}
	
	~this()
	{
		_data.free();
	}
}
