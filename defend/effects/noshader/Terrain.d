module defend.effects.noshader.Terrain;

import engine.rend.Renderer;
import engine.image.Image;
import engine.util.Config;
import engine.util.Profiler;
import engine.scene.Graph;
import engine.scene.Node;
import engine.scene.Camera;
import engine.scene.effect.Library;

import defend.Config;
import defend.terrain.Terrain;
import defend.sim.Heightmap;
import defend.terrain.Ranges;

private class EffectImpl : TerrainEffect
{
	Texture[3] alphaMaps;

	this()
	{
		super("multipass", 50);
	}

	void createAlphaMaps()
	{
		foreach(i, diffuseMap; diffuseMaps)
		{
			Image image = new Image(128, 128, ImageFormat.RA);
		
			for(uint x = 0; x < image.width; x++)
			{
				for(uint y = 0; y < image.height; y++)
				{
					auto height = getHeightForImage(heightmap, x, y, 128);
					auto value = ((height >= terrainMinRange[i] &&
					              height <= terrainMaxRange[i]) ? 255 : 0);
					
					image.setRed(x, y, 255);
					image.setAlpha(x, y, value);
				}
			}
					
			alphaMaps[i] = renderer.createTexture(image);
		}
	}

	override void registerForRendering(Camera camera, SceneNode node)
	{
		sceneGraph.passSolid.add(camera, node, &render);
	}
	
	override void onHeightmapChange(int x, int y)
	{
		assert(false);
	}

	override void initMaps()
	{
		createAlphaMaps();
	}
	
	override void releaseMaps()
	{
		foreach(texture; alphaMaps)
			delete texture;
	}
	
	override bool supported()
	{
		return renderer.caps.multiTexturing;	
	}
	
	void render(SceneNode node)
	{
		profile!("terrain render")
		({
			renderer.pushMatrix();
			renderer.mulMatrix(node.absoluteTransformation);

			renderer.setRenderState(RenderState.Blending, true);
			renderer.setRenderState(RenderState.BackfaceCulling, true);

			renderer.setTextureMode(1, TextureMode.Replace);
			renderer.setTexture(2, lightmap);

			for(uint i_ = 0; i_ < alphaMaps.length * 2; i_++)
			{
				int i = i_ / 2;
			
				if(i_ & 1)
					renderer.setBlendFunc(BlendFunc.SrcAlpha, BlendFunc.One);
				else
					renderer.setBlendFunc(BlendFunc.SrcAlpha, BlendFunc.OneMinusSrcAlpha);
				
				renderer.setTexture(0, alphaMaps[i]);
				renderer.setTexture(1, diffuseMaps[i]);
				
				foreach(patch; patches)
				{
					if(patch.visible &&
					   patch.maxHeight[i] != -10_000 &&
					   patch.minHeight[i] != 10_000 &&
					   patch.maxHeight[i] >= terrainMinRange[i] &&
					   patch.maxHeight[i] <= terrainMaxRange[i])
					{
						patch.render();
					}
				}
			}

			renderer.setTexture(2, null);
			renderer.setTexture(1, null);
			renderer.setTexture(0, null);

			renderer.popMatrix();
			
			renderer.setTextureMode(1, TextureMode.Modulate);
			
			renderer.setRenderState(RenderState.Blending, false);
			renderer.setRenderState(RenderState.BackfaceCulling, false);
		});
	}
	
	override void renderOrthogonal()
	{
		renderer.setRenderState(RenderState.Blending, true);

		renderer.setTextureMode(1, TextureMode.Replace);

		for(uint i = 0; i < alphaMaps.length; i++)
		{
			renderer.setTexture(0, alphaMaps[i]);
			renderer.setTexture(1, diffuseMaps[i]);
			
			foreach(patch; patches)
				patch.render();
		}

		renderer.setTexture(1, null);
		renderer.setTexture(0, null);

		renderer.setTextureMode(1, TextureMode.Modulate);
		
		renderer.setRenderState(RenderState.Blending, false);
	}

	static this()
	{
		gEffectLibrary.addEffect(new typeof(this));
	}
}
