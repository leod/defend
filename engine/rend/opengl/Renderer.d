module engine.rend.opengl.Renderer;

import tango.stdc.stringz;
import tango.text.Util;
import Float = tango.text.convert.Float;

version(UseSDL)
{
	import derelict.sdl.sdl;
}
else
{
	version(Windows)
	{
		import tango.sys.win32.UserGdi;
	}

	import derelict.opengl.wgl;
	import GL = derelict.util.wintypes;

	private const CDS_FULLSCREEN = 4;
	private const CDS_RESET = 0x40000000;
	private const DISP_CHANGE_SUCCESSFUL = 0;
}

import derelict.opengl.extension.arb.multitexture;
import derelict.opengl.extension.arb.vertex_buffer_object;
import derelict.opengl.extension.arb.vertex_shader;
import derelict.opengl.extension.arb.fragment_shader;
import derelict.opengl.extension.ext.framebuffer_object;
import derelict.opengl.extension.ext.blend_minmax;

import engine.util.Log : MLogger;
import engine.util.Config;
import engine.util.Profiler;
import engine.util.Wrapper;
import engine.util.Statistics;
import engine.image.Image;
import engine.image.Devil;
import engine.math.Vector;
import engine.math.Matrix;
import engine.math.Rectangle;
import engine.math.Ray;
import engine.rend.Window;
import engine.rend.Shader;
import engine.rend.Texture;
import engine.rend.IndexBuffer;
import engine.rend.Renderer;
import engine.rend.VertexContainer : Usage, VertexContainer;
import engine.rend.opengl.Shader;
import engine.rend.opengl.IndexBuffer;
import engine.rend.opengl.Texture;
import engine.rend.opengl.Wrapper;
import engine.rend.opengl.FBO;
import engine.rend.opengl.Framebuffer;
import engine.rend.opengl.TextureFB;
import engine.rend.opengl.sdl.Window;
import engine.rend.opengl.VertexContainer : VertexArray, VertexBuffer;

class OGLRenderer : Renderer
{
	mixin MLogger;

private:
	static uint[MatrixType.max + 1] matrixMap;
	static uint[BlendFunc.max + 1] blendFuncMap;
	static uint[BlendOp.max + 1] blendOpMap;
	
	static this()
	{
		matrixMap[MatrixType.Modelview] = GL_MODELVIEW;
		matrixMap[MatrixType.Projection] = GL_PROJECTION;
		

		blendFuncMap[BlendFunc.Zero] = GL_ZERO;
		blendFuncMap[BlendFunc.One] = GL_ONE;
		blendFuncMap[BlendFunc.SrcColor] = GL_SRC_COLOR;
		blendFuncMap[BlendFunc.OneMinusSrcColor] = GL_ONE_MINUS_SRC_COLOR;
		blendFuncMap[BlendFunc.DstColor] = GL_DST_COLOR;
		blendFuncMap[BlendFunc.OneMinusDstColor] = GL_ONE_MINUS_DST_COLOR;
		blendFuncMap[BlendFunc.SrcAlpha] = GL_SRC_ALPHA;
		blendFuncMap[BlendFunc.OneMinusSrcAlpha] = GL_ONE_MINUS_SRC_ALPHA;
		blendFuncMap[BlendFunc.DstAlpha] = GL_DST_ALPHA;
		blendFuncMap[BlendFunc.OneMinusDstAlpha] = GL_ONE_MINUS_DST_ALPHA;
		
		blendOpMap[BlendOp.Add] = GL_FUNC_ADD;
		blendOpMap[BlendOp.Sub] = GL_FUNC_SUBTRACT;
		blendOpMap[BlendOp.Min] = GL_MIN;
		blendOpMap[BlendOp.Max] = GL_MAX;
	}
	
	RendererCaps _caps;

	RendererConfig _config;
	Window _window;
	
	Shader currentShader;
	Texture[9] currentTexture;

	version(UseSDL)
	{
		
	}
	else version(Windows)
	{
		HANDLE hdc;
		HANDLE hglrc;
	}
	else version(linux)
	{
		import derelict.util.xtypes;
		import derelict.opengl.glx;

		struct XF86VidModeModeInfo
		{
			uint dotclock;
			ushort hdisplay;
			ushort hsyncstart;
			ushort hsyncend;
			ushort htotal;
			ushort hskew;
			ushort vdisplay;
			ushort vsyncstart;
			ushort vsyncend;
			ushort vtotal;
			ushort flags;
			int privsize;
			int * c_private;
		}

		alias XID Colormap;

		struct XErrorEvent
		{
			int type;
			Display *display;
			XID resourceid;
			ulong serial;
			ubyte error_code;
			ubyte request_code;
			ubyte minor_code;
		}

		Display* display;
		XVisualInfo* visual;
		GLXContext context;
		Colormap colormap;

		extern(C) static int errorHandler(Display* d, XErrorEvent* e)
		{
			char[1024] buffer;
			XGetErrorText(d, e.error_code, cast(byte*)toStringz(buffer), 1024);
			Stderr("X Error: ")(buffer);

			return 0;
		}
	}

	void init()
	{
		version(UseSDL)
		{
			if(SDL_Init(SDL_INIT_VIDEO) < 0)
				throw new RendererException("unable to initialize SDL");
				
			if(SDL_InitSubSystem(SDL_INIT_VIDEO) < 0)
				throw new RendererException("unable to initialize SDL video");
				
			SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
			
			if(SDL_SetVideoMode(config.dimension.x, config.dimension.y, 0,
								SDL_OPENGL | (config.fullscreen ? SDL_FULLSCREEN : 0)) is null)
				throw new RendererException("unable to create OpenGL screen");
				
			SDL_WM_SetCaption(toStringz(config.title), null);
			//SDL_WM_GrabInput(SDL_GRAB_ON);
			SDL_ShowCursor(0);
			
			_window = new SDLWindow(config.dimension);
		}
		else version(Windows)
		{
			static assert(false, "use sdl");
		
			 _window = new MSWindow(config.title,
						            vec2i(config.dimension.x + 8,
						            config.dimension.y + 29));

			if(_config.fullscreen)
			{
				SetForegroundWindow(cast(HWND)_window.handle);

				DEVMODE settings;
				memset(&settings, 0, DEVMODE.sizeof);
				settings.dmSize = DEVMODE.sizeof;
				settings.dmPelsWidth = _config.dimension.width;
				settings.dmPelsHeight = _config.dimension.height;
				settings.dmBitsPerPel = _config.depth;
				settings.dmFields = DM_BITSPERPEL | DM_PELSWIDTH | DM_PELSHEIGHT;
				
				if(ChangeDisplaySettingsA(&settings, CDS_FULLSCREEN | CDS_RESET) != DISP_CHANGE_SUCCESSFUL)
					throw new RendererException("failed to go fullscreen");
			}

			static PIXELFORMATDESCRIPTOR pfd = { PIXELFORMATDESCRIPTOR.sizeof,
							     1,
							     PFD_DRAW_TO_WINDOW |
							     PFD_SUPPORT_OPENGL |
							     PFD_DOUBLEBUFFER,
							     PFD_TYPE_RGBA,
							     32, // Fix me
							     0, 0, 0, 0, 0, 0,
							     0,
							     0,
							     0,
							     0, 0, 0, 0,
							     16,
							     0,
							     0,
							     PFD_MAIN_PLANE,
							     0,
							     0, 0, 0 };
												 
			auto  hwnd = cast(HWND)_window.handle;
			hdc = GetDC(cast(GL.HANDLE)hwnd);

			if(!hdc)
				throw new RendererException("cannot get hdc");

			auto pixelFormat = ChoosePixelFormat(hdc, &pfd);
			if(pixelFormat == 0)
				throw new RendererException("failed to choose the pixel format");

			if(!SetPixelFormat(hdc, pixelFormat, &pfd))
				throw new RendererException("failed to set the pixel format");

			hglrc = cast(HANDLE)wglCreateContext(cast(GL.HANDLE)hdc);
			if(!hglrc)
				throw new RendererException("failed to create renderer context");

			if(!wglMakeCurrent(cast(GL.HANDLE)hdc, cast(GL.HANDLE)hglrc))
				throw new RendererException("failed to activate the renderer context");
		}
		else version(linux)
		{
			static assert(false, "use sdl");
		
			XSetErrorHandler(&errorHandler);

			display = XOpenDisplay(null);
			if(!display)
				throw new RendererException("failed to open display");
				
			int screen = XDefaultScreen(display);

			int modeCount;
			
			int* attributes = cast(int*)new int[11];
			attributes[0] = GLX_RGBA;
			attributes[1] = GLX_DOUBLEBUFFER;
			attributes[2] = GLX_RED_SIZE;
			attributes[3] = 8;
			attributes[4] = GLX_GREEN_SIZE;
			attributes[5] = 8;
			attributes[6] = GLX_BLUE_SIZE;
			attributes[7] = 8;
			attributes[8] = GLX_DEPTH_SIZE;
			attributes[9] = 16;
			attributes[10] = None;
			visual = glXChooseVisual(display, screen, attributes);
			if(!visual)
				throw new RendererException("failed to create visual");

			context = glXCreateContext(display, visual, cast(GLXContext)None, GL_TRUE);
			if(!context)
				throw new RendererException("failed to create renderer context");
			
			colormap = XCreateColormap(display, XRootWindow(display, visual.screen),
			                           visual.visual, AllocNone);
			
			_window = new XWindow(_config.title, _config.dimension, display, screen,
					      visual, colormap);
				
			if(_config.fullscreen)
				XMapWindow(display, cast(Window)_window.handle);
			else
				XMapRaised(display, cast(Window)_window.handle);
				
			if(!glXMakeCurrent(display, cast(GLXDrawable)_window.handle, context))
				throw new RendererException("failed to activate the renderer");
				
			XFlush(display);
		}
		
		//setRenderState(RenderState.DepthTest, true);
		setRenderState(RenderState.Texture, true);
		glDepthFunc(GL_LEQUAL);
	}

	void initCaps()
	{
		with(_caps)
		{
			multiTexturing = ARBMultitexture.isEnabled;
			shaders = ARBVertexShader.isEnabled && ARBFragmentShader.isEnabled;
			framebuffers = EXTFramebufferObject.isEnabled;
			vertexBuffers = ARBVertexBufferObject.isEnabled;
			blendEquation = EXTBlendMinmax.isEnabled;
		}

		logger_.info("multitexturing: {}", _caps.multiTexturing);
		logger_.info("shaders: {}", _caps.shaders);
		logger_.info("framebuffers: {}", _caps.framebuffers);
		logger_.info("vertexbuffers: {}", _caps.vertexBuffers);
		logger_.info("blendequation: {}", _caps.blendEquation);

		//with(_caps)
		//	multiTexturing = shaders = framebuffers = vertexBuffers =
		//	blendEquation = true;
	}

public:
	this(RendererConfig c)
	{
		engine_ = Engine.OpenGL;
		_config = c;

		version(UseSDL)
			DerelictSDL.load();
		
		DerelictGL.load();
		init();

		DerelictGL.loadExtensions();
		initCaps();
		
		DerelictGLU.load();
	}

	~this()
	{
		version(UseSDL)
		{
			SDL_Quit();
		}
		else
		{
			version(Windows)
			{
				wglMakeCurrent(null, null);
			}
			else version(linux)
			{
				if(display) XCloseDisplay(display);
				if(visual) XFree(visual);
				XFreeColormap(display, colormap);
			}
		}
	}

	override RendererCaps caps()
	{
		return _caps;
	}

	override void clear(vec3 color2 = vec3.zero, bool color = true, bool depth = true)
	{
		logger_.spam("clearing");
	
		glClearColor(color2.tuple, 0.0);
		glClear(GL_DEPTH_BUFFER_BIT | GL_COLOR_BUFFER_BIT);
	}

	override void update()
	{
		logger_.spam("updating window");
		_window.update();
	}

	override void begin()
	{
		
	}

	override void end()
	{
		logger_.spam("swapping buffers");
	
		version(UseSDL)
		{
			SDL_GL_SwapBuffers();
		}
		else
		{
			version(Windows)
			{
				SwapBuffers(hdc);
			}
			else version(linux)
			{
				glXSwapBuffers(display, cast(GLXDrawable)_window.handle);
			}
		}
	}
	
	override void setMatrix(mat4 m, MatrixType type)
	{
		glMatrixMode(matrixMap[type]);
		glLoadMatrixf(cast(GLfloat*)&m);
	}
	
	override void pushMatrix(MatrixType type)
	{
		glMatrixMode(matrixMap[type]);
		glPushMatrix();
	}
	
	override void popMatrix(MatrixType type)
	{
		glMatrixMode(matrixMap[type]);
		glPopMatrix();
	}
	
	override void mulMatrix(mat4 m, MatrixType type)
	{
		glMatrixMode(matrixMap[type]);
		glMultMatrixf(cast(GLfloat*)&m);
	}
	
	override mat4 getMatrix(MatrixType type)
	{
		mat4 result;
		glGetFloatv(type == MatrixType.Modelview ? GL_MODELVIEW_MATRIX : GL_PROJECTION_MATRIX,
					cast(GLfloat*)&result);
		
		return result;
	}
	
	override void orthogonal(vec2i size = vec2i.zero)
	{
		if(size == vec2i.zero)
			size = config.dimension;
	
		//GLint[4] viewport;
		//glGetIntegerv(GL_VIEWPORT, viewport.ptr);
		
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		glOrtho(0, size.x, size.y, 0, 0, 1337);
	}

	V createVertexContainer(V : VertexContainer!(T, U), T, Usage U)(T[] elements)
	{
		//if(ARBVertexBufferObject.isEnabled)
		//	return new VertexBuffer!(T, U)(elements);
		//else
			return new VertexArray!(T, U)(elements);
	}

	override IndexBuffer createIndexBuffer(uint count)
	{
		return new OGLIndexBuffer(count);
	}

	override void drawTexture(vec3 position, Texture texture)
	{
		setTexture(0, texture);
		
		pushMatrix(MatrixType.Modelview);
		translate(position);
		
		with(texture.dimension)
		{
			glBegin(GL_QUADS);
			glTexCoord2f(0, 0);
			glVertex3f(-width / 2, -height / 2, 0);
			glTexCoord2f(1, 0);
			glVertex3f( width / 2, -height / 2, 0);
			glTexCoord2f(1, 1);
			glVertex3f( width / 2,  height / 2, 0);
			glTexCoord2f(0, 1);
			glVertex3f(-width / 2,  height / 2, 0);
			glEnd();
		}
		
		popMatrix(MatrixType.Modelview);
	}

	override void drawLine(vec3 begin, vec3 end, vec3 color)
	{
		glDisable(GL_TEXTURE_2D);
		glBegin(GL_LINES);
		glColor3f(color.x, color.y, color.z);
		glVertex3f(begin.tuple);
		glVertex3f(end.tuple);
		glColor3f(1.0, 1.0, 1.0);
		glEnd();
		//glEnable(GL_TEXTURE_2D);
	}
	
	override Texture createTexture(Image image)
	{
		//logger.trace("creating {}*{} texture (from {})", image.width, image.height,
		//             image.file ? "\"" ~ image.file ~ "\"" : "an image");
	
		return new OGLTexture(image);
	}
	
	override Texture createTexture(vec2i dimension, ImageFormat format)
	{
		//logger.trace("creating {}*{} texture render target", dimension.x, dimension.y);
	
		return new OGLTexture(dimension, format);
	}
	
	override void setTexture(uint stage, Texture texture)
	in
	{
		if(texture !is null)
			assert(cast(OGLTexture)texture !is null);
	}
	body
	{
		if(texture is currentTexture[stage]) return;
		
		if(ARBMultitexture.isEnabled)
			glActiveTextureARB(GL_TEXTURE0_ARB + stage);

		if(currentTexture[stage] is null)
			glEnable(GL_TEXTURE_2D);

		currentTexture[stage] = texture;

		if(texture is null)
		{
			glDisable(GL_TEXTURE_2D);
			return;
		}
		
		statistics.texture_changes++;

		(cast(OGLTexture)texture).bind();
	}
	
	override void setTextureMode(uint stage, TextureMode mode)
	{
		if(ARBMultitexture.isEnabled)
			glActiveTextureARB(GL_TEXTURE0_ARB + stage);
		
		glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE,
		          mode == TextureMode.Replace ? GL_REPLACE : GL_MODULATE);
	}
	
	override void setBlendFunc(BlendFunc source, BlendFunc target)
	{
		glBlendFunc(blendFuncMap[source], blendFuncMap[target]);
	}
	
	override void setBlendOp(BlendOp op)
	{
		assert(glBlendEquationEXT !is null);
		glBlendEquationEXT(blendOpMap[op]);
	}
	
	override Framebuffer createFramebuffer(vec2i dimension, ImageFormat format = ImageFormat.RGB)
	{
		//logger.info("creating {}*{} framebuffer", dimension.x, dimension.y);
		auto target = cast(OGLTexture)createTexture(dimension, format);
	
		if(EXTFramebufferObject.isEnabled)
			return new FBO(target);
		else
			return new OGLTextureFB(target);
	}
	
	override void setFramebuffer(Framebuffer framebuffer)
	{
		(cast(OGLFramebuffer)framebuffer).bind();
	}
	
	override void unsetFramebuffer(Framebuffer framebuffer)
	{
		(cast(OGLFramebuffer)framebuffer).unbind();
	}
	
	override void setRenderState(RenderState state, uint value)
	{
		assert(false);
	}
	
	override void setRenderState(RenderState state, bool value)
	{		
		uint what = 0;
		
		switch(state)
		{
		case RenderState.Light:
			what = GL_LIGHTING;
			break;
		
		case RenderState.Texture:
			what = GL_TEXTURE_2D;
			break;
		
		case RenderState.DepthTest:
			what = GL_DEPTH_TEST;
			break;
			
		case RenderState.Blending:
			what = GL_BLEND;
			
			if(value)
				glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
			
			break;
			
		case RenderState.Fog:
			what = GL_FOG;
			break;
			
		case RenderState.Wireframe:
			glPolygonMode(GL_FRONT_AND_BACK, value ? GL_LINE : GL_FILL);
			return;
			
		case RenderState.ZWrite:
			glDepthMask(cast(GLboolean)value);
			return;
			
		case RenderState.BackfaceCulling:
			what = GL_CULL_FACE;
			break;
			
		default:
			assert(false);
		}
		
		if(value) glEnable(what);
		else glDisable(what);
	}
	
	override void setRenderState(RenderState state, float value)
	{
		assert(false);
	}

	override Shader createShader(ResourcePath path)
	{
		return new OGLShader(path);
	}
	
	override void setShader(Shader shader)
	{
		if(shader is null)
		{
			OGLShader.unbind();
			currentShader = null;
			
			return;
		}
		
		if(shader is currentShader)
			return;
		
		currentShader = shader;
		statistics.shader_changes++;
			
		(cast(OGLShader)shader).bind();
	}
	
	Shader getCurrentShader()
	{
		return currentShader;
	}
	
	override void setViewport(Rect rect)
	{
		glViewport(rect.left, rect.top, rect.right, rect.bottom);
	}
	
	override RendererConfig config()
	{
		return _config;
	}

	override Window window()
	{
		return _window;
	}

	override void setColor(vec4 color)
	{
		glColor4f(color.tuple);
	}
	
	override void setFog(FogMode mode, float density, float start, float end, vec3 color)
	{
		glFogfv(GL_FOG_COLOR, cast(float*)&color);
		glFogf(GL_FOG_START, start);
		glFogf(GL_FOG_END, end);
		glFogi(GL_FOG_MODE, mode == FogMode.Exp ? GL_EXP : GL_LINEAR);
		glFogf(GL_FOG_DENSITY, density);
	}
	
	override void setLightPosition(uint index, vec3 pos)
	{
		glLightfv(GL_LIGHT0 + index, GL_POSITION, vec4(pos.tuple, 1).ptr);
	}
	
	override void screenshot(char[] file)
	{
		logger_.spam("screenshot to \"{}\"", file);
	
		scope image = new Image(width, height);
		glReadPixels(0, 0, width, height, GL_RGB, GL_UNSIGNED_BYTE, image.data.ptr);

		DevilImage.save(image, file);
	}
	
	override Ray!(float) calcMouseRay(vec2i mousePos, vec3 pos, ref mat4 projection_, ref mat4 modelview_)
	{
		GLint[4] viewport;
		
		auto pt = mousePos;
		auto modelview = mat4d.from(modelview_);
		auto projection = mat4d.from(projection_);

		viewport[2] = renderer.width;
		viewport[3] = renderer.height;
		
		pt.y = viewport[3] - pt.y;
		vec3d near, far;

		gluUnProject(pt.x, pt.y, 0.0,
		             modelview.ptr, projection.ptr, viewport.ptr,
		             &near.x, &near.y, &near.z);
		
		gluUnProject(pt.x, pt.y, 0.1,
		             modelview.ptr, projection.ptr, viewport.ptr,
		             &far.x, &far.y, &far.z);

		vec3d result = far - near;

		result = result.normalized();

		return Ray!(float)(pos, vec3(result.x, result.y, result.z));
	}
}
