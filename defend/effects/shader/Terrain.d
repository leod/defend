module defend.effects.shader.Terrain;

import engine.rend.Renderer;
import engine.image.Image;
import engine.util.Config;
import engine.util.Profiler;
import engine.util.Debug;
import engine.util.Statistics;
import engine.math.Vector;
import engine.scene.Camera;
import engine.scene.Node;
import engine.scene.Graph;
import engine.scene.effect.Library;

import defend.Config : gDefendConfig;
import defend.terrain.Terrain;
import defend.sim.Heightmap;
import defend.terrain.Ranges;

private class EffectImpl : TerrainEffect
{
	Shader shader;
	Texture alphaMap;

	this()
	{
		super("shader", 80);
	}

	const alphaMapSize = 128;
	
	void createAlphaMaps()
	{
		Image image = new Image(alphaMapSize, alphaMapSize, ImageFormat.RGB);

		for(int i = 0; i < diffuseMaps.length; ++i)
		{
			for(uint x = 0; x < image.width; x++)
			{
				for(uint y = 0; y < image.height; y++)
				{
					auto height = getHeightForImage(heightmap, x, y, alphaMapSize);
					auto value = ((height >= terrainMinRange[i] &&
					              height <= terrainMaxRange[i]) ? 255 : 0);
					
					image.setByte(x, y, i, value);
				}
			}
		}
		
		alphaMap = renderer.createTexture(image);
	}

	override void registerForRendering(Camera camera, SceneNode node)
	{
		sceneGraph.passSolid.add(camera, node, &render);
	}
	
	override void onHeightmapChange(int x, int y)
	{
		vec3ub color;
		
		auto height = getHeightForImage(heightmap, x, y, alphaMapSize);
	
		for(int i = 0; i < diffuseMaps.length; ++i)
		{
			auto value = ((height >= terrainMinRange[i] &&
						  height <= terrainMaxRange[i]) ? 255 : 0);
			setVectorField(color, i, value);
		}
		
		uint x2 = cast(uint)(cast(float)alphaMapSize * (cast(float)x / cast(float)heightmap.size.x));
		uint y2 = cast(uint)(cast(float)alphaMapSize * (cast(float)y / cast(float)heightmap.size.y));
		
		//traceln("setting {}|{} to {}", x2, y2, color);
		
		alphaMap.update(x2, y2, color);
	}

	override void initMaps()
	{
		createAlphaMaps();
	}
	
	override void releaseMaps()
	{
		delete alphaMap;
	}
	
	override void init()
	{
		shader = Shader("terrain.cfg");
	}
	
	override void release()
	{
		subRef(shader);
	}
	
	override bool supported()
	{
		return renderer.caps.shaders &&
		       gDefendConfig.graphics.terrain_use_shaders;
	}
	
	void render(SceneNode node)
	{
		profile!("terrain render")
		({
			renderer.pushMatrix();
			renderer.mulMatrix(node.absoluteTransformation);

			renderer.setRenderState(RenderState.BackfaceCulling, true);

			renderer.setShader(shader);
			
			renderer.setTexture(0, alphaMap);
			renderer.setTexture(1, diffuseMaps[0]);
			renderer.setTexture(2, diffuseMaps[1]);
			renderer.setTexture(3, diffuseMaps[2]);
			renderer.setTexture(4, lightmap);
			
			shader.setUniform("alphaMap", 0);
			shader.setUniform("texture1", 1);
			shader.setUniform("texture2", 2);
			shader.setUniform("texture3", 3);
			shader.setUniform("lightMap", 4);
			
			if(gDefendConfig.graphics.shadowmapping.enable && sceneGraph.isCamera("shadow")) // shouldn't be in here
			{
				auto shadow = sceneGraph.getCamera("shadow");
				assert(shadow.core !is null);
				
				renderer.setTexture(5, shadow.framebuffer.texture);
				shader.setUniform("shadowTexture", 5);

				shader.setUniform("lightTransform", shadow.core.projection * shadow.core.modelview);
			}
			
			foreach(patch; patches)
				if(patch.visible)
				{
					++statistics.patches_rendered;
				
					patch.render();
				}
			
			renderer.setShader(null);
			
			renderer.setTexture(5, null);
			renderer.setTexture(4, null);
			renderer.setTexture(3, null);
			renderer.setTexture(2, null);
			renderer.setTexture(1, null);
			renderer.setTexture(0, null);
			
			renderer.popMatrix();

			renderer.setRenderState(RenderState.BackfaceCulling, false);
		});
	}
	
	override void renderOrthogonal()
	{
		// need to disable shadowmapping here.. this is kind of a hack :P
		auto define = cast(bool)("SHADOWMAPPING" in Shader.defines);
		if(define) Shader.defines.remove("SHADOWMAPPING");
		
		scope(exit)
			if(define) Shader.defines["SHADOWMAPPING"] = "1";
		
		auto localShader = Shader("terrain.cfg");
		scope(exit) delete localShader;
	
		scope lightmapImage = new Image(128, 128);
		for(uint x = 0; x < 128; x++)
			for(uint y = 0; y < 128; y++)
				lightmapImage.setRGB(x, y, 128, 128, 128);
	
		auto localLightmap = renderer.createTexture(lightmapImage);
		scope(exit) delete localLightmap;
	
		renderer.setShader(localShader);

		renderer.setTexture(0, alphaMap);
		renderer.setTexture(1, diffuseMaps[0]);
		renderer.setTexture(2, diffuseMaps[1]);
		renderer.setTexture(3, diffuseMaps[2]);
		renderer.setTexture(4, localLightmap);
		
		localShader.setUniform("alphaMap", 0);
		localShader.setUniform("texture1", 1);
		localShader.setUniform("texture2", 2);
		localShader.setUniform("texture3", 3);
		localShader.setUniform("lightMap", 4);

		foreach(patch; patches)
			patch.render();

		renderer.setShader(null);

		renderer.setTexture(3, null);
		renderer.setTexture(2, null);
		renderer.setTexture(1, null);
		renderer.setTexture(0, null);
	}

	static this()
	{
		gEffectLibrary.addEffect(new typeof(this));
	}
}
