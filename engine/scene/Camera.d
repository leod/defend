module engine.scene.Camera;

import engine.math.Vector;
import engine.math.Matrix;
import engine.math.Frustum;

interface Camera
{
	/**
	 * Update the camera, calculate matrices and allow input
	 */
	void update();
	
	/**
	 * Return the frustum
	 */
	Frustum!(float) frustum();
	
	/**
	 * Return the modelview matrix
	 */
	mat4 modelview();
	
	/**
	 * Return the projection matrix
	 */
	mat4 projection();
	
	/**
	 * The absolute position
	 */
	vec3 position();
}
