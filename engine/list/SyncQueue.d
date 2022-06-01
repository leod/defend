module engine.list.SyncQueue;

public
{
	import tango.core.Thread;
	import tango.core.sync.Mutex;
	import tango.core.sync.Condition;

	import engine.list.LinkedList;
}

template MSyncQueue(T)
{
	static assert(is(T == class));
	
	mixin MLinkedList!(T);
	
	struct SyncQueue
	{
	private:
		Mutex mutex;
		Condition condition;

		LinkedList queue;
		
	public:
		void create()
		{
			mutex = new Mutex;
			condition = new Condition(mutex);
		}
		
		bool empty()
		{
			bool result;
			
			synchronized(mutex)
				result = queue.empty;
			
			return result;
		}
		
		uint length()
		{
			uint result;
			
			synchronized(mutex)
				result = queue.length;
				
			return result;
		}
		
		void put(T t)
		{
			synchronized(mutex)
			{
				queue.attach(t);
				condition.notify();
			}
		}
		
		T take()
		{
			T t;
			
			synchronized(mutex)
			{
				while(queue.empty)
					condition.wait();
				
				t = queue.detach(queue.first);
			}

			return t;
		}
		
		bool poll(double secs, out T t)
		{
			synchronized(mutex)
			{
				if(queue.empty)
				{
					condition.wait(secs);
					
					if(queue.empty)
						return false;
				}
				
				t = queue.detach(queue.first);
			}

			return true;
		}
	}
}
