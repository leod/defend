module engine.hybrid.Input;

import xf.hybrid.Hybrid : gui;
import xf = xf.input.Input;

import engine.input.Input;

private
{
	class InputTunnel : InputReader
	{
		xf.InputChannel outgoing;
		
		this(InputChannel incoming, xf.InputChannel outgoing)
		{
			incoming.addReader(this);
			this.outgoing = outgoing;
		}
		
		override void dispatch(Input i)
		{
			switch(i.type)
			{
				case InputType.Keyboard:
					xf.KeyboardInput o = void;
					o.modifiers = cast(xf.KeyboardInput.Modifiers)i.keyboard.mod;
					o.keySym = cast(xf.KeySym)i.keyboard.key;
					o.type = i.keyboard.type == KeyState.Up ? xf.KeyboardInput.Type.Up :
						xf.KeyboardInput.Type.Down;
					
					outgoing << o;
					
					break;
					
				case InputType.Mouse:
					xf.MouseInput o = void;
					o.position = i.mouse.position;
					o.move = i.mouse.delta;
					o.type = cast(xf.MouseInput.Type)i.mouse.type;
					
					switch(i.mouse.button)
					{
						case MouseButton.Left:
							o.buttons = xf.MouseInput.Button.Left;
							break;
							
						case MouseButton.Right:
							o.buttons = xf.MouseInput.Button.Right;
							break;
							
						case MouseButton.Middle:
							o.buttons = xf.MouseInput.Button.Middle;
							break;
							
						case MouseButton.WheelDown:
							o.buttons = xf.MouseInput.Button.WheelDown;
							break;
							
						case MouseButton.WheelUp:
							o.buttons = xf.MouseInput.Button.WheelUp;
							break;
					}
					
					outgoing << o;
					
					break;
			}
		}
		
		override InputType typeMask()
		{
			return InputType.Keyboard | InputType.Mouse;
		}
	}
	
	InputTunnel tunnel;
}

void setupHybridInputTunnel()
{
	tunnel = new InputTunnel(InputChannel.global, gui.inputChannel);
}

void cleanHybridInputTunnel()
{
	assert(tunnel !is null);
	
	tunnel.remove();
	tunnel = null;
}
