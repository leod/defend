module engine.rend.Renderer;

import engine.util.Config;
import engine.util.Resource : MResource, ResourcePath;
import engine.util.Profiler;
import engine.image.Image;
import engine.image.Devil;
import engine.math.Vector;
import engine.math.Matrix;
import engine.math.Ray;
import engine.math.Rectangle;
import engine.math.BoundingBox;
import engine.rend.Window;
import engine.rend.IndexBuffer;
public import engine.util.RefCount;

// The one and only global renderer instance
Renderer renderer;

/**
 * Renderer exception
 */
class RendererException : Exception
{
public:
	this(char[] msg)
	{
		super(msg);
	}
}

/**
 * Configuration for the renderer
 */
struct RendererConfig
{
	vec2i dimension;
	char[] title = "GEN Application";
	bool fullscreen = true;
	uint depth = 24;
	
	float aspect()
	{
		return dimension.x / cast(float)dimension.y;
	}
}

/**
 * Renderstates
 */
enum RenderState
{
	Light,
	Texture,
	Fog,
	DepthTest,
	Blending,
	Wireframe,
	ZWrite,
	BackfaceCulling
}

/**
 * Matrix types
 */
enum MatrixType
{
	Modelview,
	Projection
}

/**
 * Texture mode
 */
enum TextureMode
{
	Modulate,
	Replace
}

/**
 * Fog modes
 */
enum FogMode
{
	Exp,
	Linear
}

/**
 * Blending functions
 */
enum BlendFunc
{
	Zero,
	One,
	SrcColor,
	OneMinusSrcColor,
	DstColor,
	OneMinusDstColor,
	SrcAlpha,
	OneMinusSrcAlpha,
	DstAlpha,
	OneMinusDstAlpha
}

enum BlendOp
{
	Add,
	Sub,
	Min,
	Max
}

/**
 * Base for textures
 */
abstract class Texture
{
	enum Filter
	{
		Nearest,
		Linear,
		MipMapLinear,
	}

	mixin MResource;

	static Texture loadResource(ResourcePath path)
	{
		auto image = DevilImage.load(path.fullPath);

		return renderer.createTexture(image);
	}
	
	/**
	 * Returns the image's dimensions
	 */
	abstract uint width();
	abstract uint height();
	abstract vec2i dimension();
	
	/**
	 * Returns the texture format
	 */
	abstract ImageFormat format();

	/**
	 * Update a texel
	 */
	abstract void update(int x, int y, vec3ub col);

	/**
	 * Copies the screen content into the texture
	 */
	abstract void copyFromScreen();
	
	abstract void setFilter(Filter filter);
	abstract void clamp();
}

/**
 * Shaders
 */
abstract class Shader
{
	mixin MResource;

	// Global defines, will be set for each shader
	static char[][char[]] defines;
	
	static void define(char[] name, char[] value = "")
	{
		defines[name] = value;
	}
	
	static Shader loadResource(ResourcePath path)
	{
		return renderer.createShader(path);
	}

	void setUniform(char[] name, int value);
	void setUniform(char[] name, vec2 value);
	void setUniform(char[] name, vec3 value);
	void setUniform(char[] name, vec4 value);
	void setUniform(char[] name, mat4 value);
}

/**
 * Framebuffers
 */
abstract class Framebuffer
{
	Texture texture();
}

/**
 * Capabilities
 */
struct RendererCaps
{
	bool multiTexturing;
	bool shaders;
	bool framebuffers;
	bool vertexBuffers;
	bool blendEquation;
}

/**
 * 3D-renderer interface
 */
abstract class Renderer
{
public:
	enum Engine
	{
		OpenGL
	}

	/**
	 * Returns the renderer's capabilities
	 */
	RendererCaps caps();

	/**
	 * Clears the screen.
	 */
	void clear(vec3 color = vec3.zero, bool color = true, bool depth = true);
	
	/**
	 * Update
	 */
	void update();
	
	/**
	 * Start rendering
	 */
	void begin();
	
	/**
	 * Stop rendering
	 */
	void end();
	
	/**
	 * Set a matrix
	 */
	void setMatrix(mat4 m, MatrixType type = MatrixType.Modelview);
	
	/**
	 * Push the matrix stack
	 */
	void pushMatrix(MatrixType type = MatrixType.Modelview);
	
	/**
	 * Pop the matrix stack
	 */
	void popMatrix(MatrixType type = MatrixType.Modelview);

	/**
	 * Multiply the current matrix
	 */
	void mulMatrix(mat4 m, MatrixType type = MatrixType.Modelview);
	
	/**
	 * Returns a matrix
	 */
	mat4 getMatrix(MatrixType type = MatrixType.Modelview);
	
	/**
	 * Sets an orthogonal projection matrix
	 */
	void orthogonal(vec2i size = vec2i.zero);
	
	/**
	 * Translates the current modelview matrix
	 */
	final void translate(vec3 v, MatrixType type = MatrixType.Modelview)
	{
		mulMatrix(mat4.translation(v), type);
	}
	
	/// Ditto
	final void translate(float x, float y, float z, MatrixType type = MatrixType.Modelview)
	{
		mulMatrix(mat4.translation(vec3(x, y, z)), type);
	}
	
	/**
	 * Rotates the current modelview matrix
	 */
	final void rotate(vec3 v, MatrixType type = MatrixType.Modelview)
	{
		mulMatrix(mat4.zRotation(v.z) * mat4.xRotation(v.x) * mat4.yRotation(v.y), type);
	}
	
	/// Ditto
	final void rotate(float x, float y, float z, MatrixType type = MatrixType.Modelview)
	{
		mulMatrix(mat4.zRotation(z) * mat4.xRotation(x) * mat4.yRotation(y), type);
	}
	
	/**
	 * Scales the current matrix
	 */
	final void scale(vec3 v, MatrixType type = MatrixType.Modelview)
	{
		mulMatrix(mat4.scaling(v), type);
	}
	
	/// Ditto
	final void scale(float x, float y, float z, MatrixType type = MatrixType.Modelview)
	{
		scale(vec3(x, y, z));
	}
	
	/// Ditto
	final void scale(float s, MatrixType type = MatrixType.Modelview)
	{
		scale(s, s, s);
	}
	
	/**
	 * Set an identity matrix
	 */
	void identity(MatrixType type = MatrixType.Modelview)
	{
		setMatrix(mat4.identity, type);
	}
	
	/**
	 * Create an index buffer
	 */
	IndexBuffer createIndexBuffer(uint count);

	/**
	 * Render a texture as a plain quad
	 */
	void drawTexture(vec3 position, Texture texture);
	
	/**
	 * Draw a line
	 */
	void drawLine(vec3 begin, vec3 end, vec3 color);
	
	/**
	 * Draw a bounding box
	 */
	final void drawBoundingBox(ref BoundingBox!(float) bbox, vec3 color)
	{
		with(bbox)
		{
			drawLine(min, vec3(max.x, min.y, min.z), color);
			drawLine(vec3(max.x, min.y, min.z), vec3(max.x, min.y, max.z), color);
			drawLine(vec3(max.x, min.y, max.z), max, color);
			drawLine(max, vec3(min.x, max.y, max.z), color);
			drawLine(vec3(min.x, max.y, max.z), vec3(min.x, max.y, min.z), color);
			drawLine(vec3(min.x, max.y, min.z), vec3(max.x, max.y, min.z), color);
			drawLine(vec3(max.x, max.y, min.z), vec3(max.x, min.y, min.z), color);
			drawLine(min, vec3(min.x, min.y, max.z), color);
			drawLine(vec3(min.x, min.y, max.z), vec3(min.x, max.y, max.z), color);
			drawLine(vec3(min.x, min.y, max.z), vec3(max.x, min.y, max.z), color);
			drawLine(min, vec3(min.x, max.y, min.z), color);
			drawLine(vec3(max.x, max.y, min.z), max, color);
		}
	}
	
	/**
	 * Create a texture
	 */
	Texture createTexture(Image image);
	
	/** 
	 * Create an empty texture
	 */
	Texture createTexture(vec2i dimension, ImageFormat format = ImageFormat.RGB);
	
	/**
	 * Use a texture for rendering
	 */
	void setTexture(uint stage, Texture texture);
	
	/**
	 * Set an texture mode
	 */
	void setTextureMode(uint stage, TextureMode mode);
	
	/**
	 * Set a blend function
	 */
	void setBlendFunc(BlendFunc source, BlendFunc target);
	void setBlendOp(BlendOp op);
	
	/**
	 * Create a framebuffer
	 */
	Framebuffer createFramebuffer(vec2i dimension,  ImageFormat format = ImageFormat.RGB);
	
	/**
	 * Set a framebuffer
	 */
	void setFramebuffer(Framebuffer framebuffer);
	void unsetFramebuffer(Framebuffer framebuffer);
	
	/**
	 * Set a renderstate
	 */
	void setRenderState(RenderState state, uint value);
	
	/// Ditto
	void setRenderState(RenderState state, bool value);
	
	/// Ditto
	void setRenderState(RenderState state, float value);
	
	/**
	 * Load a shader from a file
	 */
	Shader createShader(ResourcePath);

	/**
	 * Set a shader
	 */
	void setShader(Shader shader);
	Shader getCurrentShader();
	
	/**
	 * Set the viewport
	 */
	void setViewport(Rect rect);
	
	/**
	 * Returns the renderer configuration
	 */
	RendererConfig config();
	
	final
	{
		uint width()
		{
			return config.dimension.x;
		}
		
		uint height()
		{
			return config.dimension.y;
		}
	}
	
	/**
	 * Returns the renderer window
	 */
	Window window();

	// tmp
	void setColor(vec4 color);
	final void setColor(vec3 color) { setColor(vec4(color.tuple, 1)); }
	
	/**
	 * Enables fog
	 */
	void setFog(FogMode mode, float density, float start, float end, vec3 color);
	
	/**
	 * Lighting
	 */
	void setLightPosition(uint index, vec3 pos);
	
	/**
	 * Make a screenshot
	 */
	void screenshot(char[] file);

	Ray!(float) calcMouseRay(vec2i mousePos, vec3 pos, ref mat4 proj, ref mat4 modelview);
	
	Engine engine()
	{
		return engine_;
	}

protected:
	Engine engine_;
}

vec2i getTextureSizeForScreen(uint width, uint height)
{
	return vec2i(1024, 1024);

	assert(width > height);
	
	return vec2i(width, width);
}
