module defend.effects.noshader.FogOfWar;

import engine.math.Vector;
import engine.util.Sprite;
import engine.rend.Renderer;
import engine.scene.effect.Library;

import defend.terrain.FogOfWarRend;

private class EffectImpl : FogOfWarEffect
{
	Framebuffer tempBuffer;

	this()
	{
		super("blend", 30);
	}

	override void release()
	{
		delete tempBuffer;
	}
	
	override bool supported()
	{
		return renderer.caps.blendEquation;
	}

	override void updateVisitedTexture(Sprite sprite, Texture visible,
	                                   Texture visited, Framebuffer target)
	{
		with(renderer)
		{
			setFramebuffer(target);
			
			sprite.render(vec2.zero, visited);
		
			setRenderState(RenderState.Blending, true);
			setBlendOp(BlendOp.Max);
		
			sprite.render(vec2.zero, visible);
			
			setBlendOp(BlendOp.Add);
			setRenderState(RenderState.Blending, false);
			
			setTexture(0, null);
			
			unsetFramebuffer(target);
		}
	}
	
	override void combineTextures(Sprite sprite, Texture visible,
	                              Texture visited, Texture lightmap,
	                              Framebuffer target)
	{
		with(renderer)
		{
			{			
				if(!tempBuffer)
					tempBuffer = renderer.createFramebuffer(lightmap.dimension);
			
				setFramebuffer(tempBuffer);
				clear();
				
				setRenderState(RenderState.Blending, true);
				setColor(vec4(1, 1, 1, 0.5));
				setBlendFunc(BlendFunc.SrcAlpha, BlendFunc.Zero);
				
				sprite.render(vec2.zero, visited);
				
				setBlendOp(BlendOp.Max);
				sprite.render(vec2.zero, visible);
				setBlendOp(BlendOp.Add);
				
				setRenderState(RenderState.Blending, false);
				
				unsetFramebuffer(tempBuffer);
			}
		
			{
				setFramebuffer(target);
				clear();
			
				sprite.render(vec2.zero, lightmap);
				
				setRenderState(RenderState.Blending, true);
				setColor(vec4(1, 1, 1, 0.1)); // lol
				setBlendFunc(BlendFunc.SrcAlpha, BlendFunc.SrcColor);
				
				sprite.render(vec2.zero, tempBuffer.texture);
				
				setRenderState(RenderState.Blending, false);
				
				unsetFramebuffer(target);
			}
		}
	}

	static this()
	{
		gEffectLibrary.addEffect(new typeof(this));
	}
}
