module engine.util.FPS;

import engine.util.Wrapper;

class FPSCounter
{
private static:
	int fps = 0;
	int lastFPS = 0;
	int lastFrame = 0;

public static:
	void update()
	{
		if(getTickCount() - lastFrame < 1000)
			++fps;
		else
		{
			lastFrame = getTickCount();
			lastFPS = fps;
			fps = 0;
		}
	}
	
	int get()
	{
		return lastFPS;
	}
}
