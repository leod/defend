module engine.input.Windows;

import tango.stdc.stdlib;
import tango.stdc.string;
import tango.sys.win32.UserGdi;

import engine.rend.Window;
import engine.input.Input;
import engine.math.Vector;

/+private static uint translation[KeyType.max];

static this()
{
	translation[VK_ESCAPE]	 = KeyType.Escape;
	translation[VK_LEFT]	   = KeyType.Left;
	translation[VK_RIGHT]	  = KeyType.Right;
	translation[VK_UP]		 = KeyType.Up;
	translation[VK_DOWN]	   = KeyType.Down;
	translation[VK_RETURN]	 = KeyType.Return;
	translation[VK_PRIOR]	  = KeyType.PageUp;
	translation[VK_SPACE]	  = KeyType.Space;
	translation[VK_NEXT]	   = KeyType.PageDown;
	translation[VK_LBUTTON]	= KeyType.LeftButton;
	translation[VK_RBUTTON]	= KeyType.RightButton;
	translation[VK_MBUTTON]	= KeyType.MiddleButton;
	translation[VK_LSHIFT]	 = KeyType.LeftShift;
	translation[VK_RSHIFT]	 = KeyType.RightShift;
	translation[VK_LCONTROL]   = KeyType.LeftControl;
	translation[VK_RCONTROL]   = KeyType.RightControl;
	
	for(uint i = KeyType.A, j = 'A'; i <= KeyType.Z; i++, j++)
	{
		translation[j] = i;
	}
	
	for(uint i = KeyType.Zero; i <= KeyType.Nine; i++)
	{
		translation[i] = i;
	}
	
	for(uint i = KeyType.F1, j = VK_F1; i <= KeyType.F12; i++, j++)
	{
		translation[j] = i;
	}
}

class WindowsInputManager : InputManager
{
private:
	Window window;

	vec2i _mouseDelta;
	vec2i _mousePosition;
	vec2i mouseOldPosition;

	bool windowActive = true;
	
	typedef bool[KeyType.max + 1] KeyArray;
	
	ubyte[255] keyStatesBuffer;
	KeyArray keyStates;
	KeyArray keyStatesOld;

public:
	mixin MInkey;
	
	this(Window w)
	in
	{
		assert(w !is null, "window is null");
	}
	body
	{
		window = w;
		_mousePosition = vec2i(window.width / 2, window.height / 2);
		mouseOldPosition = vec2i(GetSystemMetrics(SM_CXSCREEN) / 2, GetSystemMetrics(SM_CYSCREEN) / 2);
		
		ShowCursor(false);
		windowActive = window.active;
	
		SetCursorPos(GetSystemMetrics(SM_CXSCREEN) / 2, GetSystemMetrics(SM_CYSCREEN) / 2);
	}

	~this()
	{
		ShowCursor(true);
	}

	override void update()
	{
		vec2i position;
		GetCursorPos(cast(POINT*)&position);

		_mouseDelta = vec2i(position.x, position.y) - vec2i(mouseOldPosition.x, mouseOldPosition.y);
		
		auto newPos = vec2i(_mousePosition.x, _mousePosition.y) + _mouseDelta;
		_mousePosition = vec2i(newPos.x, newPos.y);

		if(_mousePosition.x <= 0) _mousePosition.x = 0;
		if(_mousePosition.y <= 0) _mousePosition.y = 0;
		if(_mousePosition.x >= window.width) _mousePosition.x = window.width;
		if(_mousePosition.y >= window.height) _mousePosition.y = window.height;

		if(window.active != windowActive)
		{
			windowActive = window.active;

			if(windowActive)
				ShowCursor(true);
			else
				ShowCursor(false);
		}

		if(windowActive)
		{
			keyStatesOld[] = keyStates[];
		
			GetKeyboardState(keyStatesBuffer.ptr);
			foreach(uint index, status; keyStatesBuffer)
			{
				if(index == KeyType.max) break;
				keyStates[translation[index]] = ((status & 0x80) == 0x80);
			}
			
			SetCursorPos(GetSystemMetrics(SM_CXSCREEN) / 2, GetSystemMetrics(SM_CYSCREEN) / 2);
		}

		GetCursorPos(cast(POINT*)&position);
		mouseOldPosition = vec2i(position.x, position.y);
	}

	override bool keyPressed(KeyType key)
	{
		return windowActive && keyStates[key];
	}
	
	override bool keyReleased(KeyType key)
	{
		return windowActive && keyStatesOld[key] && !keyStates[key];
	}
	
	override bool keyPressedFirst(KeyType key)
	{
		return windowActive && !keyStatesOld[key] && keyStates[key];
	}

	override vec2i mouseDelta()
	{
		return _mouseDelta;
	}

	override vec2i mousePosition()
	{
		return _mousePosition;
	}
}
+/
