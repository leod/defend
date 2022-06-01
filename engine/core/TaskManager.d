module engine.core.TaskManager;

import engine.util.Log : MLogger;
import engine.util.Singleton;

struct Task
{
private:
	void delegate() dg = null;
	
	int next = -1;
	
	bool isNew;
	bool oneShot;

	float period = 0;
	float timeOffset = 0;
	
	void opCall()
	{
		dg();
	}
	
	int opCmp(Task* other)
	{
		if(timeOffset > other.timeOffset)
			return 1;
		
		if(timeOffset < other.timeOffset)
			return -1;
			
		return 0;
	}
}

// Stolen from Deadlock, slightly modified

final class TaskManager
{
	mixin MLogger;

private:
	void delegate()[] preFrameTasks;
	void delegate()[] postFrameTasks;

	bool scheduleModified = false;
	Task[] schedule;

public:
	mixin MSingleton;
	
	void reset()
	{
		preFrameTasks.length = 0;
		postFrameTasks.length = 0;
		
		for(int i = 0; i < schedule.length;)
		{
			if(!schedule[i].oneShot)
			{
				schedule[i] = schedule[$ - 1];
				schedule.length = schedule.length - 1;
			}
			else
				i++;
		}		
		
		scheduleModified = true;
	}
	
	void addPreFrameTask(void delegate() task)
	{
		preFrameTasks ~= task;
	}
	
	void addPostFrameTask(void delegate() task)
	{
		postFrameTasks ~= task;
	}
	
	void addTask(Task task)
	{
		schedule ~= task;
		
		scheduleModified = true;
	}
	
	void addOneShotTask(void delegate() dg, float timeOffset = 0)
	{
		Task task;
		task.dg = dg;
		task.oneShot = true;
		task.timeOffset = timeOffset;
		
		addTask(task);
	}
	
	void addRepeatedTask(void delegate() dg, float frequency)
	{
		Task task;
		task.dg = dg;
		task.period = 1f / frequency;
		
		addTask(task);
	}
	
	void setTaskFrequency(void delegate() dg, float frequency)
	{
		foreach(ref task; schedule)
		{
			if(task.dg == dg)
			{
				//Stdout("setting frequency to ")(frequency)(" (")(1000 / frequency)(")").newline;
				
				task.period = 1f / frequency;
			}
		}
		
		scheduleModified = true;
	}
	
	void update(float time)
	{
		foreach(task; preFrameTasks)
			task();
		
		// Make a queue of tasks which shall be ran, sorted by time
		void makeTaskQueue()
		{
			schedule.sort;
			
			foreach(i, ref task; schedule)
			{
				if(i + 1 >= schedule.length || schedule[i + 1].timeOffset > time)
					task.next = -1;
				else
					task.next = i + 1;
					
				//logger.spam("task queue: offset {:z5}, next {}  (period {:z5})", task.timeOffset, task.next, task.period);
			}
		}
		
		foreach(ref task; schedule)
			task.isNew = false;
		
		scheduleModified = false;
		
		makeTaskQueue();
		
		if(schedule.length)
		{
			// Iterate through the queue
			for(int cur = 0; cur != -1 && schedule[cur].timeOffset <= time;)
			{
				//logger.spam("running task: offset {:z5}, next {} (period {:z5})", schedule[cur].timeOffset,  schedule[cur].next, schedule[cur].period);
			
				// Run the task
				schedule[cur]();
				
				auto task = &schedule[cur];
				float lastTime = task.timeOffset;
				
				if(task.oneShot)
					task.timeOffset = float.max;
				else
					task.timeOffset += task.period;
					
				// The schedule has been modified
				if(scheduleModified)
				{
					// Calculate time offset for the new jobs
					foreach(ref t; schedule)
					{
						if(t.isNew)
						{
							t.timeOffset += lastTime;
							t.isNew = false;
						}
					}
					
					if(schedule.length)
					{
						makeTaskQueue();
						cur = 0;
					}
					else
						cur = -1;
						
					continue;
				}
				
				// Does the task need to be executed again in this update?
				if(task.timeOffset > time)
					cur = task.next;
				else
				{
					// Check if we can simply run the current task again
					if(task.next == -1 || schedule[task.next].timeOffset > task.timeOffset)
						continue;
						
					// Move the task
					int prev = cur;
					cur = task.next;
					
					int i = cur;
					while(schedule[i].next != -1 && schedule[schedule[i].next].timeOffset <=
					      task.timeOffset)
						i = schedule[i].next;
						
					task.next = schedule[i].next;
					schedule[i].next = prev;
				}
			}
		}
		
		foreach(ref task; schedule)
		{
			if(task.timeOffset != float.max)
				task.timeOffset -= time;
		}
		
		// Remove one shots which have been ran
		for(int i = 0; i < schedule.length;)
		{
			if(schedule[i].oneShot && schedule[i].timeOffset == float.max)
			{
				schedule[i] = schedule[$ - 1];
				schedule.length = schedule.length - 1;
			}
			else
				i++;
		}
		
		foreach(task; postFrameTasks)
			task();
	}
}

alias SingletonGetter!(TaskManager) taskManager;
