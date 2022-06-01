module engine.sound.Source;

interface Source
{
	/**
	 * Move this sound source
	 */
	void setPosition(float x, float y, float z);
	
	/**
	 * Set the velocity
	 */
	void setVelocity(float x, float y, float z);
}
