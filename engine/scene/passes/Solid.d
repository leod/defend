module engine.scene.passes.Solid;

import tango.core.Array : sort;

import engine.util.Log : MLogger;
import engine.util.Profiler;
import engine.scene.Camera;
import engine.scene.Node;
import engine.scene.RenderPass;

class RenderPassSolid : RenderPass
{
	mixin MLogger;

protected:
	RenderFunc[] funcs;

	override void add_(Camera c, RenderFunc func)
	{
		funcs ~= func;
	}
	
public:
	this(int priority = 20)
	{
		super(priority);
	}

	override void renderAll(void delegate(SceneNode) beforeRender)
	{
		profile!("render.solid")
		({
			funcs.sort((RenderFunc a, RenderFunc b)
			{
				return cast(size_t)cast(void*)a.node.texture > cast(size_t)cast(void*)b.node.texture;
			});
		
			foreach(func; funcs)
			{
				logger_.spam("render {}", func.node);
			
				if(beforeRender) beforeRender(func.node);
				func();
			}
		});
	}
	
	override void reset()
	{
		super.reset();
		funcs.length = 0;
	}
}
