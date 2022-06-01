module defend.effects.shader.FogOfWar;

import engine.math.Vector;
import engine.util.Debug;
import engine.util.Sprite;
import engine.rend.Renderer;
import engine.scene.effect.Library;

import defend.terrain.FogOfWarRend;

private class EffectImpl : FogOfWarEffect
{
	Shader copyShader;
	Shader combineShader;

	this()
	{
		super("shader", 80);
	}

	override void init()
	{
		copyShader = Shader("copyVisibleFog.cfg");
		combineShader = Shader("combineLightmaps.cfg");
	}
	
	override void release()
	{
		subRef(copyShader);
		subRef(combineShader);
	}
	
	override bool supported()
	{
		return renderer.caps.shaders;
	}

	override void updateVisitedTexture(Sprite sprite, Texture visible,
	                                   Texture visited, Framebuffer target)
	{
		with(renderer)
		{
			setFramebuffer(target);
		
			setShader(copyShader);
			
			with(copyShader)
			{
				setUniform("fogVisible", 0);
				setUniform("fogVisited", 1);
			}
			
			setTexture(1, visited);
			sprite.render(vec2.zero, visible);
			
			setShader(null);
			setTexture(1, null);
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
			setFramebuffer(target);
			clear();			
			
			setShader(combineShader);
				
			with(combineShader)
			{
				setUniform("lightmap", 0);
				setUniform("fogVisible", 1);
				setUniform("fogVisited", 2);
			}
			
			setTexture(1, visible);
			setTexture(2, visited);
			sprite.render(vec2.zero, lightmap);
			
			setShader(null);
			setTexture(1, null);
			setTexture(2, null);
			setTexture(0, null);
			
			unsetFramebuffer(target);
		}
	}

	static this()
	{
		gEffectLibrary.addEffect(new typeof(this));
	}
}
