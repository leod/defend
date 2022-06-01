module defend.effects.noshader.GameObject;

import engine.util.Debug;
import engine.rend.Renderer;
import engine.scene.effect.Effect;
import engine.scene.effect.Library;
import engine.scene.RenderPass;
import engine.scene.Camera;
import engine.scene.Node;
import engine.scene.Graph;
import engine.scene.passes.Solid;
import engine.scene.passes.Blended;
import engine.rend.opengl.Wrapper;
import engine.math.Vector;

import defend.Config;
import defend.terrain.Terrain;
import defend.sim.SceneNode;

/* render the game objects by doing multiple passes.
   this is used when the GPU doesn't support shaders. */

private class EffectImpl : GameObjectEffect
{
	this()
	{
		super("multipass", 20);
	}

	override void registerForRendering(Camera camera, GameObjectMesh node)
	{
		if(sceneGraph.cameraData.shadowMap)
			return;
	
		if(!node.parent.isNeutral)
		{
			pass.add(camera, node, &render);
		}
		else
		{
			passNeutralBlended.add(camera, node, &render);
		}
	}
	
	override void inject(RenderPass delegate(RenderPass) dg)
	{
		assert(false);
	}
	
	override bool supported()
	{
		return true;
	}
	
	override void init()
	{
		pass = sceneGraph.addRenderPass(new Pass);
		passNeutralBlended = sceneGraph.addRenderPass(new PassNeutralBlended);
	}
	
	void render(GameObjectMesh node)
	{
		renderer.pushMatrix();
		renderer.mulMatrix(node.absoluteTransformation);
		
		renderer.setTexture(0, node.texture);
		node.renderMesh();

		renderer.popMatrix();
	}
	
	/+void renderColor()
	{
		return;
	
		with(sceneNode)
		{
			renderer.pushMatrix();
			renderer.mulMatrix(absoluteTransformation);
			
			renderer.setColor(vec4(parent.color.tuple, 1));
			renderer.setTexture(0, texture);
			renderMesh();
			renderer.setColor(vec4(1, 1, 1, 1));

			renderer.popMatrix();		
		}
	}+/

	// Render passes
	RenderPass passColor; // render the object's team color
	RenderPass pass;
	RenderPass passNeutral;
	RenderPass passNeutralBlended;

	static void setup()
	{
		{
			vec4 specular = vec4(1.0, 1.0, 1.0, 1.0);
			vec4 ambient = vec4(0.4, 0.4, 0.4, 1.0);
			
			glMaterialfv(GL_FRONT, GL_SPECULAR, specular.ptr);
			glMaterialfv(GL_FRONT, GL_AMBIENT, ambient.ptr);
		}

		{
			vec4 position = vec4(10.0, 10.0, 0.0, 1);
			vec4 ambient = vec4(0.9, 0.9, 0.9, 1.0);
			
			glLightfv(GL_LIGHT0, GL_AMBIENT, ambient.ptr);
			glLightfv(GL_LIGHT0, GL_POSITION, position.ptr);
		}

		glEnable(GL_LIGHT0);
		
		renderer.setRenderState(RenderState.Light, true);
	}
	
	static void cleanup()
	{
		renderer.setRenderState(RenderState.Light, false);
	}
	
	class Pass : RenderPassSolid
	{
		override void renderAll(void delegate(SceneNode) beforeRender)
		{
			EffectImpl.setup();
			scope(exit) EffectImpl.cleanup();
			
			super.renderAll(beforeRender);
		}
	}
	
	class PassNeutralBlended : RenderPassBlended
	{	
		override void renderAll(void delegate(SceneNode) beforeRender)
		{
			EffectImpl.setup();
			scope(exit) EffectImpl.cleanup();
			
			super.renderAll(beforeRender);
		}
	}

	static this()
	{
		gEffectLibrary.addEffect(new typeof(this));
	}
}
