module engine.image.Image;

import derelict.opengl.gl;
import derelict.opengl.glu;

import engine.mem.Memory;
import engine.math.Vector;

enum ImageFormat
{
	A = 1,
	RA = 2,
	RGB = 3,
	RGBA = 4
}

class Image
{
protected:
	ubyte[] _data;
	uint _width;
	uint _height;
	ImageFormat _format;
	
public:
	mixin MAllocator;

	static uint formatToOpenGL(ImageFormat format) // TODO: doesn't belong here
	{
		switch(format)
		{
		case ImageFormat.A:
			return GL_LUMINANCE;
			
		case ImageFormat.RA:
			return GL_LUMINANCE_ALPHA;
			
		case ImageFormat.RGB:
			return GL_RGB;
			
		case ImageFormat.RGBA:
			return GL_RGBA;
			
		default:
			assert(false);
		}
		
		assert(false);
	}

	this()
	{
		
	}

	this(uint width, uint height, ImageFormat format = ImageFormat.RGB)
	{
		_width = width;
		_height = height;
		_format = format;
		
		_data.alloc(width * height * cast(uint)format);
	}
	
	~this()
	{
		free();
	}

	void save(char[] file)
	{
		assert(false);
	}
	
	void resize(uint w, uint h)
	{
		if(w == width && h == height)
			return;

		ubyte[] newData;
		newData.alloc(w * h * cast(uint)format);

		if(gluScaleImage(formatToOpenGL(format), width, height, GL_UNSIGNED_BYTE,
						 data.ptr, w, h, GL_UNSIGNED_BYTE, newData.ptr) != 0)
		{
			throw new Exception("ur mum");
		}
		
		.free(_data);
		_data = newData;
		_width = w;
		_height = h;
	}
	
	void setByte(uint x, uint y, uint o, ubyte b)
	{
		assert(_data);
		
		_data[(y * width + x) * cast(uint)format + o] = b;
	}

	ubyte getByte(uint x, uint y, uint o)
	{
		assert(_data);
		
		return _data[(y * width + x) * cast(uint)format + o];
	}

	void setRed(uint x, uint y, ubyte r)
	{
		assert(cast(uint)format >= 3 || format == ImageFormat.RA);
		
		setByte(x, y, 0, r);
	}
	
	ubyte getRed(uint x, uint y)
	{
		assert(cast(uint)format >= 3);
		
		return getByte(x, y, 0);
	}
	
	void setGreen(uint x, uint y, ubyte g)
	{
		assert(cast(uint)format >= 3);
		
		setByte(x, y, 1, g);
	}
	
	ubyte getGreen(uint x, uint y)
	{
		assert(cast(uint)format >= 3);
		
		return getByte(x, y, 1);
	}
	
	void setBlue(uint x, uint y, ubyte b)
	{
		assert(cast(uint)format >= 3);
		
		setByte(x, y, 2, b);
	}
	
	ubyte getBlue(uint x, uint y)
	{
		assert(cast(uint)format >= 3);
		
		return getByte(x, y, 2);
	}
	
	void setRGB(uint x, uint y, ubyte r, ubyte g, ubyte b)
	{
		assert(cast(uint)format >= 3);
		
		setRed(x, y, r);
		setGreen(x, y, g);
		setBlue(x, y, b);
	}
	
	void setAlpha(uint x, uint y, ubyte a)
	{
		switch(format)
		{
		case ImageFormat.RGBA:
			setByte(x, y, 3, a);
			return;
		
		case ImageFormat.RA:
			setByte(x, y, 1, a);
		
		case ImageFormat.A:
			setByte(x, y, 0, a);
			return;
			
		default:
			assert(false);
		}
	}
	
	ubyte getAlpha(uint x, uint y)
	{
		switch(format)
		{
		case ImageFormat.RGBA:
			return getByte(x, y, 3);
		
		case ImageFormat.RA:
			return getByte(x, y, 1);
		
		case ImageFormat.A:
			return getByte(x, y, 0);
			
		default:
			assert(false);
		}
		
		assert(false);
	}

	ubyte[] data()
	{
		return _data;
	}
	
	void data(ubyte[] d)
	{
		assert(d.length == _data.length);
		_data[] = d[];
	}
	
	uint width()
	{
		return _width;
	}
	
	uint height()
	{
		return _height;
	}
	
	vec2i dimension()
	{
		return vec2i(width, height);
	}
	
	ImageFormat format()
	{
		return _format;
	}
	
	void free()
	{
		.free(_data);
	}
	
	bool hasAlphaChannel()
	{
		return format == ImageFormat.A || format == ImageFormat.RA || format == ImageFormat.RGBA;
	}
	
	void createAlphaChannel(vec3ub[] colors ...)
	{
		assert(format == ImageFormat.RGB);
		assert(_data.ptr !is null);
		
		_format = ImageFormat.RGBA;
		
		ubyte[] newData;
		newData.alloc(width * height * cast(uint)format);
		
		scope(success)
		{
			.free(_data);
			_data = newData;
		}
		
		scope(failure)
		{
			_format = ImageFormat.RGB;
			.free(newData);
		}
		
		ubyte* read = data.ptr;
		ubyte* write = newData.ptr;
		
		for(uint i = 0; i != width * height; i++)
		{
			ubyte r = *read;
			read++;
			
			ubyte g = *read;
			read++;
			
			ubyte b = *read;
			read++;
			
			*write = r;
			write++;
			
			*write = g;
			write++;
			
			*write = b;
			write++;
			
			foreach(color; colors)
			{
				if(r == color.x && g == color.y && b == color.z)
				{
					*(write - 3) = *(write - 2) = *(write - 1) = 0;
					*write = 0;
				}
				else
					*write = 255;
			}
				
			write++;
		}
	}
}
