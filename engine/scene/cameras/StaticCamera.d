module engine.scene.cameras.StaticCamera;

import engine.math.Vector;
import engine.math.Matrix;
import engine.math.Frustum;
import engine.scene.Camera;

/+modelview: [-1.38, -1.57, 0.00] + [39.30, 109.20, -62.50] -> [(1.00,0.00,0.02,-3
7.65); (0.00,1.00,-0.02,-110.67); (-0.02,0.02,1.00,60.91); (0.00,0.00,0.00,1.00)
]

modelview: [-1.38, -1.57, 0.00] + [39.30, 109.20, -62.50] -> [(0.00,0.00,1.00,62
.47); (0.98,0.19,-0.00,-59.34); (-0.19,0.98,0.00,-99.76); (0.00,0.00,0.00,1.00)]+/

class StaticCamera : Camera
{
private:
	vec3 _position;
	vec3 _rotation;
	
	mat4 _projection;
	mat4 _modelview;
	
	Frustum!(float) _frustum;
	
	void updateModelview()
	{
		_modelview = zRotationMat!(float)(rotation.z) *
			xRotationMat!(float)(rotation.x) *
			yRotationMat!(float)(rotation.y) *
			mat4.translation(position * -1);

		//Stdout.formatln("modelview: {} + {} -> {}", _modelview);
		//Stdout.formatln("creating dem frusturmmmm:\n{}\n{}", _modelview, _projection);

		_frustum.create(_modelview, _projection);
		
		//Stdout.formatln("{}", _projection);
	}
	
public:
	this(vec3 position, vec3 rotation, mat4 projection)
	{
		_position = position;
		_rotation = rotation;
		_projection = projection;
		
		_frustum = new Frustum!(float);
		
		updateModelview();
	}
	
	override void update()
	{
		// Nothing
	}
	
	override Frustum!(float) frustum()
	{
		return _frustum;
	}
	
	override mat4 modelview()
	{
		return _modelview;
	}
	
	override mat4 projection()
	{
		return _projection;
	}

	override vec3 position()
	{
		return _position;
	}
	
	void position(vec3 p)
	{
		_position = p;
		updateModelview();
	}
	
	void rotation(vec3 r)
	{
		_rotation = r;
		updateModelview();
	}
	
	vec3 rotation()
	{
		return _rotation;
	}
}
