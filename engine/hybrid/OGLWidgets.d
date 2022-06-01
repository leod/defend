module engine.hybrid.OGLWidgets;

import xf.hybrid.Common;
import xf.hybrid.CustomWidget;
import xf.hybrid.widgets.Group;

import xf.hybrid.widgets.WindowFrame;

import engine.rend.Renderer;
import engine.hybrid.OGLRenderer : HybridRenderer = Renderer;

class TopLevelWindow : CustomWidget
{
	this()
	{
		overrideSizeForFrame(userSize);
		
		//layout = new BinLayout;
	}

	override vec2 userSize()
	{
		return vec2(renderer.width, renderer.height);
	}
	
	override vec2 minSize()
	{
		return vec2(renderer.width, renderer.height);
	}
	
	override vec2 desiredSize()
	{
		return vec2(renderer.width, renderer.height);
	}
	
	protected override EventHandling handleRender(RenderEvent e)
	{
		auto r = cast(HybridRenderer)e.renderer;
		
		if(e.sinking)
			r.viewportSize = vec2i(renderer.width, renderer.height);
		
		super.handleRender(e);

		if(e.bubbling)
			r.flush();

		if(e.sinking)
			return EventHandling.Continue;
		else
			return EventHandling.Stop;
	}
	
	mixin MWidget;
}
