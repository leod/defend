module defend.editor.Editor;

import tango.core.Memory;
import tango.math.Math;
import tango.util.container.HashMap;

import xf.hybrid.Hybrid : gui, Group, TextList, Button, horizontalMenu, menuGroup, menuLeaf, loadHybridConfig;
import xf.hybrid.WidgetConfig : HybridConfig = Config;

import engine.core.TaskManager;
import engine.input.Input;
import engine.math.Matrix;
import engine.math.Vector;
import engine.math.Ray;
import engine.rend.Renderer;
import engine.scene.Node;
import engine.scene.Graph;
import engine.scene.nodes.ModelNode;
import engine.util.GameState;
import engine.hybrid.OGLRenderer : HybridRenderer = Renderer;
import engine.hybrid.Input : setupHybridInputTunnel, cleanHybridInputTunnel;
import engine.util.Debug;
import engine.util.Sprite;
import engine.util.Log : MLogger;
import engine.util.Array;
import engine.util.Signal;
import engine.model.Model;
import engine.image.Devil;

import defend.common.Camera;
import defend.common.Graphics;
import defend.common.MouseBase;
import defend.demo.Player;
import defend.game.hud.MiniMap; // todo: move
import defend.sim.Core;
import defend.sim.FogOfWar : DisableFogOfWar;
import defend.sim.GameInfo;
import defend.sim.Gateway;
import defend.sim.Heightmap;
import defend.sim.IFogOfWar : IFogOfWar;
import defend.sim.Player;
import defend.sim.Map;
import defend.terrain.Terrain;

package class EditorPlayerManager : PlayerManager
{
	Signal!(player_id_t) onRemovePlayer;
	Signal!(player_id_t) onAddPlayer;
	
	player_id_t addPlayer()
	{
		player_id_t id = players.length;
		players.length = players.length + 1;
		
		players[id] = new Player;
		players[id].info.id = id;
		players[id].info.exists = true;
		
		onAddPlayer(id);
		
		return id;
	}
	
	void removePlayer(player_id_t id)
	{
		assert(false, "todo");
	}
}

package class EditorGameObjectManager : GameObjectManager
{
	DisableFogOfWar fogOfWar;

	void onRemovePlayer(player_id_t id)
	{
		assert(false, "todo");
	}
	
	void onAddPlayer(player_id_t id)
	{
		assert(!(id in civs));
		
		players[id].fogOfWar = fogOfWar;
		
		auto civ = new Civ;
		civ.owner = id;
		
		auto simTypes = typeRegister().createAllTypes!(SimType.ObjectType)(id, this);
		
		foreach(type; simTypes)
		{
			if((type.isNeutral && id == NEUTRAL_PLAYER ||
			   !type.isNeutral && id != NEUTRAL_PLAYER))
			   civ.types[type.id] = type;
			else
				delete type;
		}
		
		foreach(type; civ.types)
			type.construct();
		
		civs[id] = civ;
	}

	this(EditorPlayerManager players, Terrain terrain, Map map)
	{
		_players = players;
		_terrain = terrain;
		_map     = map;
	
		players.onRemovePlayer.connect(&onRemovePlayer);
		players.onAddPlayer.connect(&onAddPlayer);
	
		objects = new HashMap!(object_id_t, GameObject);
		objectAppender = &appendObject;
		
		fogOfWar = new typeof(fogOfWar);
	}
	
	void editorRemove(GameObject gameObject)
	{
		super.removeObject(gameObject);
	}
	
	override Gateway gateway()
	{
		assert(false, "EditorGameObjectManager does not have a gateway");
	}
	
	override IFogOfWar localFogOfWar()
	{
		assert(fogOfWar !is null);
		return fogOfWar;
	}
}

package class EditorMouse : MouseBase
{
private:
	EditorGameObjectManager gameObjects;

protected:
	override bool mayOrder(GameObject)
	{
		return true;
	}
	
	override void orderMapRightClick(GameObject[] objects, map_pos_t pos)
	{
		// ignore
	}
	
	override void orderObjectRightClick(GameObject[] objects, GameObject target)
	{
		// ignore
	}
	
	override void orderRemove(GameObject[] objects)
	{
		foreach(object; objects)
			gameObjects.editorRemove(object);
	}
	
	override void orderPlaceObject(ObjectTypeInfo type, player_id_t owner, map_pos_t pos)
	{
		gameObjects.localCreate(owner, type.id, pos.x, pos.y);
	}

public:
	this(EditorGameObjectManager gameObjects, MiniMap miniMap)
	{
		super(gameObjects, miniMap);
		
		this.gameObjects = gameObjects;
	}
}

class Editor : GameState
{
	mixin MLogger;

	Graphics graphics;
	Heightmap heightmap;
	Terrain terrain;
	
	Map map;
	EditorPlayerManager players;
	EditorGameObjectManager gameObjects;
	
	EditorMouse editorMouse;
	vec2i mouseWidth;
	
	HybridRenderer hybridRenderer;
	HybridConfig hybridConfig;
	
	KeyboardReader keyboard;
	MouseReader mouse;
	
	Civ currentPlayerCiv;

	this()
	{
		mouseWidth = vec2i(6, 6); // tmp
	}
	
	void render()
	{
		renderer.begin();

		// scene graph
		if(wireframe)
			renderer.setRenderState(RenderState.Wireframe, true);
		
		graphics.render();

		if(wireframe)
			renderer.setRenderState(RenderState.Wireframe, false);
		
		// gui
		renderer.setRenderState(RenderState.DepthTest, false);
		
		gui.begin(hybridConfig);
			gui.push("main");
				with(TextList("objectTypes"))
				{
					if(anythingPicked)
					{
						editorMouse.startPlaceObject(currentPlayerCiv.owner, pickedText);
						
						/+auto selectedType = currentTypes[pickedIdx];
					
						if(currentType !is selectedType)
						{
							currentType = selectedType;
							placeObjectNode.setModel(Model.get(currentType.model));
							placeObjectNode.hide = false;
							placeObjectNode.scaling = currentType.scale;
							placeObjectNode.rotation = currentType.normRotation;
							placeObjectNode.calcTransformation();
							
							state = State.ObjectPlacement;
						}
						
						if(Button().text("Unselect").clicked)
						{
							resetPick();

							placeObjectNode.resetModel();
							placeObjectNode.hide = true;
							
							currentType = null;
							
							state = State.TerrainEdit;
						}+/
					}
				}
			gui.pop();
			
			Group("menu")
			[delegate void() { // wtf dmd assumes delegate int()
				horizontalMenu(
					menuGroup("File",
						menuLeaf("New", traceln("U")),
						menuLeaf("Quit", gameState.exit = true)
					)
				);
			}];
		gui.end();
		
		gui.render(hybridRenderer);

		// mouse pointer
		renderer.orthogonal();
		renderer.setRenderState(RenderState.Blending, true);
		editorMouse.render();
		renderer.setRenderState(RenderState.Blending, false);
		
		renderer.setRenderState(RenderState.DepthTest, true);
		
		renderer.end();
		renderer.clear();
	}
	
	void mouseUpdate()
	{
		/+mouseRay = renderer.calcMouseRay(mouse.mousePos,
		                                 graphics.mainCamera.position,
		                                 graphics.mainCamera.projection,
										 graphics.mainCamera.modelview);
										 
		auto oldTilePos = mouseTilePos;
		mouseOverTerrain = terrain.intersectRay(mouseRay, mouseTilePos);
		
		if(mouseTilePos != oldTilePos &&
		   mouseOverTerrain &&
		   abs(cast(int)mouseTilePos.x - cast(int)oldTilePos.x) <= 1 &&
		   abs(cast(int)mouseTilePos.y - cast(int)oldTilePos.y) <= 1)
		{
			switch(state)
			{
				case State.TerrainEdit:
					if(mouse.buttonStates[MouseButton.Left] == MouseInput.Type.Down)
						changeTerrain(mouseTilePos, 1);
					else if(mouse.buttonStates[MouseButton.Right] == MouseInput.Type.Down)
						changeTerrain(mouseTilePos, -1);
					
					break;
					
				case State.ObjectPlacement:
					placeObjectNode.translation = terrain.getWorldPos(mouseTilePos) + currentType.posOffset;
					placeObjectNode.color = isObjectPlaceable ? vec3(0, 1, 0) : vec3(1, 0, 0);
					
					if(mouse.buttonStates[MouseButton.Left] == MouseInput.Type.Down)
						placeCurrentObject();
					
					break;
					
				default:
					assert(false);
			}
		}+/
	}
	
	void changeTerrain(map_pos_t pos, float mod)
	{
		/+for(int x = pos.x - mouseWidth.x / 2; x < pos.x + mouseWidth.x / 2; ++x)
		{
			for(int y = pos.y - mouseWidth.y / 2; y < pos.y + mouseWidth.y / 2; ++y)
			{
				if(!terrain.within(x, y)) continue;
				
				float newHeight = heightmap.getHeight(x, y) + mod;
				
				if(newHeight > heightmap.getMaxHeight())
					newHeight = heightmap.getMaxHeight();
				
				if(newHeight < 0)
					newHeight = 0;
				
				terrain.changeHeightmap(x, y, newHeight);
				
				if(auto obj = cast(GameObject)map[x, y])
				{
					obj.sceneNode.translation = terrain.getWorldPos(obj.mapPos) + obj.typeInfo.posOffset;
				}
			}
		}+/
	}
	
	void onLeftMouseDown(MouseInput input)
	{
		/+if(mouseOverTerrain)
		{
			switch(state)
			{
				case State.TerrainEdit:
					changeTerrain(mouseTilePos, 1);
					break;
					
				case State.ObjectPlacement:
					placeCurrentObject();
					break;
				
				default:
					assert(false);
			}
		}+/
	}
	
	void onRightMouseDown(MouseInput input)
	{
		/+if(mouseOverTerrain)
			changeTerrain(mouseTilePos, -1);+/
	}
	
	bool wireframe;
	
	void toggleWireframe(KeyboardInput)
	{
		wireframe = !wireframe;
	}
	
	void quit(KeyboardInput)
	{
		gameState.exit = true;
	}
	
	void init()
	{
		keyboard = new KeyboardReader(InputChannel.global);
		keyboard.keyDownHandlers[KeyType.L] = &toggleWireframe;
		keyboard.keyDownHandlers[KeyType.Escape] = &quit;
		
		mouse = new MouseReader(InputChannel.global);
		mouse.buttonDownHandlers[MouseButton.Left] = &onLeftMouseDown;
		mouse.buttonDownHandlers[MouseButton.Right] = &onRightMouseDown;
		mouse.updateHandler = &mouseUpdate;
		
		taskManager.addRepeatedTask(&InputChannel.global.update, 100);
		taskManager.addRepeatedTask(&sceneGraph.update, 60);
		taskManager.addRepeatedTask(&renderer.window.update, 60);
		taskManager.addPostFrameTask(&render);
		
		// initialize graphics
		graphics = new Graphics;
		graphics.init(null);

		// create terrain
		{
			// initialize heightmap to zero
			heightmap = new Heightmap(map_pos_t(128, 128), 20);
			for(int x = 0; x < heightmap.size.x; ++x)
				for(int y = 0; y < heightmap.size.y; ++y)
					heightmap.setHeight(x, y, 0);
		
			GameInfo info;
			info.withFogOfWar = false;
			
			terrain = new Terrain(sceneGraph.root, null, info, heightmap);
			
			graphics.mainCamera.setTerrain(terrain);
		}
		
		// initialize sim stuff
		players = new EditorPlayerManager;
		map = new Map(heightmap);
		gameObjects = new EditorGameObjectManager(players, terrain, map);
		
		auto id = players.addPlayer();
		currentPlayerCiv = gameObjects.getCiv(id);
		
		// mouse
		editorMouse = new EditorMouse(gameObjects, new MiniMap(gameObjects));
		
		taskManager.addRepeatedTask(&editorMouse.update, 30);
		
		// initialize gui
		hybridRenderer = new HybridRenderer;
		hybridConfig = loadHybridConfig("editor-gui.cfg");
		
		gui.begin(hybridConfig);
			gui.push("main");

			with(TextList("objectTypes"))
			{
				foreach(type_; currentPlayerCiv.types)
				{
					auto type = cast(ObjectTypeInfo)type_;
					if(!type.abstractType && type.editorPlaceable)
						addItem(type.name);
				}
			}

			gui.pop();
		gui.end();
		
		setupHybridInputTunnel();
	}
	
	void done()
	{
		cleanHybridInputTunnel();
		
		delete map;
		delete gameObjects;
		delete players;
		graphics.release();
		
		keyboard.remove();
		mouse.remove();
		
		delete editorMouse;
	}
}
