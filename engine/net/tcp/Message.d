module engine.net.tcp.Message;

public
{
	import engine.util.Serialize;
}

typedef ushort message_type_t;

template MMessage(T)
{
	static message_type_t type;

	static this()
	{
		assert(lastType < message_type_t.max, "too many message types");
	
		type = lastType++;
		messageTypes[T.stringof] = &type;
	}
}

package
{
	// 0 is reserved for a special message type which synchronizes the other message types
	message_type_t lastType = 1;
	
	message_type_t*[char[]] messageTypes;
	
	char[] getMessageTypeName(message_type_t type)
	{
		foreach(key, val; messageTypes)
			if(*val == type)
				return key;
				
		assert(false);
	}
	
	// will remain until I write the message's length at the beginning of it
	ubyte[] messageSeparator = ['\r', '\n', 255, 254, 253];
}
