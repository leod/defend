module defend.demo.Recorder;

import tango.io.device.File;

import engine.mem.Memory;
import engine.util.Serialize;
import engine.util.Log : MLogger;

import defend.sim.Gateway;
import defend.sim.Round;
import defend.sim.GameInfo;
import defend.Config;
import defend.demo.Chunks;

class DemoRecorder
{
	mixin MLogger;
private:
	Gateway gateway;
	File file;

	void write(T)(ChunkType type, T chunk)
	{
		uint length;
	
		{
			// Calculate length of the chunk. Definitely needs to be changed.
			auto stream = RawWriter((uint, ubyte[] data) { length += data.length; });
			serialize(stream, chunk);
		}
	
		ChunkHeader header;
		header.type = type;
		header.length = length;

		file.output.write((cast(ubyte*)&header)[0 .. header.sizeof]);
		
		auto stream = RawWriter((uint, ubyte[] data) { file.output.write(data); });
		serialize(stream, chunk);
	}

	// Slots
	void onGameInfo(GameInfo info)
	{
		ChunkGameInfo chunk;
		chunk.info = info;

		write(ChunkType.GameInfo, chunk);
	}

	void onStartGame()
	{
		ChunkStartGame chunk;
		write(ChunkType.StartGame, chunk);
	}

	void onStartRound(Round round)
	{
		foreach(item; round)
		{
			ChunkOrder chunk;
			chunk.targets = item.targets;
			chunk.order = cast(ubyte[])item.data;

			write(ChunkType.Order, chunk);
		}

		ChunkStartRound chunk;
		chunk.length = round.length;
		chunk.simulationSteps = round.simulationSteps;

		write(ChunkType.StartRound, chunk);
	}

public:
	this(Gateway gateway, char[] path)
	{
		logger_.info("recording demo to {}", path);
	
		this.gateway = gateway;
		
		gateway.onGameInfo.connect(&onGameInfo);
		gateway.onStartGame.connect(&onStartGame);
		gateway.onStartRound.connect(&onStartRound);

		file = new File(path, File.WriteCreate);
	}

	~this()
	{
		file.close();
	}
}

