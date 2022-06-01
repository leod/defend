module defend.effects.shader.GameObject;

import engine.math.Vector;
import engine.util.Debug;
import engine.rend.Renderer;
import engine.scene.Node;
import engine.scene.Graph;
import engine.scene.Camera;
import engine.scene.RenderPass;
import engine.scene.passes.Solid;
import engine.scene.passes.Blended;
import engine.scene.effect.Effect;
import engine.scene.effect.Library;

import defend.Config : gDefendConfig;
import defend.terrain.Terrain;
import defend.sim.SceneNode;

private class EffectImpl : GameObjectEffect
{
	Shader normalShader;
	Shader neutralShader;

	this()
	{
		super("shader", 80);
	}

	override void registerForRendering(Camera camera, GameObjectMesh node)
	{
		if(sceneGraph.cameraData.shadowMap)
			return;
	
		RenderPass renderPass;
		
		if(!node.parent.isNeutral)
			renderPass = pass;
		else
			renderPass = passNeutralBlended;
		
		renderPass.add(camera, node, &render);
	}
	
	void render(GameObjectMesh node)
	{
		auto shader = renderer.getCurrentShader();
	
		renderer.pushMatrix();
		renderer.mulMatrix(node.absoluteTransformation);
		
		renderer.setTexture(0, node.texture);
		
		if(gDefendConfig.graphics.objects_lightmap)
			shader.setUniform("mapPos", node.absolutePosition);
		
		if(!node.parent.isNeutral) shader.setUniform("color", node.parent.color);
		shader.setUniform("diffuseTexture", 0);

		node.renderMesh();

		renderer.popMatrix();
	}

	override void init()
	{
		normalShader = Shader("model.cfg");
		neutralShader = Shader("model-neutral.cfg");
		
		pass = sceneGraph.addRenderPass(new Pass);
		passNeutralBlended = sceneGraph.addRenderPass(new PassNeutralBlended);
		
	}

	override void release()
	{
		subRef(normalShader);
		subRef(neutralShader);
	}

	override bool supported()
	{
		return renderer.caps.shaders;
	}

	override void inject(RenderPass delegate(RenderPass) dg)
	{
		assert(pass !is null);
		assert(passNeutralBlended !is null);
		
		pass = dg(pass);
		passNeutralBlended = dg(passNeutralBlended);
	}

	static this()
	{
		gEffectLibrary.addEffect(new typeof(this));
	}

	void setup(Shader shader)
	{
		renderer.setShader(shader);
		renderer.setLightPosition(0, vec3(10, 10, 0));
		
		if(gDefendConfig.graphics.objects_lightmap)
		{
			shader.setUniform("lightTexture", 1);
			shader.setUniform("mapSize", vec3(terrain.dimension.x, terrain.dimension.y, 0));
			
			renderer.setTexture(1, fogOfWarTexture);
		}
	}

	void cleanup()
	{
		renderer.setTexture(1, null);
		renderer.setShader(null);
		renderer.setTexture(2, null);
		renderer.setTexture(0, null);
	}

	class Pass : RenderPassSolid
	{
		override void renderAll(void delegate(SceneNode) beforeRender)
		{
			EffectImpl.setup(normalShader);
			scope(exit) EffectImpl.cleanup();
			
			super.renderAll(beforeRender);
		}
	}

	class PassNeutralBlended : RenderPassBlended
	{	
		override void renderAll(void delegate(SceneNode) beforeRender)
		{
			EffectImpl.setup(neutralShader);
			scope(exit) EffectImpl.cleanup();
			
			super.renderAll(beforeRender);
		}
	}
	
	RenderPass pass;
	RenderPass passNeutralBlended;
}
