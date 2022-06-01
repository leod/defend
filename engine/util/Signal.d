module engine.util.Signal;

struct Signal(T...)
{
	private alias void delegate(T) SlotType;
	private SlotType[] slots;
	
	void opCall(T arguments)
	{
		foreach(slot; slots)
			slot(arguments);
	}
	
	void connect(SlotType slot)
	{
		slots ~= slot;
	}
	
	void disconnect(SlotType slot)
	{
		foreach(i, s; slots)
		{
			if(s is slot)
			{
				slots[i] = slots[$ - 1];
				slots.length = slots.length - 1;
			}
		}
	}
}

unittest
{
	static class Sender
	{
		Signal!(char[], uint) Test;
		
		void run()
		{
			Test("hello world!", 42);
		}
	}
	
	uint counter = 0;

	class Receiver
	{
		void onTest(char[] string, uint number)
		in
		{
			assert(string == "hello world!");
			assert(number == 42);
		}
		body
		{
			counter++;
		}
	}
	
	Sender sender = new Sender;
	Receiver receiver1 = new Receiver;
	Receiver receiver2 = new Receiver;
	Receiver receiver3 = new Receiver;
	
	sender.Test.connect(&receiver1.onTest);
	sender.Test.connect(&receiver2.onTest);
	sender.Test.connect(&receiver3.onTest);
	
	sender.run;
	assert(counter == 3);
	
	sender.Test.disconnect(&receiver1.onTest);
	
	counter = 0;
	sender.run;
	assert(counter == 2);
	
	sender.Test.disconnect(&receiver2.onTest);
	
	counter = 0;
	sender.run;
	assert(counter == 1);
	
	sender.Test.connect(&receiver1.onTest);
	
	counter = 0;
	sender.run;
	assert(counter == 2);
	
	void functionReceiver(char[] string, uint number)
	in
	{
		assert(string == "hello world!");
		assert(number == 42);
	}
	body
	{
		counter++;
	}
	
	sender.Test.connect(&functionReceiver);
	
	counter = 0;
	sender.run;
	assert(counter == 3);
	
	sender.Test.connect((char[] string, uint number)
	{
		assert(string == "hello world!");
		assert(number == 42);
		
		counter++;
	});
	
	counter = 0;
	sender.run;
	assert(counter == 4);
}
