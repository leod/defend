module defend.game.hud.Hud;

import xf.hybrid.Hybrid;
import xf.hybrid.WidgetConfig : HybridConfig = Config;
import xf.hybrid.Font;
import xf.hybrid.Shape;
import xf.hybrid.widgets.Input : InputWidget = Input;
import xf.hybrid.widgets.Button;
import xf.hybrid.widgets.WindowFrame;
import xf.hybrid.widgets.VBox;

import engine.mem.Memory;
import engine.util.Sprint;
import engine.util.FPS;
import engine.util.Lang;
import engine.util.Log : MLogger;
import engine.util.Statistics;
import engine.util.ProfilingDisplay;
import engine.math.Misc;
import engine.math.Vector;
import engine.rend.Renderer;
import engine.rend.opengl.Wrapper;
//import engine.sound.Source;
//import engine.sound.System : gSoundSystem;
import engine.input.Input;

import defend.Config;
import defend.sim.Core;
import defend.sim.IHud;
import defend.sim.Player;
import defend.sim.Resource;
import defend.game.hud.Mouse;
import defend.game.hud.MiniMap;
import defend.game.hud.Console;
import engine.hybrid.OGLRenderer : HybridRenderer = Renderer;
import engine.hybrid.Input : setupHybridInputTunnel, cleanHybridInputTunnel;

class Hud : IHud
{
	mixin MLogger;

private:
	HybridRenderer hybridRenderer;
	HybridConfig hybridConfig;
	
	GameObjectManager gameObjects;


	Mouse mouse;
	MiniMap miniMap;
	KeyboardReader keyboard;

	ProfilingDisplay profilingDisplay;
	bool displayProfiling = false;
	bool displayStatistic = false;
	bool displayMemory = false;

	GameObject[] selection;
	ObjectTypeInfo minimalType;
	
	const uint maxInfoLines = 6;
	const uint maxInfoLineLength = 512;
	
	struct InfoLine
	{
		char[maxInfoLineLength] buffer;
		uint length;
		uint lifetime;
	}
	
	InfoLine[maxInfoLines] infoLines;
	uint numInfoLines;
	
	Sprint!(char) sprint;
	
	void removeOneInfoLine()
	{
		for(uint i = 0; i < numInfoLines - 1; ++i)
			infoLines[i] = infoLines[i + 1];
			
		--numInfoLines;
	}
	
	void addInfoLine(char[] text)
	{
		if(numInfoLines == maxInfoLines)
			removeOneInfoLine();
	
		{
			InfoLine line;
			line.buffer[0 .. text.length] = text[];
			line.lifetime = 70;
			line.length = text.length;

			infoLines[numInfoLines++] = line;
		}
	}
	
	void updateInfoLines()
	{
		loop: for(uint i = 0; i < numInfoLines; ++i)
		{
			if(!--infoLines[i].lifetime)
			{
				assert(i == 0);
				
				removeOneInfoLine();
				goto loop;
			}
		}
	}
	
	version(none) void renderInfoLines()
	{
		for(uint i = 0; i < numInfoLines; ++i)
		{
			smallFont.write(guiRenderer, vec2i(10, 35 + i * 13),
				vec3.one, "{}",
				infoLines[i].buffer[0 .. infoLines[i].length]);
		}
	}
	
	version(none) void renderSelection()
	{
		if(minimalType && mouse.selection.length > 0)
		{
			foreach(button; minimalType.buttons)
			{
				auto index = button.index(mouse.selection[$ - 1]);
				
				if(button.showCache && index != 0)
				{
					smallFont.write(guiRenderer, button.widget.globalPosition + vec2i(12, 15),
					                vec3(1, 1, 1), "{}", index);
				}
			}
			
			uint i = 0;
			mouse.selection[$ - 1].iterateProperties((char[] name, float value)
			{
				auto pos = vec2i(240, renderer.height - HUD_HEIGHT + 10 + i * 15);
				auto color = vec3.one;
				auto format = "{}: {}";
				
				if(cast(float)cast(int)value == value)
					smallFont.write(guiRenderer, pos, color, format, name, cast(int)value);
				else
					smallFont.write(guiRenderer, pos, color, format, name, value);
				
				i++;
			});
			
			foreach(obj; mouse.selection)
				smallFont.write(guiRenderer, mouse.getScreenPos(obj.realPos),
				                vec3.one, "[{}]", obj.id);
		}
	}
	
	void renderDebugInfo()
	{	
		debug
		{
			hybridRenderer.resetClipping();
			hybridRenderer.setOffset(vec2.zero);

			Font("verdana.ttf", 15).print(vec2i(10, 10), sprint("FPS: {}", FPSCounter.get()));
			
			if(displayProfiling)
				profilingDisplay.render();

			hybridRenderer.flush();
				
			//if(screenDebugger.active)
			//	screenDebugger.render(vec2i(520, 300), smallFont);
			
			/+
			if(displayStatistic)
			{
				statistics.render(guiRenderer, vec2i(550, 150), smallFont);
				statistics.reset();
			}
			+/
		}
	}
	
	// Input
	void inputToggleProfiling(KeyboardInput)
	{
		displayProfiling = !displayProfiling;
	}
	
	void inputToggleStatistics(KeyboardInput)
	{
		displayStatistic = !displayStatistic;
	}
	
	void inputToggleMemory(KeyboardInput)
	{
		displayMemory = !displayMemory;
	}
	
	// Slots
	/+void onButtonLeftClick(ObjectButton button)
	{
		if(!mouse.selection.length || minimalType is null)
			return;
		
		if(!button.doPlaceObject)
		{
			gameObjects.order(gameObjects.gateway, mouse.selection,
							  OrderButtonLeftClick(button.id));
		}
		else
		{
			
		}
	}
	
	void onButtonRightClick(ObjectButton button)
	{
		assert(mouse.selection.length);
		assert(minimalType !is null);
		
		if(!button.doPlaceObject)
		{
			gameObjects.order(gameObjects.gateway, mouse.selection,
			                  OrderButtonRightClick(button.id));		
		}		
	}+/
	
	void onSelectionChange()
	{
		selection = mouse.selection;

		if(selection.length == 0 || !selection[0].mayBeOrdered)
		{
			minimalType = null;
			
			return;
		}
		else if(selection.length == 1)
		{
			// TODO: Show general information about the selected object (health, a picture, etc.)
		}

		minimalType = GameObject.lowestCommonType(selection);
	}

	void onInvalidOrder(GameObject[], OrderError error)
	{
		//addInfoLine(Lang.get("order_error_general"));
	}

public:
	mixin MAllocator;

	this(GameObjectManager gameObjects)
	{
		this.gameObjects = gameObjects;
		
		gameObjects.onInvalidOrder.connect(&onInvalidOrder);
		
		miniMap = new MiniMap(gameObjects);
		mouse = new Mouse(gameObjects, miniMap);
		sprint = new typeof(sprint);

		debug
		{
			profilingDisplay = new ProfilingDisplay();
		}

		mouse.SelectionChange.connect(&onSelectionChange);
		
		keyboard = new KeyboardReader(InputChannel.global);
		keyboard.keyDownHandlers[KeyType.P] = &inputToggleProfiling;
		keyboard.keyDownHandlers[KeyType.N] = &inputToggleStatistics;
		keyboard.keyDownHandlers[KeyType.O] = &inputToggleMemory;
		
		hybridRenderer = new HybridRenderer;
		hybridConfig = loadHybridConfig("game-gui.cfg");
		
		setupHybridInputTunnel();
	}
	
	~this()
	{
		keyboard.remove();
		cleanHybridInputTunnel();
		
		delete mouse;
		delete miniMap;
		delete profilingDisplay;
	}

	override void startPlaceObject(object_type_t type)
	{
		mouse.startPlaceObject(gameObjects.gateway.id, type);
	}

	void update()
	{
		mouse.update();
		
		updateInfoLines();
	}

	void render()
	{
		//miniMap.render();
		//return;
	
		//renderSelection();
		//renderInfoLines();
		
		logger_.spam("rendering");
		
		gui.begin(hybridConfig);
            
            gui.push("main");
            
				// object buttons
				HBox("hud").userSize(vec2(renderer.width, HUD_HEIGHT)).
					parentOffset(vec2(0, renderer.height - HUD_HEIGHT));
				
				gui.push("hud");
				
					VBox("left")
						.userSize(vec2(205, HUD_HEIGHT - 20))
					[{
						if(minimalType)
							minimalType.doLeftHud(this, selection);
					}];
					
					VBox("middle")
						.userSize(vec2(renderer.width - 2 * 205, HUD_HEIGHT - 20))
					[{
						if(minimalType)
							minimalType.doMiddleHud(this, selection);
					}];
					
				gui.pop();
				
				// resource display
				HBox("resourceDisplay").
					parentOffset(vec2(100, 10))
				[{
					auto player = gameObjects.players[gameObjects.gateway.id];
				
					foreach(type, amount; player.resources)
					{
						Label(type).text(
							sprint("{}: {}",
							Lang.get("resources", resourceTypes[type]), amount));
					}
				}];
				
			gui.pop();
            
        gui.end();
        gui.render(hybridRenderer);
		
		renderDebugInfo();
		
		miniMap.render();
		mouse.render();
	}
}
