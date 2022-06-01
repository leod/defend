module engine.rend.VertexContainer;

import engine.rend.IndexBuffer : IndexBuffer;

enum Primitive
{
	Triangle,
	Line,
	Quad,
	Point,
	TriangleStrip,
	TriangleFan
}

enum Usage
{
	// specified once (by application) used only a few times by GL
	StreamDraw,

	// specified once (by GL) used a few times by application
	StreamRead,

	// specified once (by GL) used only a few times by GL
	StreamCopy,

	// specified once (by application) used many times by GL
	StaticDraw,

	// specified once (by GL) used many times by application
	StaticRead,

	// specified once (by GL) used many times by GL
	StaticCopy,

	// respecified repeatedly (by application) used many times by GL
	DynamicDraw,

	// respecified repeatedly (by GL) used many times by application
	DynamicRead,

	// respecified repeatedly (by GL) used many times by GL
	DynamicCopy
}

/**
 * Vertex Container holds a Vertex and is the base for
 * the specific renderer containers, for now created by
 * switching over the renderer type at runtime by a call to
 * renderer.createVertexContainer
 */
abstract class VertexContainerBase(T)
{
	alias T Vertex;

	/**
	 * Mark an area as dirty
	 */
	void dirty(size_t begin = 0, size_t end = 0);

	/**
	 * Synchronize local vertex data with graphic card
	 */
	void synchronize();

	/**
	 * Draw the container with the specified primitive type
	 */
	void draw(Primitive, IndexBuffer indices = null,
	          size_t start = 0, size_t count = 0);

	/**
	 * Returns the buffer's length
	 */
	size_t length();

	/**
	 * Return usage
	 */
	Usage usage();

	/**
	 * distinguish between setting and getting (do not use opIndex)
	 */
	T get(size_t index);
	void set(size_t index, ref T);
	T* ptr(size_t index = 0);
}

// FIXME: abstract class VertexContainer(T, Usage U) should work
template VertexContainer(T, Usage U)
{
	abstract class VertexContainer
		: VertexContainerBase!(T)
	{
		Usage usage()
		{
			return U;
		}
	}
}
