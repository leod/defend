module engine.rend.opengl.IndexBuffer;

import engine.mem.Memory;
import engine.rend.IndexBuffer;

package class OGLIndexBuffer : IndexBuffer
{
package:
	size_t count;
	
	type[] buffer_;
	
public:
	mixin MAllocator;

	this(size_t c)
	{
		count = c;
		buffer_.alloc(count);
	}
	
	~this()
	{
		buffer_.free();
	}
	
	override void lock()
	{
		
	}
	
	override void unlock()
	{
		
	}

	override type get(size_t index)
	{
		return buffer_[index];
	}

	override void set(size_t index, type elem)
	{
		buffer_[index] = elem;
	}

	override type[] buffer()
	{
		return buffer_;
	}
	
	override size_t length()
	{
		return count;
	}
}
