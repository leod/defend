module engine.scene.RenderPass;

import engine.scene.Node;
import engine.scene.Camera;

abstract class RenderPass
{
private:
	int _priority;
	int _count;
	
protected:
	struct RenderFunc
	{
		SceneNode node;
	
		enum Type
		{
			Delegate,
			FunctionWithNode,
			DelegateWithNode
		}
		
		Type type;
		
		union
		{
			void delegate() dg;
			void function(SceneNode) fnWithNode;
			void delegate(SceneNode) dgWithNode;
		}
		
		void opCall()
		{
			if(type == Type.Delegate) dg();
			else if(type == Type.FunctionWithNode) fnWithNode(node);
			else if(type == Type.DelegateWithNode) dgWithNode(node);
			else assert(false);
		}
	}

	abstract void add_(Camera, RenderFunc);
	
public:
	this(int priority)
	{
		_priority = priority;
	}
	
	final int priority() { return _priority; }
	final int count() { return _count; }
	
	final void add(A=void, B=void)(Camera camera,
		                           SceneNode node, void delegate() dg)
	{
		RenderFunc info;
		info.node = node;
		info.type = RenderFunc.Type.Delegate;
		info.dg = dg;
		
		++_count;
		
		add_(camera, info);
	}
	
	final void add(A=void, B=void)(Camera camera, RenderFunc func)
	{
		++_count;
	
		add_(camera, func);
	}

	final void add(T)(Camera camera,
					  SceneNode node, void delegate(T) dg)
	{
		RenderFunc info;
		info.node = node;
		info.type = RenderFunc.Type.DelegateWithNode;
		info.dgWithNode = cast(void delegate(SceneNode))dg;
		
		++_count;
		
		add_(camera, info);
	}
	
	abstract void renderAll(void delegate(SceneNode) beforeRender = null);
	abstract void reset() { _count = 0; }
}
