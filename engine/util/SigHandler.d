module engine.util.SigHandler;

version(Posix)
{
	import tango.stdc.stdlib;
	import tango.stdc.signal;

	private extern(C) void handleSIGINT(int)
	{
		exit(0);
	}

	static this()
	{
		signal(SIGINT, &handleSIGINT);
	}
}
else version(Windows)
{
	import tango.stdc.stdlib;
	import tango.sys.win32.UserGdi;
	
	private extern(Windows) BOOL consoleHandler(DWORD event)
	{
		switch(event)
		{
		case CTRL_C_EVENT:
			exit(0);
			break;
			
		default:
			break;
		}
		
		return TRUE;
	}
	
	static this()
	{
		SetConsoleCtrlHandler(cast(PHANDLER_ROUTINE)&consoleHandler, TRUE);
	}
}