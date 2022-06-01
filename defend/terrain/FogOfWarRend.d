module defend.terrain.FogOfWarRend;

import engine.core.TaskManager;
import engine.util.Sprite;
import engine.util.Profiler;
import engine.util.Cast;
import engine.image.Image;
import engine.scene.effect.Effect;
import engine.scene.effect.Library;
import engine.scene.Graph;
import engine.scene.Node;
import engine.math.Misc : clamp, min, max;
import engine.rend.Renderer;

import defend.sim.Core;

// effect for generating the fog of war textures
abstract class FogOfWarEffect : Effect
{
	this(char[] name, int priority)
	{
		super("fog of war", name, priority);
	}

	abstract void updateVisitedTexture(Sprite sprite, Texture visible,
		Texture visited, Framebuffer target);
	abstract void combineTextures(Sprite sprite, Texture visible,
		Texture visited, Texture lightmap, Framebuffer target);

	static this()
	{
		gEffectLibrary.addEffectType("fog of war");
	}
}

class FogOfWarRend
{
private:
	GameObjectManager gameObjects;

	Texture lightmap; // terrain's lightmap
	vec2i dimension; // terrain's dimension

	Framebuffer framebuffer;
	Framebuffer visibleBuffer;
	Framebuffer visitedBuffer;
	
	bool firstVisited;
	
	Sprite sprite;
	Texture circleTexture;
	
	FogOfWarEffect effect;
	
	void updateVisibleTexture()
	{
		with(renderer)
		{
			setRenderState(RenderState.Blending, true);
		
			auto ratio = vec2.from(lightmap.dimension) / vec2.from(dimension);
			auto scaleToOne = vec2(1.0f / sprite.width, 1.0f / sprite.height);
			
			setFramebuffer(visibleBuffer);
			clear();
			
			setBlendFunc(BlendFunc.One, BlendFunc.One);
			
			foreach(o; gameObjects)
			{
				// TODO: fog of war needs to include any object of the own team
				if(o.mayBeOrdered)
				{				
					auto sight = cast(real)o.property(GameObject.Property.Sight);
					auto scaling = scaleToOne * sight;
					sprite.scaling = scaling * ratio;
				
					auto position = (vec2(o.center.x,
										  dimension.y + o.center.z) -
									 
									 scaling * sprite.width * 0.5f) * ratio;
					
					sprite.render(position, circleTexture);
				}
			}
			
			unsetFramebuffer(visibleBuffer);
			
			sprite.scaling = vec2.one;
			
			setRenderState(RenderState.Blending, false);
		}
	}
	
	void updateVisitedTexture()
	{
		with(renderer)
		{
			if(!firstVisited)
			{
				setFramebuffer(visitedBuffer);
				clear();
				unsetFramebuffer(visitedBuffer);

				firstVisited = true;
			}
	
			visitedBuffer.texture.setFilter(Texture.Filter.Nearest);
			visibleBuffer.texture.setFilter(Texture.Filter.Nearest);
	
			effect.updateVisitedTexture(sprite, visibleBuffer.texture,
				visitedBuffer.texture, visitedBuffer);
		}
	}
	
	void combineTextures()
	{
		with(renderer)
		{
			visitedBuffer.texture.setFilter(Texture.Filter.Linear);
			visibleBuffer.texture.setFilter(Texture.Filter.Linear);
		
			effect.combineTextures(sprite, visibleBuffer.texture,
				visitedBuffer.texture, lightmap, framebuffer);
		}
	}
	
	void update()
	{
		profile!("fog of war render")
		({
			with(renderer)
			{
				setRenderState(RenderState.ZWrite, false);
				setRenderState(RenderState.DepthTest, false);
				
				orthogonal(visibleBuffer.texture.dimension);
				identity();

				updateVisibleTexture();
				updateVisitedTexture();
				combineTextures();
				
				setRenderState(RenderState.ZWrite, true);
				setRenderState(RenderState.DepthTest, true);
			}
		});
	}
	
	// Generate a circle which can be rendered on the fog of war texture
	static Texture generateCircle(vec2i size = vec2i(64, 64), float intensity = 2.7)
	{
		scope image = new Image(size.tuple, ImageFormat.A);
		vec2 center = vec2.from(size) / 2.f;

		for(uint x = 0; x < size.x; x++) for(uint y = 0; y < size.y; y++)
			image.setAlpha(x, y, cast(ubyte)clamp((center.x - (center -
				vec2(x, y)).length()) / center.y * 255.0f * intensity, 0, 255));
		
		return renderer.createTexture(image);
	}
	
public:
	this(GameObjectManager gameObjects, Texture lightmap)
	{
		this.gameObjects = gameObjects;
		this.lightmap = lightmap;
		dimension = lightmap.dimension;
		
		framebuffer = renderer.createFramebuffer(dimension);
		visibleBuffer = renderer.createFramebuffer(dimension);
		visitedBuffer = renderer.createFramebuffer(dimension);
		
		circleTexture = generateCircle();
		sprite = new Sprite(dimension, true);
		effect = objCast!(FogOfWarEffect)(
			gEffectLibrary.best("fog of war"));

		taskManager.addRepeatedTask(&update, 30);
	}
	
	~this()
	{
		delete framebuffer;
		delete visibleBuffer;
		delete visitedBuffer;
		delete circleTexture;
		delete sprite;
	}
	
	Texture texture()
	{
		return framebuffer.texture;
	}
}
