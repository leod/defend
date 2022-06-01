module engine.list.TreeList;

template MTreeList()
{
	import tango.io.Stdout;

	alias typeof(this) T;

	protected T next = null;
	protected T previous = null;
	protected T child = null;
	protected T parent = null;
	
	~this()
	{
		if(parent)
			parent.detachChild(this);
	
		iterateChildren((T node)
		{
			//Stdout("removing a ")(node.classinfo.name).newline;
		
			node.parent = null; // so that the child node doesn't detach itself
			delete node;
			
			return true;
		});
	}
	
	final void addChild(T node)
	{
		//Stdout("|")(node.classinfo.name)("|")();
	
		if(child is null)
		{
			child = node;
			child.parent = this;
		}
		else
			child.addSibling(node);
	}
	
	final void addSibling(T node)
	in
	{
		assert(node !is null);
	}
	body
	{
		node.parent = parent;
		
		node.previous = null;
		node.next = null;
		
		if(next is null)
		{
			next = node;
			node.previous = this;
		}
		else
		{
			next.previous = node;
			node.previous = this;
			node.next = next;
			next = node;
		}
	}
	
	final void detachChild(T node)
	in
	{
		assert(node !is null);
	}
	body
	{
		if(child is node)
			child = node.next;
		
		if(node.next !is null)
			node.next.previous = node.previous;

		if(node.previous !is null)
			node.previous.next = node.next;	
	}
	
	final void detach()
	{
		assert(parent !is null);
		parent.detachChild(this);
		
		previous = null;
		next = null;
		parent = null;
	}
	
	void iterateChildren(U)(bool delegate(U) dg)
	{
		T node = child;
		
		while(node)
		{
			// Need to save where the next node is, because the callback could delete the current one
			auto next = node.next;

			if(!dg(cast(U)node))
				break;
			
			node = next;
		}
	}
	
	void recurseChildren(U)(bool delegate(U) dg, bool delegate(U) cond = null)
	{
		T node = child;
		
		while(node)
		{
			// See above
			auto next = node.next;
		
			if((!cond || cond(cast(U)node)) && dg(cast(U)node))
				node.recurseChildren(dg);
			
			node = next;
		}
	}
	
	void dump(uint depth = 0)
	{
		iterateChildren((T node)
		{
			synchronized(Stdout)
			{
				for(uint i = 0; i <= depth; i++)
					Stdout("-> ");
				
				Stdout(node.classinfo.name).newline;
			}
			
			node.dump(depth + 1);
			
			return true;
		});
	}
}
