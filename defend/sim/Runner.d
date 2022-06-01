module defend.sim.Runner;

import engine.core.TaskManager;
import engine.util.Profiler;
import engine.util.Signal;
import engine.util.HardwareTimer;
import engine.util.Log : MLogger;

import defend.sim.Round;
import defend.sim.Gateway;

class SimulationRunner
{
	mixin MLogger;

private:
	Gateway gateway;

	ushort oldSimulationSteps;
	ushort simulationSteps;
	
	uint doneSimulationSteps;
	bool runningRound;
	
	const interpolationFrequency = 100.0f;
	float frequency = 10.0f;
	float _interpolation = 0.0f;

	void update()
	{
		//logger.trace("up 1");
	
		profile!("simulation.update")
		({
			if(!runningRound)
			{
				assert(doneSimulationSteps == simulationSteps);
			
				if(!gateway.startRound())
					return;
			}

			logger_.spam("simulation step");

			assert(doneSimulationSteps < simulationSteps);
			
			onSimulationStep();
			doneSimulationSteps++;
			
			//logger.trace("interp {}", _interpolation);
			_interpolation = 0;
				
			if(doneSimulationSteps == simulationSteps)
			{
				runningRound = false;

				// Tell the gateway that we finished the round
				gateway.roundDone();
			}
		});
	}
	
	void updateInterpolation()
	{
		//logger.trace("up 2");
	
		if(!runningRound) // HACK: should the new round really be started in the interpolation func? (hint: no.)
		{
			assert(doneSimulationSteps == simulationSteps);
			
			gateway.startRound();
			return;
		}
	
		_interpolation += frequency / interpolationFrequency;
		
		if(_interpolation > 1.0f)
		{
			//if(_interpolation - 1.0f > 0.001f)
			//	logger.warn("interpolation higher than 1.0f: {}", _interpolation);
			
			_interpolation = 1.0f;
		}
	}
	
	// Slots
	void onStartRound(Round round)
	{
		assert(round !is null);

		assert(doneSimulationSteps == simulationSteps && !runningRound);
		
		simulationSteps = round.simulationSteps;
		
		doneSimulationSteps = 0;
		runningRound = true;

		//if(round.simulationSteps == 0)
		//	runningRound = false; // special case for editor
		
		// Only happens when the game speed changes
		if(oldSimulationSteps != simulationSteps)
		{
			logger_.info("number of simulation steps changed from {} to {}",
			            oldSimulationSteps, simulationSteps);
		
			frequency = (1000.0f / round.length) * simulationSteps;
			taskManager.setTaskFrequency(&update, frequency);
		}
		
		oldSimulationSteps = simulationSteps;
	}
	
public:
	Signal!() onSimulationStep; // Run one simulation step

	this(Gateway gateway)
	{
		this.gateway = gateway;
	
		gateway.onStartRound.connect(&onStartRound);
		
		taskManager.addRepeatedTask(&update, frequency);
		taskManager.addRepeatedTask(&updateInterpolation, interpolationFrequency);
	}
	
	float interpolation()
	{
		return _interpolation;
	}
}
