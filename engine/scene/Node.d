module engine.scene.Node;

import engine.rend.Renderer;
import engine.rend.Texture;
import engine.rend.Shader;
import engine.math.Matrix;
import engine.math.Vector;
import engine.math.BoundingBox;
import engine.scene.Camera;
import engine.list.TreeList;
import engine.mem.Memory;

class SceneNode
{	
protected:	
	// Visibility
	bool _visible = true;
	bool visible(bool b) { return _visible = b; }
	
	// Rotation and scaling
	vec3 _rotation = vec3.zero;
	vec3 _scaling = vec3.one;
	
	// Matrices
	mat4 matrixTranslation = mat4.identity;
	mat4 matrixRotation = mat4.identity;
	mat4 matrixScaling = mat4.identity;
	
	// Stores, if the matrix needs to be updated this frame
	bool recalcModelview = true;
	
	// Recalculate the modelview transformation matrix
	void calcModelview()
	{
		relativeTransformation = matrixTranslation * matrixRotation * matrixScaling;
	}

package:
	// Update the modelview matrices and recurse for any childs and neighbours
	void doUpdate()
	{
		if(recalcModelview)
			calcModelview();
		
		if(recalcModelview || (parent && parent.recalcModelview))
		{
			if(parent !is null)
				absoluteTransformation = parent.absoluteTransformation * relativeTransformation;
			
			recalcModelview = true;
		}
		
		update();
		
		if(child)
			child.doUpdate();
			
		if(next)
			next.doUpdate();
			
		recalcModelview = false;
	}
	
	// Register for rendering
	void doRegisterForRendering(Camera camera)
	{
		if(!hide)
			registerForRendering(camera);
		
		if(child && visible && !hide)
			child.doRegisterForRendering(camera);
			
		if(next)
			next.doRegisterForRendering(camera);
	}

public:
	mixin MAllocator;
	mixin MTreeList;

	// TODO: most of these don't need to be public

	// Debug data visible?
	bool debugVisible;
	
	// hack
	vec3 color = vec3.one;

	// The node's texture (null, if the node's only purpose is transformation or something else)
	Texture texture;
	
	// Shader
	Shader shader;
	
	// Render this node for shadows?
	bool renderShadow = false;
	
	// Relative position of the object
	vec3 relativePosition = vec3.zero;
	
	// Relative and absolute modelview transformation
	mat4 relativeTransformation = mat4.identity;
	mat4 absoluteTransformation = mat4.identity;
	
	// Hiding
	bool hide;

	this(SceneNode parent)
	{
		if(parent)
			parent.addChild(this);
	}

	// Rotate, translate or scale this node
	void translate(vec3 v)
	{
		translation = relativePosition + v;
	}
	
	void translation(vec3 v)
	{
		if(v == relativePosition)
			return;
		
		relativePosition = v;
		matrixTranslation = mat4.translation(relativePosition);
		recalcModelview = true;
	}
	
	void rotate(vec3 v)
	{
		rotation = _rotation + v;
	}
	
	void rotation(vec3 v)
	{
		if(v == rotation)
			return;

		_rotation = v;
		matrixRotation = rotationMat(rotation.tuple);
		recalcModelview = true;
	}
	
	void rotation(mat4 m)
	{
		matrixRotation = m;
		recalcModelview = true;
	}
	
	vec3 rotation()
	{
		return _rotation;
	}
	
	void calcTransformation()
	{
		assert(parent !is null);
		
		calcModelview();
		absoluteTransformation = parent.absoluteTransformation * relativeTransformation;
		
		iterateChildren((SceneNode node)
		{
			node.calcTransformation();
			return true;
		});
	}
	
	void scaling(vec3 v)
	{
		_scaling = v;
		matrixScaling = mat4.scaling(_scaling);
		recalcModelview = true;
	}
	
	vec3 scaling()
	{
		return _scaling;
	}
	
	vec3 absolutePosition()
	{
		return absoluteTransformation.getTranslation();
	}
	
	bool visible()
	{
		return _visible && (parent ? parent.visible : true);
	}
	
	void update()
	{
		
	}
	
	void registerForRendering(Camera camera)
	{
		
	}
	
	BoundingBox!(float) boundingBox()
	{
		BoundingBox!(float) result;
		return result;
	}
}
