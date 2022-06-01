module engine.scene.passes.Blended;

import tango.core.Array : sort;

import engine.util.Log : MLogger;
import engine.util.Profiler;
import engine.rend.Renderer;
import engine.scene.Camera;
import engine.scene.Node;
import engine.scene.RenderPass;

class RenderPassBlended : RenderPass
{
	mixin MLogger;
	
protected:
	struct RenderInfo
	{
		RenderFunc func;
		float distance;
	}

	RenderInfo[] funcs;

	override void add_(Camera camera, RenderFunc func)
	{
		funcs ~= RenderInfo(func,
			camera.position.distance(func.node.absolutePosition));
	}
	
public:
	this(int priority = 80)
	{
		super(priority);
	}

	override void renderAll(void delegate(SceneNode) beforeRender)
	{
		profile!("render.blended")
		({
			funcs.sort((RenderInfo a, RenderInfo b)
			{
				return a.distance > b.distance;
			});
			
			renderer.setRenderState(RenderState.Blending, true);
			renderer.setRenderState(RenderState.ZWrite, false);
			
			scope(exit)
			{
				renderer.setRenderState(RenderState.Blending, false);
				renderer.setRenderState(RenderState.ZWrite, true);
			}
			
			foreach(func; funcs)
			{
				logger_.spam("render {}", func.func.node);
			
				if(beforeRender) beforeRender(func.func.node);
				func.func();
			}
		});
	}
	
	override void reset()
	{
		super.reset();
		funcs.length = 0;
	}
}

