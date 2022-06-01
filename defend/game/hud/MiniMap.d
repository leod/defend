module defend.game.hud.MiniMap;

import engine.util.Debug;
import engine.core.TaskManager;
import engine.image.Image;
import engine.math.Rectangle;
import engine.math.Vector;
import engine.math.Matrix;
import engine.scene.Camera;
import engine.scene.Graph;
import engine.scene.cameras.StaticCamera;
import engine.rend.Renderer;
import engine.rend.Texture;
import engine.rend.opengl.Wrapper;
import engine.mem.Memory;
import engine.util.Sprite;
import engine.util.Wrapper;

import defend.Config;
import defend.sim.Core;
import defend.terrain.ITerrain;

class MiniMap
{
private:
	const width = 128;
	const height = 128;

	GameObjectManager gameObjects;
	ITerrain terrain() { return gameObjects.terrain; }
	
	Texture texture;
	Sprite sprite;

	Framebuffer objectLayer;

	vec2i position;

	void renderTerrain()
	{
		renderer.setViewport(Rect(0, 0, width, height));

		renderer.identity(MatrixType.Projection);
		glOrtho(terrain.dimension.x - 1, 0, terrain.dimension.y - 1, 0, 0, 1337);
		
		renderer.identity();
		
		auto center = vec2( (terrain.dimension.x - 1),
		                   -(terrain.dimension.y - 1));
		
		gluLookAt(center.x, 500.0f, center.y, center.x, 0.0f,
		          center.y, 0.0f, 0.0f, 1.0f);

		renderer.clear();
		terrain.renderOrthogonal();

		//renderer.clear(vec3(128, 128, 128));
		texture.copyFromScreen();
		renderer.clear();

		renderer.setViewport(Rect(0, 0, renderer.width, renderer.height));
	}

	void updateObjects()
	{
		renderer.setFramebuffer(objectLayer);
		renderer.clear(vec3.one);
		
		renderer.unsetFramebuffer(objectLayer);
	}

public:
	mixin MAllocator;

	this(GameObjectManager gameObjects)
	{
		this.gameObjects = gameObjects;
	
		texture = renderer.createTexture(vec2i(width, height));
		renderTerrain();
		
		sprite = new Sprite(texture, Rect(0, 0, width - 1, height - 1), true);
		sprite.scaling = vec2(128.0f / width, 128.0f / width);
		
		objectLayer = renderer.createFramebuffer(vec2i(width, height));
		
		position = vec2i(renderer.width - 150, renderer.height - HUD_HEIGHT + 10);
		
		taskManager.addRepeatedTask(&updateObjects, 1);
	}

	~this()
	{
		delete sprite;
		delete texture;
		delete objectLayer;
	}

	void render()
	{
		// shadow mapping debug
		//sprite.render(position, sceneGraph.getCamera("shadow").framebuffer.texture);
		//return;
	
		assert(texture !is null);
		assert(sprite !is null);

		renderer.setRenderState(RenderState.Blending, true);

		renderer.setBlendFunc(BlendFunc.SrcAlpha, BlendFunc.OneMinusSrcAlpha);

		renderer.setTexture(0, null);
		renderer.setTexture(1, null);

		sprite.render(position, texture);

		renderer.setTexture(0, texture);
		renderer.setTexture(1, terrain.lightmap);

		for(uint i = 0; i < 2; i++)
		{
			if(i == 1) renderer.setBlendFunc(BlendFunc.One, BlendFunc.One);

			glBegin(GL_QUADS);
			glMultiTexCoord2fARB(GL_TEXTURE0_ARB, 0, 1);
			glMultiTexCoord2fARB(GL_TEXTURE1_ARB, 0, 1);
			//glMultiTexCoord2fARB(GL_TEXTURE2_ARB, 0, 1);
			glVertex3f(position.x, position.y, 0);
			glMultiTexCoord2fARB(GL_TEXTURE0_ARB, 1, 1);
			glMultiTexCoord2fARB(GL_TEXTURE1_ARB, 1, 1);
			//glMultiTexCoord2fARB(GL_TEXTURE2_ARB, 0, 1);
			glVertex3f(position.x + width, position.y, 0);
			glMultiTexCoord2fARB(GL_TEXTURE0_ARB, 1, 0);
			glMultiTexCoord2fARB(GL_TEXTURE1_ARB, 1, 0);
			//glMultiTexCoord2fARB(GL_TEXTURE2_ARB, 0, 1);
			glVertex3f(position.x + width, position.y + height, 0);
			glMultiTexCoord2fARB(GL_TEXTURE0_ARB, 0, 0);
			glMultiTexCoord2fARB(GL_TEXTURE1_ARB, 0, 0);
			//glMultiTexCoord2fARB(GL_TEXTURE2_ARB, 0, 1);
			glVertex3f(position.x, position.y + height, 0);
			glEnd();
		}
		
		renderer.setTexture(0, null);
		renderer.setTexture(1, null);
		renderer.setTexture(2, null);
		
		renderer.setRenderState(RenderState.Blending, false);
	}
	
	bool pointInside(vec2i pos)
	{
		return pos.x > position.x && pos.x < position.x + width &&
		       pos.y > position.y && pos.y < position.y + height;
	}
	
	vec2 translatePoint(vec2i pos, vec2i scale)
	in
	{
		assert(pointInside(pos));
	}
	out(result)
	{
		assert(terrain.within(vec2us.from(result)));
	}
	body
	{
		auto offset = pos - position;
		auto result = vec2(scale.x / cast(float)width * offset.x,
		                   scale.y - scale.y / cast(float)height * offset.y);
		
		return result;
	}
}
