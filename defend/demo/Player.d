module defend.demo.Player;

import tango.io.device.File;
import tango.text.Util;

import engine.math.Vector;
import engine.util.Log : MLogger;
import engine.util.Wrapper;
import engine.util.Serialize;

import defend.Config;
import defend.demo.Chunks;
import defend.sim.Gateway;
import defend.sim.Core;
import defend.sim.obj.Unit;

class DemoPlayer : Gateway
{
	mixin MLogger;
private:
	File file;
	float _speed = 1f;

	ubyte[] dataBuffer;
	Round round;
	
	bool finished = false;

	ChunkHeader readChunkHeader()
	{
		ChunkHeader result;
		file.input.read((cast(void*)&result)[0 .. result.sizeof]);

		return result;
	}
	
	uint readChunkData(ubyte[] buffer, uint amount)
	{
		return file.input.read(cast(void[])buffer[0 .. amount]);
	}

	T chunky(T)(ubyte[] data)
	{
		return unserialize!(T)(ArrayReader(data));
	}

	void interpretChunk(ChunkHeader header, ubyte[] data)
	{
		switch(header.type)
		{
		case ChunkType.GameInfo:
			final chunk = chunky!(ChunkGameInfo)(data);

			// disable fog of war, we want to see everything while playing a demo
			chunk.info.withFogOfWar = false;
			
			onGameInfo(chunk.info);
			break;

		case ChunkType.Order:
			final chunk = chunky!(ChunkOrder)(data);
			round.push(chunk.targets, chunk.order);
			
			break;

		case ChunkType.StartRound:
			final chunk = chunky!(ChunkStartRound)(data);

			round.mayBeStarted = true;
			round.length = cast(ushort)(chunk.length / speed);
			round.simulationSteps = chunk.simulationSteps;

			onStartRound(round);
			round.reset();

			break;

		default:
			assert(false);
		}
	}

public:
	this(char[] path)
	{
		file = new File(path, File.ReadExisting);
		dataBuffer.length = 1024;
		round = new Round;
		
		OrderData.memoryPool.create(100);
	}

	~this()
	{
		OrderData.memoryPool.release();
	}

	void speed(float f)
	{
		_speed = f;
	}

	float speed()
	{
		return _speed;
	}

	void init()
	{
		bool firstRound = false;

		loop: while(true)
		{
			if(file.position == file.length)
				assert(false);

			ChunkHeader header = readChunkHeader();
			uint size = readChunkData(dataBuffer,
			                          header.length);
			ubyte[] dataSlice = dataBuffer[0 .. size];

			switch(header.type)
			{
			case ChunkType.StartGame:
				break loop;

			case ChunkType.GameInfo:
				interpretChunk(header, dataSlice);

				break;

			case ChunkType.StartRound:
				interpretChunk(header, dataSlice);
				break loop;

			default:
				interpretChunk(header, dataSlice);

				break;
			}
		}
	}

	override void start()
	{
		assert(false);
	}

	override void sendOrder(object_id_t[] targets, ubyte[] data)
	{
		assert(false);
	}

	override void disconnect()
	{
		assert(false);
	}

	override player_id_t id()
	{
		return 0;
	}

	override void update()
	{
		assert(false);
	}

	override void ready()
	{
		assert(false);
	}

	override void roundDone()
	{
		
	}

	override bool startRound()
	{
		if(finished)
			return false;
	
		while(true)
		{
			if(file.position == file.length)
			{
				logger_.info("demo finished playing");
				finished = true;
			
				return false;
			}

			ChunkHeader header = readChunkHeader();

			uint size = readChunkData(dataBuffer,
			                          header.length);
			ubyte[] dataSlice = dataBuffer[0 .. size];
			assert(dataSlice.length == header.length);

			bool canBreak = false;

			switch(header.type)
			{
			case ChunkType.StartRound:
				canBreak = true;

			default:
				interpretChunk(header, dataSlice);
			}

			if(canBreak)
				break;
		}
		
		return true;
	}
	
	override void checkSync(SyncCheckInfo info)
	{
	
	}
}
