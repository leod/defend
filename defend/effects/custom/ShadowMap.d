module defend.effects.custom.ShadowMap;

import engine.util.Profiler;
import engine.util.Cast;
import engine.util.Log : MLogger;
import engine.math.Vector;
import engine.rend.Renderer;
import engine.scene.Node;
import engine.scene.Graph;
import engine.scene.Camera;
import engine.scene.RenderPass;
import engine.scene.passes.Solid;
import engine.scene.effect.Library;
import engine.rend.opengl.Wrapper;
import engine.image.Image;
import engine.scene.cameras.StaticCamera;

import defend.Config : gDefendConfig;
import defend.terrain.Terrain;
import defend.sim.SceneNode;

import xf.omg.core.Misc : rad2deg;

private class EffectImpl : GameObjectCustomEffect
{
	this()
	{
		super("shadow", 100);
	}

	override void registerForRendering(Camera camera, GameObjectMesh node)
	{
		if(sceneGraph.cameraData.shadowMap)
			passRenderShadow.add(camera, node, &renderShadow);
	}
	
	void renderShadow(GameObjectMesh node)
	{
		renderer.pushMatrix();
		renderer.mulMatrix(node.absoluteTransformation);
		
		node.renderMesh();
		
		renderer.popMatrix();
	}
	
	void createShadowCamera()
	{
		auto size = gDefendConfig.graphics.shadowmapping.size;
		auto fb = renderer.createFramebuffer(vec2i(size, size), ImageFormat.A);

		auto camera = new StaticCamera(vec3(39.30, 109.20, -62.50),
			vec3(-1.38, -1.57, 0.00) * rad2deg, mat4.perspective(70, 1, 90, 200));

		sceneGraph.addCamera("shadow", camera, vec3(0, 0, 0), fb, true);
	}

	override bool supported()
	{
		return renderer.caps.shaders &&
			   gDefendConfig.graphics.shadowmapping.enable;
	}
	
	override void init()
	{
		auto effect = objCast!(GameObjectEffect)
			(gEffectLibrary.best("game object"));
		
		passRenderShadow = sceneGraph.addRenderPass(new PassRenderShadow);
		
		effect.inject(delegate RenderPass(RenderPass pass)
		{
			sceneGraph.removeRenderPass(pass);
			return sceneGraph.addRenderPass(new PassInjectShadow(pass));
		});
		
		createShadowCamera();
	}

	class PassRenderShadow : RenderPassSolid
	{
		this()
		{
			super(50);
		}
		
		import engine.rend.opengl.Wrapper;
		
		override void renderAll(void delegate(SceneNode) beforeRender)
		{
			profile!("render.shadow")
			({
				renderer.setTexture(0, null);
				
				glColorMask(false, false, false, false); // TODO: opengl removal
				super.renderAll(beforeRender);
				glColorMask(true, true, true, true);
			});
		}
	}
	
	class PassInjectShadow : RenderPass
	{
		mixin MLogger;
		RenderPass inner;
		
		protected override void add_(Camera camera, RenderFunc func)
		{
			inner.add(camera, func);
		}

		this(RenderPass inner)
		{
			super(inner.priority);
			this.inner = inner;
		}

		override void renderAll(void delegate(SceneNode) beforeRender)
		{
			profile!("render.shadow")
			({
				logger_.spam("shadow inner: {}", inner);
			
				bool setup = false;
				
				scope(exit)
					renderer.setTexture(2, null);
					
				inner.renderAll((SceneNode node)
				{
					if(!setup)
					{
						auto shadowCamera = sceneGraph.getCamera("shadow");
						auto shader = renderer.getCurrentShader();
					
						shader.setUniform("shadowTexture", 2);
						shader.setUniform("lightTransform", shadowCamera.core.projection *
															shadowCamera.core.modelview);
						
						renderer.setTexture(2, shadowCamera.framebuffer.texture);
						
						setup = true;
					}
				
					auto shader = renderer.getCurrentShader();
					shader.setUniform("modelTransform", node.absoluteTransformation);
				});
			});
		}
		
		override void reset()
		{
			super.reset();
			inner.reset();
		}
	}

	RenderPass passRenderShadow;

	static this()
	{
		gEffectLibrary.addEffect(new typeof(this));
	}
}
