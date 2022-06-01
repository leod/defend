module engine.rend.Window;

import tango.core.Exception;

import engine.util.Profiler;
import engine.util.Signal;
import engine.math.Vector;

abstract class Window
{
	// Returns the internal OS handle of the window
	void* handle();
	
	// Update, process window events
	void update();
	
	// Returns if the window is currently active
	bool active();
	
	// Width of the window
	uint width();
	
	// Height
	uint height();
	
	// Set a new title
	void title(char[] name);
}

class WindowException : Exception
{
public:
	this(char[] msg)
	{
		super(msg);
	}
}

/+version(UseSDL)
{
	import derelict.sdl.sdl;
	
	final class SDLWindow : Window
	{
	private:
		vec2i dimension;
		bool _active;
		
	public:
		Signal!(SDL_Event*) SDLEvent;
	
		this(vec2i d)
		{
			dimension = d;
		}
		
		override void* handle()
		{
			return null;
		}
		
		override void update()
		{
			profile!("window.update")
			({
				SDL_Event event;
				
				while(SDL_PollEvent(&event))
				{
					switch(event.type)
					{
					case SDL_QUIT:
						// Do something
						break;
					
					case SDL_ACTIVEEVENT:
						if(event.active.state & SDL_APPACTIVE)
						{
							if(event.active.gain == 0)
								_active = false;
							else
								_active = true;
						}
						
						break;
						
					default:
						SDLEvent(&event);
					}
				}
			});
		}
		
		override bool active()
		{
			//return true;
			return _active;
		}
		
		override uint width()
		{
			return dimension.width;
		}
		
		override uint height()
		{
			return dimension.height;
		}
		
		override void title(char[] name)
		{
			
		}
	}
}
else
{
	version(Windows)
	{
		import tango.sys.win32.UserGdi;

		final class MSWindow : Window
		{
		private:
			HWND _handle;
			void handle(HWND h) { _handle = h; }

			vec2i dimension;

			bool _active;
			void active(bool a) { _active = a; }

			extern(Windows) static int callback(HWND window, uint message, uint wparam, int lparam)
			{
				switch(message)
				{
				case WM_CLOSE:
					return 0;

				case WM_CREATE:
				{
					//CREATESTRUCT* c = cast(CREATESTRUCT*)lparam;
					//SetWindowLongA(window, GWL_USERDATA, cast(int)(c.lpCreateParams));
				}
				break;

				case WM_ACTIVATE:
				{
					//MSWindow* w = cast(MSWindow*)GetWindowLongA(window, GWL_USERDATA);
					//synchronized w._active = wparam != 0;
					//if(wparam == 0) ShowWindow(window, SW_MINIMIZE);
				}
				return 0;

				default:
					return DefWindowProcA(window, message, wparam, lparam);
				}

				return true;
			}

		public:
			override bool active() { return GetActiveWindow() == _handle; }
			override void* handle() { return cast(void*)_handle; }
			override uint width() { return dimension.width; }
			override uint height() { return dimension.height; }

			this(char[] title, vec2i d)
			{
				dimension = d;
				
				auto instance = GetModuleHandleA(null);
				WNDCLASSEX wndclass;

				with(wndclass)
				{
					cbClsExtra = 0;
					cbWndExtra =0;
					hCursor = null;
					hIcon = null;
					hIconSm = null;
					hInstance = instance;
					lpfnWndProc = &callback;
					lpszClassName = toStringz("gen window");
					lpszMenuName = null;
					cbSize = WNDCLASSEX.sizeof;
					style = CS_VREDRAW | CS_HREDRAW | CS_OWNDC;
				}

				if(!RegisterClassExA(&wndclass))
					throw new WindowException("Failed to create the window class");

				handle = CreateWindowExA(0,
				                         toStringz("gen window"),
				                         toStringz(title),
				                         WS_VISIBLE | WS_OVERLAPPEDWINDOW,
				                         GetSystemMetrics(SM_CXSCREEN) / 2 - dimension.width / 2,
				                         GetSystemMetrics(SM_CYSCREEN) / 2 - dimension.height / 2,
				                         //GetSystemMetrics(SM_CXSCREEN) - dimension.width,
				                         //0,
				                         dimension.width,
				                         dimension.height,
				                         null,
				                         null,
				                         instance,
				                         cast(void*)this);

				if(!handle)
					throw new WindowException("Failed to open the window");

				ShowWindow(_handle, SW_SHOW);
				UpdateWindow(_handle);
				SetFocus(_handle);
			}
			
			~this()
			{
				DestroyWindow(_handle);
			}
			
			override void update()
			{
				MSG message;
				
				if(PeekMessageA(&message, null, 0, 0, PM_REMOVE))
				{
					TranslateMessage(&message);
					DispatchMessageA(&message);
				}
			}
			
			override void title(char[] name)
			{
				SetWindowTextA(_handle, toStringz(name));
			}
		}
	}
	else version(linux)
	{
		import engine.libs.ogl.All;
		import engine.libs.x.All;

		final class XWindow : Window
		{
		private:
			Window _handle;
			Display* display;
			vec2i dimension;

		public:
			override void* handle() { return cast(void*)_handle; }
			override bool active() { return true; }
			override uint width() { return dimension.width; }
			override uint height() { return dimension.height; }

			this(char[] t, vec2i d, Display* dsp, int screen,
			     XVisualInfo* visual, Colormap colormap)
			{
				display = dsp;
				dimension = d;
				
				XSetWindowAttributes swa;
				swa.colormap = colormap;
				swa.border_pixel = 0;
				swa.background_pixel = 0;
				swa.override_redirect = false;
				swa.event_mask = FocusChangeMask | KeyPressMask | KeyReleaseMask | PropertyChangeMask | StructureNotifyMask | KeymapStateMask | PointerMotionMask;
				_handle = XCreateWindow(display,
				                        XRootWindow(display, visual.screen),
				                        0,
				                        0,
				                        d.width,
				                        d.height,
				                        0,
				                        visual.depth,
				                        InputOutput,
				                        visual.visual,
				                        CWColormap | CWBorderPixel | CWEventMask,
				                        &swa);
				                        XStoreName(display, _handle, cast(byte*)toStringz(t));
			}
			
			override void update()
			{
				
			}

			~this()
			{
				XDestroyWindow(display, _handle);
			}
		}
	}
}
+/
