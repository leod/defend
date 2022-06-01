module engine.util.Debug;

import tango.io.Stdout;

debug
{
	void trace(T...)(T t)
	{
		synchronized(Stdout)
		{
			static if(!is(T[0] : char[]))
				Stdout(t);
			else
				Stdout.format(t);
		}
	}

	void traceln(T...)(T t)
	{
		synchronized(Stdout)
		{
			trace(t);
			Stdout.newline;
		}
	}
}
