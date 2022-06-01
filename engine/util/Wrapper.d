module engine.util.Wrapper;

import tango.core.Thread;

version(Windows)
{
	extern(Windows) uint timeGetTime();
}
else version(linux)
{
	import tango.stdc.posix.sys.time;
}

uint getTickCount()
{
	version(Windows)
	{
		return timeGetTime();
	}
	else version(linux)
	{
		ulong tz;
		timeval tv;
		gettimeofday(&tv, &tz);
		
		return tv.tv_sec * 1000 + tv.tv_usec / 1000;
	}
}
