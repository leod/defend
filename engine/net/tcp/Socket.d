module engine.net.tcp.Socket;

import tango.core.Thread;
import tango.text.Util;
import tango.net.SocketConduit;

import engine.util.Log : Logger;
import engine.mem.Memory;
import engine.mem.MemoryPool;
import engine.util.Serialize;
import engine.list.SyncQueue;
import engine.net.tcp.Message;

enum MessageBehaviour
{
	Queue,
	Immediately
}

private class NetworkMessage
{
	mixin MMemoryPool!(NetworkMessage, PoolFlags.Nothing);
	mixin MSyncQueue!(NetworkMessage);
	
	ubyte[] dataBuffer;
	
	// slice to dataBuffer
	ubyte[] data;
	
	this() { dataBuffer.alloc(128); }
	~this() { dataBuffer.free(); }
}

class ThreadSocket(MessageBehaviour messageBehaviour)
{
private:
	// Logger
	Logger logger;
	
	// The socket
	SocketConduit socket;
	
	// Message callbacks
	void delegate(ubyte[])[] messageDispatchers;
	void delegate(void*)[] messageHandlers;
	
	// Disconnect callback
	void delegate() disconnectHandler;
	
	// Memory pool for messages
	NetworkMessage.MemoryPool messagePool;
	
	// Queue of received messages
	static if(messageBehaviour == MessageBehaviour.Queue)
		NetworkMessage.SyncQueue readQueue;
		
	// Queue of messages which are to be sent
	NetworkMessage.SyncQueue writeQueue;
	
	// Threads
	Thread readThread;
	Thread writeThread;
	
	// Unserialize a message and call the right callback
	void dispatcher(T)(ubyte[] data)
	{
		logger.spam("received message of type `{}'", T.stringof);
	
		static assert(is(T == struct));
	
		auto stream = ArrayReader(data);
		
		T message = unserialize!(T)(stream);
		
		//auto name = getMessageTypeName(T.type);

		//if(name == "MessagePing" && messageBehaviour == MessageBehaviour.Queue)
		//	Trace.formatln("client: PING received");
		//else if(name == "MessagePong" && messageBehaviour == MessageBehaviour.Immediately)
		//	Trace.formatln("server: PONG received");
		
		messageHandlers[T.type](&message);
	}
	
	// Read thread
	void read()
	{
		try
		{
			// Buffer for queueing up split messages
			ubyte[] stackBuffer = new ubyte[10000];
			ubyte[] buffer = stackBuffer;
			
			// Number of queued bytes in the buffer
			uint queueLength = 0;
			
			while(!stop)
			{
				auto read = socket.input.read(buffer[queueLength .. $]);

				if(read == SocketConduit.Eof)
					continue;
				else if(read <= 0)
				{
					synchronized(this)
					{
						if(stop)
							break;
					
						if(disconnectHandler)
							disconnectHandler();
						
						stop = true;
						logger.warn("got disconnected (read thread noticed)");
					}
					
					break;
				}

				auto recv = buffer[0 .. queueLength + read];
				
				// Wait until the messages are fully received
				if(recv.length <= messageSeparator.length ||
				   recv[$ - messageSeparator.length .. $] != messageSeparator)
				{
					logger.info("QUEUEING: {}", read);
				
					queueLength += read;
					continue;
				}
				
				queueLength = 0;
								
				//logger.info("queue length: {}", cast(int)recv.length);
				
				foreach(line; patterns(recv, messageSeparator))
				{
					if(!line.length) // yeah thanks tango
						continue;
				
					//Trace.formatln("message: {}", line.length);
				
					// debug
					//auto name = getMessageTypeName(*(cast(message_type_t*)line[0 .. message_type_t.sizeof]));
					
					//if(name == "MessagePing " || name == "MessagePong ")
					//	logger.trace("<= {}", name);
				
					handleMessage(line);
					
					if(stop)
						return;
				}
			}
		}
		catch(Exception exception)
		{
			logger.warn("exception in read thread: {} ({}:{})",
			            exception.toString(), exception.file, exception.line);
			version(none) if(exception.info)
			{
				foreach(l; exception.info)
					logger.fatal(l);
			}
		}
		
		logger.trace("read thread finished");
	}
	
	// Write thread
	void write()
	{
		try
		{
			while(!stop)
			{
				NetworkMessage message;

				if(!writeQueue.poll(0.5, message))
					continue;
				
				// debug
				//auto name = getMessageTypeName(*(cast(message_type_t*)message.data[0 ..
				//	message_type_t.sizeof]));
				//
				//if(name == "MessagePing" && messageBehaviour == MessageBehaviour.Immediately)
				//	Trace.formatln("server: PING sent");
				//else if(name == "MessagePong" && messageBehaviour == MessageBehaviour.Queue)
				//	Trace.formatln("client: PONG sent");
				
				//logger.trace("REMAIN: {}", writeQueue.length);
				
				assert(message !is null, "message is null");
				uint remain = message.data.length;
				
				while(remain)
				{
					auto sent = socket.output.write(message.data[$ - remain .. $]);
					
					if(sent == SocketConduit.Eof)
					{
						synchronized(this)
						{
							if(stop)
								break;

							if(disconnectHandler)
								disconnectHandler();
							
							stop = true;
							logger.warn("got disconnected (write thread noticed)");
						}
						
						break;
					}
					
					assert(sent <= remain, "wft");
					remain -= sent;
				}
				
				assert(remain == 0 || stop, "message not fully sent");

				messagePool.free(message);
			}
			
			while(!writeQueue.empty)
				messagePool.free(writeQueue.take());
		}
		catch(Exception exception)
		{
			logger.fatal("exception in write thread: {} ({}:{})",
			             exception.toString(), exception.file, exception.line);
			version(none) if(exception.info)
			{
				foreach(l; exception.info)
					logger.fatal(l);
			}
		}
		
		logger.trace("write thread finished");
	}
	
	// Handle messages, call the dispatcher
	final void handleMessage(ubyte[] data)
	in
	{
		assert(data.length >= message_type_t.sizeof);
	}
	body
	{
		// If requested, queue the message
		static if(messageBehaviour == MessageBehaviour.Queue)
		{
			auto message = messagePool.allocate();
			
			if(message.dataBuffer.length < data.length)
				message.dataBuffer.realloc(data.length);
			
			message.dataBuffer[0 .. data.length] = data[];
			message.data = message.dataBuffer[0 .. data.length];
			
			assert(message.data.length >= message_type_t.sizeof);
			
			readQueue.put(message);
		}
		
		// Otherwise, call the dispatcher directly
		else
		{
			callDispatcher(data);
		}
	}
	
	// Calls the dispatcher for a message
	void callDispatcher(ubyte[] data)
	in
	{
		assert(data.length >= message_type_t.sizeof);
	}
	body
	{
		// Extract the message type
		message_type_t type = *(cast(message_type_t*)data[0 .. message_type_t.sizeof]);

		// Call the dispatcher
		if(type < messageDispatchers.length && messageDispatchers[type])
			messageDispatchers[type](data[message_type_t.sizeof .. $]);
		else
			logger.warn("ignored message of type {}", cast(int)type);
	}
	
	// Send message types, should be used once on server side to synchronize the messages
	void sendMessageTypes()
	{
		
	}
	
public:
	// Stop threads?
	bool stop = false;
	
	// Register a message handler
	void setMessageHandler(T)(void delegate(T*) handler)
	{
		if(messageDispatchers.length <= T.type)
			messageDispatchers.length = T.type + 1;
		
		messageDispatchers[T.type] = &dispatcher!(T);
		
		if(messageHandlers.length <= T.type)
			messageHandlers.length = T.type + 1;
		
		messageHandlers[T.type] = cast(void delegate(void*))handler;
	}
	
	void setMessageHandlers(T...)(T handlers)
	{
		foreach(handler; handlers)
			setMessageHandler(handler);
	}
	
	// Set the disconnect handler
	void setDisconnectHandler(void delegate() handler)
	{
		disconnectHandler = handler;
	}

	// Connect the socket, start threads
	void start(Logger logger, SocketConduit socket)
	{
		this.logger = logger;
		this.socket = socket;
	
		logger.spam("socket starting");
	
		// Preallocate messages
		messagePool.create(10);
		
		// Create queues
		static if(messageBehaviour == MessageBehaviour.Queue)
			readQueue.create();
		
		writeQueue.create();

		// Create threads
		readThread = new Thread(&read);
		readThread.start();

		writeThread = new Thread(&write);
		writeThread.start();
		
		// Initialize the socket
		socket.socket.blocking = true;
		socket.setTimeout(0.05);
	}
	
	static if(messageBehaviour == MessageBehaviour.Queue)
	{
		// Dispatch queued messages. May only be called from one thread at the same time
		void dispatch()
		{
			while(!readQueue.empty)
			{
				auto message = readQueue.take();
				callDispatcher(message.data);
				messagePool.free(message);
			}
		}
	}
	
	// Send a message
	void send(T)(T m)
	{
		static assert(is(T == struct), "can't send " ~ T.stringof);
	
		logger.spam("adding message of type `{}' to send queue", T.stringof);
	
		if(stop)
		{
			logger.warn("trying to send a message after shutdown");
			return;
		}
		
		auto message = messagePool.allocate();
		
		// Write the message type
		message.dataBuffer[0 .. message_type_t.sizeof] =
			(cast(ubyte*)&T.type)[0 .. message_type_t.sizeof];
		
		auto stream = RawWriter((uint offset, ubyte[] data)
		{
			uint neededLength = message_type_t.sizeof +
			                    messageSeparator.length +
			                    offset + data.length;
			
			if(message.dataBuffer.length <= neededLength)
				message.dataBuffer.realloc(neededLength);
				
			message.dataBuffer[message_type_t.sizeof + offset .. 
			                   message_type_t.sizeof + offset + data.length] = data[];
		});
		
		serialize(stream, m);
		
		// Write the message seperator
		message.dataBuffer[message_type_t.sizeof + stream.written ..
		                   message_type_t.sizeof + stream.written + messageSeparator.length] =
							messageSeparator[];
		
		// Create a slice from data to dataBuffer
		message.data = message.dataBuffer[0 .. message_type_t.sizeof +
		                                       stream.written + messageSeparator.length];

		// Queue the message, the write thread will send it
		writeQueue.put(message);
	}
	
	// Release the socket
	void release(bool stopRead = false, bool stopWrite = false)
	{
		synchronized(this) if(stop)
		{
			logger.warn("trying to shut down more than once");
			return;
		}
	
		logger.info("shutting down");		
		
		logger.trace("stopping threads");
		stop = true;
		
		if(stopRead)
			readThread.join();
			
		if(stopWrite)
			writeThread.join();
		
		logger.trace("closing socket");
		
		socket.shutdown();
		socket.close();
		
		// Release memory
		while(!writeQueue.empty)
			messagePool.free(writeQueue.take());
			
		static if(messageBehaviour == MessageBehaviour.Queue)
			while(!readQueue.empty)
				messagePool.free(readQueue.take());
			
		messagePool.release();
	}
}

alias ThreadSocket!(MessageBehaviour.Queue) QueueThreadSocket;
alias ThreadSocket!(MessageBehaviour.Immediately) ImmediateThreadSocket;
