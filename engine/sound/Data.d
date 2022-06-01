module engine.sound.Data;

interface Data
{
	/**
	 * Returns the data.
	 */
	ubyte[] data(uint offset, uint len);
	
	/**
	 * Size of the data.
	 */
	uint size();
	
	/**
	 * Frequency.
	 */
	uint frequency();
}
