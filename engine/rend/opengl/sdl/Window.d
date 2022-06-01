module engine.rend.opengl.sdl.Window;

version(UseSDL)
{
	import derelict.sdl.sdl;

	import engine.util.Signal;
	import engine.util.Profiler;
	import engine.math.Vector;
	import engine.rend.Window;

	class SDLWindow : Window
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
			return _active;
		}
		
		override uint width()
		{
			return dimension.x;
		}
		
		override uint height()
		{
			return dimension.y;
		}
		
		override void title(char[] name)
		{
			
		}
	}
}
