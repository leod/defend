module engine.input.Input;

import engine.list.BufferedArray;
import engine.math.Vector;
import engine.util.Array;
import engine.util.Log : MLogger;
import engine.util.Profiler;
import engine.util.Singleton;

public
{
	import engine.input.KeyType;
}

final class InputChannel
{
	mixin MLogger;

private:
	BufferedArray!(Input) inputBuffer;

	InputReader[] readers;
	
public:
	static InputChannel global;

	this()
	{
		inputBuffer.create(128);		
	}
	
	~this()
	{
		inputBuffer.release();
	}
	
	void opShl(Input input)
	{
		logger_.spam("adding input of type {}", input.type);
	
		inputBuffer.append(input);
	}
	
	void addReader(InputReader reader)
	{
		logger_.spam("new reader");
	
		readers ~= reader;
		reader.channel = this;
	}
	
	void removeReader(InputReader reader)
	{
		readers.removeElement(reader);
	}
	
	void update()
	{
		logger_.spam("updating readers");
	
		profile!("input.update")
		({
			foreach(reader; readers)
				reader.update();
		});
	}
	
	void dispatch()
	{
		logger_.spam("dispatching all input");
		
		profile!("input.dispatch")
		({
			foreach(input; inputBuffer)
			{
				foreach(reader; readers)
				{
					if(input.type & reader.typeMask)
						reader.dispatch(input);
				}
			}
			
			inputBuffer.reset();
		});
	}
}

enum InputType
{
	Mouse = 1,
	Keyboard = 2
}

class InputReader
{
protected:
	InputChannel channel;

public:
	void update() {}
	abstract InputType typeMask();
	abstract void dispatch(Input input);
	
	void remove()
	{
		channel.removeReader(this);
	}
}

enum KeyState
{
	Up,
	Down
}

enum MouseButton
{
	Left,
	Middle,
	Right,
	WheelUp,
	WheelDown
}

struct MouseInput
{	
	enum Type
	{
		Move,
		Up,
		Down
	}
	
	MouseButton button;
	Type type;
	
	vec2i position;
	vec2i delta;
}

struct KeyboardInput
{
	enum Modifier
	{
		None	  = 0x0000,
		LShift	  = 0x0001,
		RShift	  = 0x0002,
		LCtrl	  = 0x0040,
		RCtrl	  = 0x0080,
		LAlt	  = 0x0100,
		RAlt	  = 0x0200
	}
	
	KeyType key;
	KeyState type;
	Modifier mod;
}

struct Input
{
	InputType type;
	
	union
	{
		MouseInput mouse;
		KeyboardInput keyboard;
	}
}

class KeyboardReader : InputReader
{
	KeyState[KeyType.max + 1] oldKeyStates;
	KeyState[KeyType.max + 1] keyStates;

	void delegate(KeyboardInput)[KeyType.max + 1] keyDownHandlers;
	void delegate(KeyboardInput)[KeyType.max + 1] keyUpHandlers;
	void delegate(KeyboardInput)[KeyType.max + 1] keyHoldHandlers;

	KeyboardInput lastInput;

	this(InputChannel channel)
	{
		channel.addReader(this);
	}

	// These must only be called from update()
	bool keyDown(KeyType t) { return oldKeyStates[t] == KeyState.Up && keyStates[t] == KeyState.Down; }
	bool keyUp(KeyType t) { return oldKeyStates[t] == KeyState.Down && keyStates[t] == KeyState.Up; }
	bool keyHold(KeyType t) { return keyStates[t] == KeyState.Down; }

	override void update()
	{
		foreach(i, state; keyStates)
		{
			if(state == KeyState.Down && keyHoldHandlers[i])
			{
				lastInput.mod = KeyboardInput.Modifier.None;
				
				if(keyHold(KeyType.LeftShift))
					lastInput.mod |= KeyboardInput.Modifier.LShift;
				
				if(keyHold(KeyType.LeftControl))
					lastInput.mod |= KeyboardInput.Modifier.LCtrl;
				
				lastInput.key = cast(KeyType)i;
				keyHoldHandlers[i](lastInput);
			}
		}

		oldKeyStates[] = keyStates[];
	}
	
	override InputType typeMask()
	{
		return InputType.Keyboard;
	}
	
	override void dispatch(Input input)
	{
		keyStates[input.keyboard.key] = input.keyboard.type;
		
		lastInput = input.keyboard;
		
		switch(input.keyboard.type)
		{
		case KeyState.Down:
			if(auto handler = keyDownHandlers[input.keyboard.key])
				handler(input.keyboard);
				
			break;
			
		case KeyState.Up:
			if(auto handler = keyUpHandlers[input.keyboard.key])
				handler(input.keyboard);
				
			break;
			
		default:
			assert(false);
		}
	}
}

class MouseReader : InputReader
{
	MouseInput.Type[MouseButton.max + 1] buttonStates;
	
	void delegate(MouseInput) moveHandler;
	void delegate(MouseInput)[MouseButton.max + 1] buttonDownHandlers;
	void delegate(MouseInput)[MouseButton.max + 1] buttonUpHandlers;
	void delegate() updateHandler;
	
	vec2i mousePos;
	vec2i mouseDelta;
	
	this(InputChannel channel)
	{
		channel.addReader(this);
	}
	
	override InputType typeMask()
	{
		return InputType.Mouse;
	}

	override void dispatch(Input input)
	{
		switch(input.mouse.type)
		{
		case MouseInput.Type.Move:
			mousePos = input.mouse.position;
			mouseDelta = input.mouse.delta;
		
			if(moveHandler)
				moveHandler(input.mouse);
			
			break;
			
		case MouseInput.Type.Down:
			input.mouse.position = mousePos;
			input.mouse.delta = mouseDelta;
		
			if(auto handler = buttonDownHandlers[input.mouse.button])
				handler(input.mouse);
			
			buttonStates[input.mouse.button] = MouseInput.Type.Down;
			
			break;
				
		case MouseInput.Type.Up:
			input.mouse.position = mousePos;
			input.mouse.delta = mouseDelta;
		
			if(auto handler = buttonUpHandlers[input.mouse.button])
				handler(input.mouse);
			
			buttonStates[input.mouse.button] = MouseInput.Type.Up;
			
			break;
			
		default:
			assert(false);
		}
	}
	
	override void update()
	{
		if(updateHandler)
			updateHandler();
	}
}
