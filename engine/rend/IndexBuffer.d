module engine.rend.IndexBuffer;

/**
 * Index buffer interface
 */
abstract class IndexBuffer // classes are faster than interfaces
{
	alias ushort type;
	
	/**
	 * Lock the buffer
	 */
	void lock();

	/**
	 * Unlock the buffer
	 */
	void unlock();

	/**
	 * Returns one index
	 */
	type get(size_t i);

	/**
	 * Set one index
	 */
	void set(size_t index, type elem);

	/**
	 * Returns the buffer's length
	 */
	size_t length();

	/**
	 * Returns the buffer
	 */
	type[] buffer();
}
