module engine.input.SDL;

import derelict.sdl.sdl;

import engine.input.Input;
import engine.math.Vector;
import engine.rend.Window;
import engine.rend.opengl.sdl.Window;
import engine.list.Queue;

version(UseSDL)
{
	private static MouseButton mouseTranslation[64];

	static this()
	{
		mouseTranslation[SDL_BUTTON_LEFT] = MouseButton.Left;
		mouseTranslation[SDL_BUTTON_MIDDLE] = MouseButton.Middle;
		mouseTranslation[SDL_BUTTON_RIGHT] = MouseButton.Right;
		mouseTranslation[SDL_BUTTON_WHEELUP] = MouseButton.WheelUp;
		mouseTranslation[SDL_BUTTON_WHEELDOWN] = MouseButton.WheelDown;
	}

	class SDLInputWriter
	{
	private:
		InputChannel channel;
		SDLWindow window;

		vec2i lastMousePosition;
		vec2i lastMouseDelta;

		// Slots
		void onSDLEvent(SDL_Event* event)
		{
			if(!channel)
				return;
			
			switch(event.type)
			{
			case SDL_KEYDOWN:
				Input input;
				input.type = InputType.Keyboard;
				input.keyboard.key = cast(KeyType)event.key.keysym.sym;
				input.keyboard.mod = cast(KeyboardInput.Modifier)event.key.keysym.mod;
				input.keyboard.type = KeyState.Down;
				
				channel << input;
			
				break;
			
			case SDL_KEYUP:
				Input input;
				input.type = InputType.Keyboard;
				input.keyboard.key = cast(KeyType)event.key.keysym.sym;
				input.keyboard.mod = cast(KeyboardInput.Modifier)event.key.keysym.mod;
				input.keyboard.type = KeyState.Up;
				
				channel << input;			
				
				break;

			case SDL_MOUSEBUTTONDOWN:
				Input input;
				input.type = InputType.Mouse;
				input.mouse.button = mouseTranslation[event.button.button];
				input.mouse.type = MouseInput.Type.Down;
				input.mouse.position = lastMousePosition;
				input.mouse.delta = lastMouseDelta;
				
				channel << input;

				break;
				
			case SDL_MOUSEBUTTONUP:
				Input input;
				input.type = InputType.Mouse;
				input.mouse.button = mouseTranslation[event.button.button];
				input.mouse.type = MouseInput.Type.Up;
				input.mouse.position = lastMousePosition;
				input.mouse.delta = lastMouseDelta;
				
				channel << input;

				break;
				
			case SDL_MOUSEMOTION:
				Input input;
				input.type = InputType.Mouse;
				input.mouse.position = vec2i(event.motion.x, event.motion.y);
				input.mouse.delta = vec2i(event.motion.xrel, event.motion.yrel);
				
				channel << input;
				
				lastMousePosition = input.mouse.position;
				lastMouseDelta = input.mouse.delta;
				
				break;

			default:
				break;
			}
		}
		
	public:
		this(InputChannel channel, Window window)
		{
			this.channel = channel;
			
			this.window = cast(SDLWindow)window;
			this.window.SDLEvent.connect(&onSDLEvent);
		}
	}
}
