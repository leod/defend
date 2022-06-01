module engine.util.GameState;

import tango.core.Memory;

import engine.core.TaskManager;
import engine.util.Log : MLogger;
import engine.mem.Memory;
import engine.util.Singleton;

// Base class for gamestate
abstract class GameState
{
	/* Initialize the gamestate. That means, load resources and create tasks.
	   There are no update or render functions, so the gamestate can only get updated
	   via tasks. */
	void init();
	
	// Free all resources which have been created in the init method.
	void done();
}

class GameStateManager
{
	mixin MLogger;

private:
	// Current gamestate
	GameState gameState = null;
	
	// Previous gamestate
	GameState oldGameState = null;
	
	/* Memory usage, before the gamestate has been started.
	   -1 means that there was no gamestate before */
	int memoryUsageBefore = -1;
	
	// Stores if the game shall be exited
	bool _exit = false;

	void doChange()
	{
		if(oldGameState !is gameState)
		{
			// First, clean up the old state
			if(oldGameState)
			{
				logger_.info("cleaning up old gamestate");

				// Remove all tasks from the task manager
				taskManager.reset();
				
				freeState(oldGameState);
				delete oldGameState;
				
				GC.collect();
			}
			
			// Save memory usage
			memoryUsageBefore = getMemoryUsage();
			oldGameState = gameState;
			
			saveObjectUsage();
			
			// Then start the new one
			logger_.info("starting new gamestate");
			
			gameState.init();
			
			logger_.info("gamestate initialized");
		}
		
		GC.collect();
	}

	void freeState(GameState state)
	{
		// Let the gamestate clean up
		state.done();
			
		// Check memory usage
		if(memoryUsageBefore != -1)
		{
			if(getMemoryUsage() != memoryUsageBefore)
			{
				logger_.warn("gamestate `{}' is not clean, {} bytes of memory are left",
							state.classinfo.name, getMemoryUsage() - memoryUsageBefore);
				dumpObjectUsageDiff();
			}
			else
			{
				logger_.info("gamestate `{}' is clean", state.classinfo.name);
			}
		}
	}

public:
	mixin MSingleton;
	
	this()
	{
		logger_.info("gamestate manager initialized");
	}
	
	// Clean up
	void shutdown()
	{
		if(gameState)
			freeState(gameState);
	}
	
	// Exit the game
	void exit(bool b)
	{		
		_exit = b;
	}
	
	bool exit()
	{
		return _exit;
	}

	// Change to another state
	void change(GameState state)
	in
	{
		assert(state !is null);
	}
	body
	{
		logger_.info("changing gamestate to `{}'", state.classinfo.name);
		gameState = state;
		
		taskManager.addOneShotTask(&doChange);
	}
	
	// Returns the current gamestate
	GameState current()
	{
		return gameState;
	}
}

alias SingletonGetter!(GameStateManager) gameState;
