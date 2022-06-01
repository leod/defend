module engine.util.UnitTest;

public
{
	import tango.io.Stdout;
	import tango.core.Exception;
}

import engine.util.HardwareTimer;

void assertException(T)(lazy void expr, char[] msg = null)
{
	try
	{
		expr();
	}
	catch(T)
	{
		return;
	}
	
	assert(false, msg);
}

// Run unit tests.
// 'which' specifies which unit tests shall be invoked (e.g. "gen")
// 'not' specifies which unit tests shall not be invoked (e.g. "engine.util")
bool runTests(char[][] which, char[][] not)
{
	uint failed; // Number of failed tests
	uint passed; // Number of passed tests
	uint number; // Number of invoked tests
	ulong timemicro; // Time in microseconds needed to run the test
	
	// Run one unittest and print out its result
	void test(char[] name, void function() f)
	{
		Stdout(name)(" - ")();
		
		ulong micro;
		
		try
		{
			HardwareTimer timer;
			timer.start();
			f();
			timer.stop();
			
			micro = timer.microseconds();
			
			timemicro += micro;
		}
		catch(AssertException exception)
		{
			Stdout("failed (line ")(exception.line)(" in ")(exception.file)(")").newline;
			++failed;
		
			return;
		}
		
		Stdout("passed (")(micro)("us)").newline;
		++passed;
	}
	
	// Test if one string is included in the beginning of an array of strings
	static bool includes(char[] search, char[][] where)
	{
		foreach(what; where)
		{
			if(search.length < what.length)
				continue;

			if(search[0 .. what.length] == what)
				return true;
		}
		
		return false;
	}
	
	Stdout("RUNNING UNITTESTS").newline;
	
	foreach(m; ModuleInfo)
	{
		if(!includes(m.name, which) || includes(m.name, not))
			continue;
		
		if(m.unitTest !is null)
		{
			test(m.name, m.unitTest);
			++number;
		}
	}
	
	Stdout("\nSUMMARY\n")("Number of tests: ")(number)
						 ("\nPassed tests: ")(passed)
						 ("\nFailed tests: ")(failed)
						 ("\nTime needed: ")(timemicro)("us").newline;
	
	return false;
}

version(UnitTest)
{
	import tango.core.Runtime;
	
	static this()
	{
		static bool run()
		{
			return runTests(["defend", "engine"], []);
		}
		
		Runtime.moduleUnitTester = &run;
	}
}
