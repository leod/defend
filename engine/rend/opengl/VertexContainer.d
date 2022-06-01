module engine.rend.opengl.VertexContainer;

import engine.rend.IndexBuffer : IndexBuffer;
import engine.rend.opengl.Wrapper;
import engine.rend.Vertex : Format;
import engine.rend.VertexContainer : Primitive, Usage,
                                     GlobalContainer = VertexContainer;
import engine.util.Meta : toString;
import engine.mem.Memory;
import engine.util.Statistics;

import xf.omg.util.Meta : Range;

private
{
	template Builtin(T : int)
	{
		const Builtin = GL_INT;
	}

	template Builtin(T : float)
	{
		const Builtin = GL_FLOAT;
	}

	template Builtin(T : double)
	{
		const Builtin = GL_DOUBLE;
	}

	template Builtin(T : ushort)
	{
		const Builtin = GL_UNSIGNED_SHORT;
	}

	template BufferUsage(Usage U : Usage.StreamDraw)
	{
		const BufferUsage = GL_STREAM_DRAW_ARB;
	}

	template BufferUsage(Usage U : Usage.StreamRead)
	{
		const BufferUsage = GL_STREAM_READ_ARB;
	}

	template BufferUsage(Usage U : Usage.StreamCopy)
	{
		const BufferUsage = Usage.StreamCopy;
	}

	template BufferUsage(Usage U : Usage.StaticDraw)
	{
		const BufferUsage = GL_STATIC_DRAW_ARB;
	}

	template BufferUsage(Usage U : Usage.StaticRead)
	{
		const BufferUsage = GL_STATIC_READ_ARB;
	}

	template BufferUsage(Usage U : Usage.StaticCopy)
	{
		const BufferUsage = GL_STATIC_COPY_ARB;
	}

	template BufferUsage(Usage U : Usage.DynamicDraw)
	{
		const BufferUsage = GL_DYNAMIC_DRAW_ARB;
	}

	template BufferUsage(Usage U : Usage.DynamicRead)
	{
		const BufferUsage = GL_DYNAMIC_READ_ARB;
	}

	template BufferUsage(Usage U : Usage.DynamicCopy)
	{
		const BufferUsage = GL_DYNAMIC_COPY_ARB;
	}

	template Array(Format F : Format.Position)
	{
		const Array = GL_VERTEX_ARRAY;
	}

	template Array(Format F : Format.Diffuse)
	{
		const Array = GL_COLOR_ARRAY;
	}

	template Array(Format F : Format.Normal)
	{
		const Array = GL_NORMAL_ARRAY;
	}

	template Array(Format F : Format.Texture)
	{
		const Array = GL_TEXTURE_COORD_ARRAY;
	}

	void enableClientState(Format F)()
	{
		glEnableClientState(Array!(F));
	}

	void disableClientState(Format F)()
	{
		glDisableClientState(Array!(F));
	}

	void ARBTexture(size_t which)()
	{
		static assert(which < GL_MAX_TEXTURE_UNITS_ARB);
		const code = "GL_TEXTURE" ~ toString(which) ~ "_ARB";
		glClientActiveTextureARB(mixin(code));
	}

	void NTexture(size_t which)()
	{
		static assert(which < GL_MAX_TEXTURE_UNITS);
		const code = "GL_TEXTURE" ~ toString(which);
		glClientActiveTexture(mixin(code));
	}

	void ActiveTexture(size_t which)()
	{
		if(ARBMultitexture.isEnabled)
			ARBTexture!(which);
		//else
		//	NTexture!(which);
	}

	void setFormats(V)(void* offset)
	{
		foreach(i, element; V.Members)
			setFormat!(V, element.format, i)(offset);
	}

	void setFormat(V, Format F, size_t I)(void* offset)
	{
		alias V.Members[I] T;
		const dim = T.type.dim;
		alias T.type.flt flt;
		const builtin = Builtin!(flt);
		const typeOffset = V.tupleof[I].offsetof;

		static if(Format.Position == F)
		{
			static assert(1 == T.size); // only one position
			
			enableClientState!(F);
			glVertexPointer(dim, builtin, V.sizeof, typeOffset + offset);
		}
		else static if(Format.Diffuse == F)
		{
			static assert(1 == T.size); // only one color
			
			enableClientState!(F);
			glColorPointer(dim, builtin, V.sizeof, typeOffset + offset);
		}
		else static if(Format.Normal == F)
		{
			static assert(1 == T.size); // only one normal
			static assert(3 == dim); // only 3 dimensions
			
			enableClientState!(F);
			glNormalPointer(builtin, V.sizeof, typeOffset + offset);
		}
		else static if(Format.Texture == F)
		{
			foreach(j; Range!(T.size))
			{
				const texOffset = (j * T.type.sizeof) + typeOffset;
				ActiveTexture!(j);
				enableClientState!(F);
				glTexCoordPointer(dim, builtin, V.sizeof, texOffset + offset);
			}
		}
		else
			static assert(false); // unsupported format
	}

	void unsetFormats(V)()
	{
		foreach(i, element; V.Members)
		{
			static if(Format.Texture == element.format)
			{
				foreach(j; Range!(element.size))
				{
					ActiveTexture!(j);
					disableClientState!(element.format)();
				}
			}
			else
			{
				disableClientState!(element.format)();
			}
		}
	}

	static this()
	{
		primitiveMap_[Primitive.Line] = GL_LINES;
		primitiveMap_[Primitive.Quad] = GL_QUADS;
		primitiveMap_[Primitive.Point] = GL_POINTS;
		primitiveMap_[Primitive.Triangle] = GL_TRIANGLES;
		primitiveMap_[Primitive.TriangleStrip] = GL_TRIANGLE_STRIP;
		primitiveMap_[Primitive.TriangleFan] = GL_TRIANGLE_FAN;
	}

	GLuint[Primitive.max + 1] primitiveMap_;

	void delegate() unBinder;
	void function() unSetter;
	Object current;

	// abstract class VertexContainer(T, Usage U) should work
	template VertexContainer(T, Usage U)
	{
		abstract class VertexContainer
			: GlobalContainer!(T, U)
		{
			this(T[] elements, void* offset)
			{
				elements_ = elements;
				offset_ = offset;
			}

			~this()
			{
				if(this is current)
				{
					unsetFormats!(T);
					unbind();
					current = null;
				}
			}

			override
			{
				void dirty(size_t begin, size_t end)
				{
				}
		
				void synchronize()
				{
				}

				void draw(Primitive primitive, IndexBuffer indexBuffer = null,
						  size_t start = 0, size_t count = 0)
				{
					debug statistics.triangles_rendered +=
						(indexBuffer ? indexBuffer.length : elements_.length) / 3;

					if(this !is current)
					{
						++statistics.array_format_changes;

						if(current)
						{
							assert(unSetter);
							assert(unBinder);
						
							unSetter();
							unBinder();
						}

						current = this;
					}

					bind();
					unBinder = &unbind;
					setFormats!(T)(offset_);
					unSetter = &unsetFormats!(T);
					
					if(!indexBuffer)
					{
						glDrawArrays(
							primitiveMap_[primitive],
							start,
							count == 0 ? elements_.length : count);
					}
					else
					{
						glDrawElements(
							primitiveMap_[primitive],
							count == 0 ? indexBuffer.length : count,
							Builtin!(IndexBuffer.type),
							indexBuffer.buffer.ptr);
					}
				}

				size_t length()
				{
					return elements_.length;
				}

				T get(size_t index)
				{
					return elements_[index];
				}

				T* ptr(size_t index)
				{
					return &elements_[index];
				}

				void set(size_t index, ref T element)
				{
					elements_[index] = element;
				}
			}

			void bind()
			{
			}


			void unbind()
			{
			}

		private:
			T[] elements_;
			void* offset_;

			mixin MAllocator;
		}
	}
}

/* public access is needed because one might want to render vertex arrays
   directly via opengl */
void unbindCurrentArray()
{
	if(!current)
		return;

	unSetter();
	unBinder();
	current = null;
}

package final class VertexArray(T, Usage U)
	: VertexContainer!(T, U)
{
	this(T[] elements)
	{
		super(elements, elements.ptr);
	}
}

package final class VertexBuffer(T, Usage U)
	: VertexContainer!(T, U)
{
	this(T[] elements)
	{
		super(elements, null);
		glGenBuffersARB(1, &id_);

		bind();

		glBufferDataARB(
			GL_ARRAY_BUFFER_ARB,
			T.sizeof * elements_.length,
			cast(GLubyte*)(elements_.ptr),
			BufferUsage!(U));
	}

	~this()
	{
		glDeleteBuffersARB(1, &id_);
	}

	override
	{
		void dirty(size_t begin, size_t end)
		{
			firstSet_ = begin;
			lastSet_ = !end ? elements_.length : end;
		}

		void synchronize()
		{
			bind();
			scope(exit) unbind();

			if(GL_VBO.glBufferSubDataARB !is null)
			{
				glBufferSubDataARB(
					GL_ARRAY_BUFFER,
					firstSet_,
					lastSet_ * T.sizeof - firstSet_ * T.sizeof,
					cast(GLubyte*)(elements_[firstSet_ .. lastSet_].ptr));
			}
			else
			{
				auto buffer =
					cast(T*)glMapBufferARB(
						GL_ARRAY_BUFFER_ARB,
						GL_WRITE_ONLY_ARB);

				buffer[firstSet_ .. lastSet_] =
					elements_[firstSet_ .. lastSet_][];
				glUnmapBufferARB(GL_ARRAY_BUFFER_ARB);
			}
		}

		void set(size_t index, ref T elem)
		{
			if(index < firstSet_)
				firstSet_ = index;

			if(index + 1 > lastSet_)
				lastSet_ = index + 1;

			elements_[index] = elem;
		}
	}

	override
	{
		void bind()
		{
			glBindBufferARB(GL_ARRAY_BUFFER_ARB, id_);
		}

		void unbind()
		{
			glBindBufferARB(GL_ARRAY_BUFFER_ARB, 0);
		}
	}

private:
	size_t firstSet_;
	size_t lastSet_;
	GLuint id_;
}
