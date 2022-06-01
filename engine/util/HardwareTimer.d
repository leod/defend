module engine.util.HardwareTimer;

import tango.time.StopWatch;

struct HardwareTimer
{
	StopWatch watch;

	void start()
	{
		watch.start();
	}
	
	void stop()
	{
		watch.stop();
	}
	
	ulong microseconds()
	{
		return watch.microsec;
	}
}

/+
version(Windows)
{
	extern(Windows) int QueryPerformanceCounter(ulong* count);
	extern(Windows) int QueryPerformanceFrequency(ulong* frequency);
	
	struct HardwareTimer
	{
	private:
		static ulong frequency;
		
		ulong begin = 0;
		ulong end = 0;
		
	public:
		static this()
		{
			QueryPerformanceFrequency(&frequency);
		}

		void start()
		{
			QueryPerformanceCounter(&begin);
		}

		void stop()
		{
			QueryPerformanceCounter(&end);
		}

		ulong period()
		{
			return end - begin;
		}
		
		ulong seconds()
		{
			return period / frequency;
		}

		ulong milliseconds()
		{
			if(period < 0x20C49BA5E353F7L)
				return (period * 1000) / frequency;
				
			return (period / frequency) * 1000;
		}
		
		ulong microseconds()
		{
			if(period < 0x8637BD05AF6L)
				return (period * 1000000) / frequency;
			else
				return (period / frequency) * 1000000;
		}
	}
}
else version(Posix)
{
	import tango.stdc.posix.sys.time;
	
	struct HardwareTimer
	{
	private:
		timeval begin;
		timeval end;

	public:
		void start()
		{
			ulong tz;
			gettimeofday(&begin, &tz);
		}
		
		void stop()
		{
			ulong tz;
			gettimeofday(&end, &tz);
		}
		
		long period()
		{
			return microseconds;
		}
		
		long seconds()
		{
			return (cast(long)end.tv_sec   + cast(long)end.tv_usec   / (1000 * 1000)) -
				   (cast(long)begin.tv_sec + cast(long)begin.tv_usec / (1000 * 1000));
		}
		
		long milliseconds()
		{
			return (cast(long)end.tv_sec   * 1000 + cast(long)end.tv_usec   / 1000) -
				   (cast(long)begin.tv_sec * 1000 + cast(long)begin.tv_usec / 1000);
		}
		
		long microseconds()
		{
			return (cast(long)end.tv_sec   * 1000 * 1000 + cast(long)end.tv_usec) -
				   (cast(long)begin.tv_sec * 1000 * 1000 + cast(long)begin.tv_usec);
		}
	}
}
+/
