module engine.scene.nodes.CullNode;

import engine.math.Vector;
import engine.math.BoundingBox;
import engine.rend.Renderer;
import engine.scene.Node;
import engine.scene.Camera;
import engine.scene.Graph;

class CullNode : SceneNode
{
	BoundingBox!(float) boundingBox;
	vec3 color = vec3.one;

	this(SceneNode parent)
	{
		super(parent);
	}
	
	this(SceneNode parent, BoundingBox!(float) bb)
	{
		super(parent);
	
		boundingBox = bb;
	}
	
	override void registerForRendering(Camera camera)
	{
		visible = camera.frustum.boundingBoxVisible(boundingBox);
	}
	
	debug void render()
	{
		renderer.drawBoundingBox(boundingBox, color);
	}
}
