module defend.common.MouseBase;

import tango.io.Stdout;
import tango.util.Convert;

import engine.image.Devil;
import engine.input.Input;
import engine.list.BufferedArray;
import engine.math.BoundingBox;
import engine.math.Matrix;
import engine.math.Misc;
import engine.math.Ray;
import engine.math.Rectangle;
import engine.math.Vector;
import engine.mem.Memory;
import engine.model.Model;
import engine.rend.opengl.Wrapper;
import engine.rend.Renderer;
import engine.rend.Texture;
import engine.scene.Camera;
import engine.scene.Graph;
import engine.scene.nodes.ModelNode;
import engine.sound.Sound : Sound;
import engine.util.Log : MLogger;
import engine.util.Profiler;
import engine.util.Signal;
import engine.util.Sprite;
import engine.util.Wrapper;

import defend.common.Camera;
import defend.Config;
import defend.game.hud.MiniMap;
import defend.sim.Core;
import defend.sim.IFogOfWar;
import defend.sim.Map;
import defend.terrain.ITerrain;
import defend.terrain.Patch;

abstract class MouseBase
{
	mixin MLogger;

protected:
	abstract
	{
		bool mayOrder(GameObject object);
		void orderMapRightClick(GameObject[] objects, map_pos_t pos);
		void orderObjectRightClick(GameObject[] objects, GameObject target);
		void orderRemove(GameObject[] objects);
		void orderPlaceObject(ObjectTypeInfo type, player_id_t owner, map_pos_t pos);
	}

	MainCamera camera;
	Sprite sprite; // sprite of the mouse pointer
	Ray!(float) _ray;
	
	GameObjectManager gameObjects;
	MiniMap miniMap;
	
	ITerrain terrain() { return gameObjects.terrain; }
	IFogOfWar fogOfWar() { return gameObjects.localFogOfWar; }
	
	map_pos_t _mapPos;
	void mapPos(map_pos_t p) { _mapPos = p; }

	ModelNode mouseCube;

	// Current status
	enum Status
	{
		Nothing,
		MipMapMove,
		AreaSelection,
		ObjectPlacement
	}
	
	Status _status = Status.Nothing;

	// Selection
	vec2i areaSelectionStart;
	BufferedArray!(GameObject) areaSelectionBuffer;
	
	uint lastClickOnObject; // Double click selection
	object_type_t lastClickObjectType;
	const uint DOUBLECLICK_INTERVAL = 400; // in ms
	
	BufferedArray!(GameObject) selectionBuffer;
	BufferedArray!(object_id_t) objectIDBuffer;
	
	invariant()
	{
		if(selectionBuffer.length)
		{
			auto owner = selectionBuffer[0].owner;
			
			foreach(object; selectionBuffer.toArray[1 .. $])
				assert(object.owner == owner);
		}
	}
	
	// Object placement
	object_type_t placeObject;
	ModelNode placeObjectNode;
	ObjectTypeInfo placeObjectTypeInfo;
	
	// Is the mouse over the terrain?
	bool _overTerrain;
	void overTerrain(bool b) { _overTerrain = b; }

	// Input
	KeyboardReader keyboard;
	MouseReader mouse;
	
	Status status()
	{
		return _status;
	}
	
	void status(Status s)
	{
		switch(status)
		{
		case Status.Nothing:
			break;
				
		case Status.AreaSelection:
			foreach(obj; areaSelectionBuffer)
			{
				if(selectionBuffer.length < MAX_ORDERED_OBJECTS)
					selectionBuffer.append(obj);
			}

			break;
			
		case Status.ObjectPlacement:
			placeObjectNode.hide = true;
			placeObjectNode.resetModel();
			placeObjectTypeInfo = null;
			
			break;
			
		default:
			break;
		}
		
		_status = s;
		
		switch(status)
		{
		case Status.AreaSelection:
			areaSelectionStart = mouse.mousePos;
			areaSelectionBuffer.reset();
			
			break;
			
		default:
			break;
		}
	}
	
	bool isObjectPlaceable()
	{
		assert(status == Status.ObjectPlacement);
		assert(placeObjectTypeInfo !is null);
		assert(fogOfWar !is null);
		
		return placeObjectTypeInfo.isPlaceable(mapPos) && overTerrain &&
		       fogOfWar.isRectVisible(mapPos, placeObjectTypeInfo.dimension);
	}
	
	void selectObjects(MouseInput input)
	{
		assert(status == Status.Nothing);
	 
		if(mouse.mousePos.x > renderer.width ||
		   mouse.mousePos.y > renderer.height - HUD_HEIGHT)
			return;
		
		// If left control is not pressed, deselect all objects first
		if(!keyboard.keyHold(KeyType.LeftControl))
		{
			foreach(obj; selectionBuffer)
				obj.selected = false;
				
			selectionBuffer.reset();
			SelectionChange();
		}
		
		// Check for double click selection
		if(getTickCount() - lastClickOnObject < DOUBLECLICK_INTERVAL)
		{
			// Check if the user wants to select or deselect
			bool selectedNeed = keyboard.keyHold(KeyType.LeftShift);
			
			// Go through all objects and check if they are target of this double click selection
			foreach(obj; gameObjects)
			{
				if(!obj.visible ||
				   obj.selected != selectedNeed ||
				   obj.typeInfo.id != lastClickObjectType ||
				   !mayOrder(obj) ||
				   (selectionBuffer.length && selectionBuffer[0].owner != obj.owner))
					continue;
				
				// Select objects
				if(!selectedNeed && selectionBuffer.length < MAX_ORDERED_OBJECTS)
				{
					obj.selected = true;
					selectionBuffer.append(obj);
				}
				
				// Deselect objects
				else
				{
					obj.selected = false;
					
					uint i;
					foreach(o; selectionBuffer)
					{
						if(o is obj)
						{
							selectionBuffer.remove(i);
							break;
						}

						i++;
					}
				}
			}
			
			lastClickOnObject = 0;
			SelectionChange();
		}
		
		// Select only one object
		else
		{
			bool found = false;
			
			foreach(obj; gameObjects)
			{
				// Look if the mouse ray hits this object
				if(obj.visible && obj.localFogOfWarState == FogOfWarState.Visible &&
					obj.intersectRay(ray))
				{
					// Deselect the object, if left shift is pressed
					if(obj.selected &&
					   mayOrder(obj) &&
					   keyboard.keyHold(KeyType.LeftShift))
					{
						obj.selected = false;
						
						uint i;
						foreach(o; selectionBuffer)
						{
							if(o is obj)
							{
								selectionBuffer.remove(i);
								break;
							}

							++i;
						}

						SelectionChange();
					}
					
					// Otherwise, select the object
					else
					{
						// Don't put it twice into the list
						if(!obj.selected && selectionBuffer.length < MAX_ORDERED_OBJECTS &&
						   (!selectionBuffer.length || selectionBuffer[0].owner == obj.owner))
						{
							if(obj.typeInfo.selectSound)
								Sound(obj.typeInfo.selectSound).play();
						
							selectionBuffer.append(obj);
							
							obj.selected = true;
							found = true;
							
							SelectionChange();
						}
					}
					
					// Set information for doubleclick selection
					if(mayOrder(obj))
					{
						lastClickOnObject = getTickCount();
						lastClickObjectType = obj.typeInfo.id;
					}
				}
			}
			
			// If no object was selected, go into area selection mode
			if(!found)
				status = Status.AreaSelection;
		}
	}
	
	void inputLeftClick(MouseInput input)
	{
		//particles("smoke").spawn(mouseCube.absolutePosition + vec3(0, 1, 0), 10);
		
		// Only start selection when there was no gui event
		//if(guiController.wasGuiEvent)
		//	return;
		
		switch(status)
		{
		case Status.Nothing:
			// Check if the click was on the mini map
			if(miniMap.pointInside(input.position))
			{
				status = Status.MipMapMove;
				break;
			}
		
			selectObjects(input);
			break;
		
		case Status.AreaSelection:
			assert(false);
			break;
		
		case Status.ObjectPlacement:
			if(isObjectPlaceable)
			{
				orderPlaceObject(placeObjectTypeInfo, placeObjectTypeInfo.owner, mapPos);
				
				if(!keyboard.keyHold(KeyType.LeftShift))
					status = Status.Nothing;
			}
			
			break;
			
		default:
			break;
		}
	}
	
	void inputLeftRelease(MouseInput input)
	{
		//if(guiController.wasGuiEvent)
		//	return;
	
		switch(status)
		{
		case Status.AreaSelection:
			status = Status.Nothing;

			SelectionChange();
			
			break;
			
		case Status.MipMapMove:
			status = Status.Nothing;
			
			break;
			
		default:
			break;
		}
	}
	
	void inputRightClick(MouseInput input)
	{
		//if(guiController.wasGuiEvent)
		//	return;
	
		switch(status)
		{
		case Status.Nothing:
			// Check if the click was on the mini map
			if(miniMap.pointInside(input.position))
			{
				auto translated = miniMap.translatePoint(mouse.mousePos,
				                                         vec2i.from(terrain.dimension));

				orderMapRightClick(selection, to!(map_pos_t)(translated));
				
				break;
			}

			if(overTerrain && selectionBuffer.length && mayOrder(selectionBuffer[0]) &&
		       mouse.mousePos.y <= renderer.height - HUD_HEIGHT)
			{
				GameObject target;
				
				// Check if the user clicked on the map or an object
				foreach(obj; gameObjects)
				{
					if(obj.visible && !obj.selected && obj.intersectRay(ray) &&
					   obj.localFogOfWarState == FogOfWarState.Visible)
					{
						target = obj;
						break;
					}
				}
				
				if(target is null)
				{
					orderMapRightClick(selection, mapPos);
				}
				else
				{
					orderObjectRightClick(selection, target);
				}
			}
			
			break;
			
		case Status.ObjectPlacement:
			status = Status.Nothing;
			
			break;
			
		default:
			break;
		}
	}
	
	void inputDelete(KeyboardInput)
	{
		if(selectionBuffer.length && mayOrder(selectionBuffer[0]))
		{
			orderRemove(selection);
			selectionBuffer.reset();
		}
	}
	
	/+void inputStartOrderQueue(KeyboardInput)
	{
		gameObjects.startOrderQueue();
	}
	
	void inputStopOrderQueue(KeyboardInput)
	{
		gameObjects.stopOrderQueue();
	}+/
	
	object_id_t[] toObjectIDList(GameObject[] objects)
	{
		objectIDBuffer.reset();

		foreach(obj; objects)
			objectIDBuffer.append(obj.id);

		return objectIDBuffer.toArray();
	}

	// Slots
	void onObjectDead(GameObject object)
	{
		if(!object.selected)
			return;

		object.selected = false;

		uint i;
		foreach(o; areaSelectionBuffer)
		{
			if(o is object)
			{
				areaSelectionBuffer.remove(i);
				break;
			}

			i++;
		}

		i = 0;
		foreach(o; selectionBuffer)
		{
			if(o is object)
			{
				selectionBuffer.remove(i);
				break;
			}

			i++;
		}
		
		if(status == Status.ObjectPlacement)
			status = Status.Nothing;

		SelectionChange();
	}

public:
	Signal!() SelectionChange;

	this(GameObjectManager gameObjects, MiniMap miniMap)
	{
		this.gameObjects = gameObjects;

		gameObjects.onRemoveObject.connect(&onObjectDead);
		gameObjects.onObjectDead.connect(&onObjectDead);

		this.miniMap = miniMap;

		camera = cast(MainCamera)sceneGraph.getCamera("main").core;
		assert(camera !is null, "fail.");
	
		{
			auto image = DevilImage.load(Texture.findResourcePath("mouse.png").fullPath);
			image.createAlphaChannel(vec3ub(255, 0, 255));
			
			sprite = new Sprite(renderer.createTexture(image));
		}

		mouseCube = new ModelNode(sceneGraph.root, "box/box.obj");

		mouseCube.scaling = vec3(0.05, 0.05, 0.05);
		mouseCube.hide = false;
		mouseCube.renderShadow = true;

		placeObjectNode = new ModelNode(sceneGraph.root);
		placeObjectNode.hide = true;
		placeObjectNode.renderShadow = true;
		
		keyboard = new KeyboardReader(InputChannel.global);
		keyboard.keyDownHandlers[KeyType.Delete] = &inputDelete;
		//keyboard.keyDownHandlers[KeyType.C] = &inputStartOrderQueue;
		//keyboard.keyUpHandlers[KeyType.C] = &inputStopOrderQueue;
		
		mouse = new MouseReader(InputChannel.global);
		mouse.buttonDownHandlers[MouseButton.Left] = &inputLeftClick;
		mouse.buttonUpHandlers[MouseButton.Left] = &inputLeftRelease;
		mouse.buttonDownHandlers[MouseButton.Right] = &inputRightClick;
		
		areaSelectionBuffer.create();
		selectionBuffer.create();
		objectIDBuffer.create();
	}

	~this()
	{
		mouse.remove();
		
		delete sprite;
		
		areaSelectionBuffer.release();
		selectionBuffer.release();
		objectIDBuffer.release();
	}

	vec2i getScreenPos(vec3 pos)
	{
		GLint[4] viewport;

		auto modelview = mat4d.from(camera.modelview());
		auto projection = mat4d.from(camera.projection());

		viewport[2] = renderer.width;
		viewport[3] = renderer.height;

		vec3d result;
		gluProject(pos.x, pos.y, pos.z,
		           modelview.ptr, projection.ptr, viewport.ptr,
		           &result.x, &result.y, &result.z);

		return vec2i(cast(int)result.x, renderer.height - cast(int)result.y);
	}

	void startPlaceObject(player_id_t owner, object_type_t type)
	{
		if(status == Status.ObjectPlacement)
			return;
	
		placeObject = type;
		
		assert(placeObjectNode !is null);
		placeObjectTypeInfo = gameObjects.getTypeInfo(owner, type);
		
		placeObjectNode.hide = false;
		placeObjectNode.setModel(Model.get(placeObjectTypeInfo.model));
		placeObjectNode.scaling = placeObjectTypeInfo.scale;
		placeObjectNode.rotation = placeObjectTypeInfo.normRotation;
		placeObjectNode.calcTransformation();
		
		status = Status.ObjectPlacement;
	}

	Ray!(float) ray()
	{
		return _ray;
	}

	map_pos_t mapPos()
	{
		return _mapPos;
	}

	bool overTerrain()
	{
		return _overTerrain;
	}

	void update()
	{
		profile!("mouse.update")
		({
			_ray = renderer.calcMouseRay(mouse.mousePos, camera.position,
			                             camera.projection, camera.modelview);
			
			// ray-terrain intersection
			overTerrain = terrain.intersectRay(_ray, _mapPos);
			
			mouseCube.hide = !overTerrain;
			mouseCube.translation = terrain.getWorldPos(mapPos);
			
			switch(status)
			{
			case Status.MipMapMove:
				if(miniMap.pointInside(mouse.mousePos))
				{								
					auto translated = miniMap.translatePoint(mouse.mousePos,
						vec2i(terrain.dimension.x, terrain.dimension.y));
					
					camera.position = vec3(translated.x, camera.position.y,
						-translated.y + 10);
				}
				
				break;
			
			case Status.AreaSelection:
				auto mousePos = mouse.mousePos;
				
				auto minX = min(areaSelectionStart.x, mousePos.x);
				auto maxX = max(areaSelectionStart.x, mousePos.x);
				auto minY = min(areaSelectionStart.y, mousePos.y);
				auto maxY = max(areaSelectionStart.y, mousePos.y);

				foreach(obj; areaSelectionBuffer)
					obj.selected = false;

				areaSelectionBuffer.reset();

				foreach(obj; gameObjects)
				{
					if(obj.selected ||
					   !mayOrder(obj) ||
					   obj.typeInfo.objectClass != ObjectClass.Unit)
						continue;

					auto pos = getScreenPos(obj.realPos);
					//auto rect = obj.screenRect;

					if((pos.x >= minX && pos.x <= maxX &&
					   pos.y >= minY && pos.y <= maxY) &&
					   selectionBuffer.length + areaSelectionBuffer.length < MAX_ORDERED_OBJECTS)
					{
						obj.selected = true;
						areaSelectionBuffer.append(obj);
					}
				}
				
				break;
			
			case Status.ObjectPlacement:
				with(placeObjectNode)
				{
					hide = !overTerrain;
					translation = terrain.getWorldPos(mapPos) +
					              placeObjectTypeInfo.posOffset;
					color = isObjectPlaceable ? vec3(0, 1, 0) : vec3(1, 0, 0);
				}
				
				break;
			
			default:
				return;
			}
		});
	}

	GameObject[] selection()
	{
		return selectionBuffer.toArray;
	}

	object_id_t[] selectionIDs()
	{
		return toObjectIDList(selection);
	}

	void render()
	{
		auto mousePos = mouse.mousePos;
	
		renderer.setRenderState(RenderState.Blending, true);
		sprite.render(mousePos);
		renderer.setRenderState(RenderState.Blending, false);
		
		glDisable(GL_TEXTURE_2D);

		// Render health bar above selected objects
		foreach(obj; gameObjects)
		{
			if(!obj.selected)
				continue;

			obj.screenPos = getScreenPos(obj.realPos);

			auto bbox = obj.boundingBox;

			with(bbox)
			{
				//obj.screenPos_[0] = getScreenPos(min);
				//obj.screenPos_[1] = getScreenPos(vec3(max.x, min.y, min.z));
				obj.screenPos_[2] = getScreenPos(vec3(min.x, max.y, min.z));
				obj.screenPos_[3] = getScreenPos(vec3(max.x, max.y, min.z));
				//obj.screenPos_[4] = getScreenPos(vec3(min.x, min.y, max.z));
				//obj.screenPos_[5] = getScreenPos(vec3(max.x, min.y, max.z));
				obj.screenPos_[6] = getScreenPos(vec3(min.x, max.y, max.z));
				obj.screenPos_[7] = getScreenPos(max);
			}
			
			/+obj.screenRect = Rectangle!(int)(int.max, int.max, int.min, int.min);

			with(obj.screenRect)
			{
				foreach(x; obj.screenPos_)
				{
					left = min(left, x.x);
					right = max(right, x.x);
					top = min(top, x.y);
					bottom = max(bottom, x.y);
				}
			}+/
		}

		// TODO: Don't use GL directly
		renderer.setRenderState(RenderState.Blending, true);
		renderer.setBlendFunc(BlendFunc.SrcAlpha, BlendFunc.OneMinusSrcAlpha);
		
		glBegin(GL_QUADS);

		foreach(obj; gameObjects)
		{
			if(!obj.selected)
				continue;
			
			const int BAR_WIDTH = 28;
			const int BAR_HEIGHT = 5;
			const int BORDER_SIZE = 1;

			auto start = (obj.screenPos_[2] +
				obj.screenPos_[3] +
				obj.screenPos_[6] +
				obj.screenPos_[7]) / 4 - vec2(BAR_WIDTH / 2, BAR_HEIGHT / 2 + 15);
			auto end = start + vec2(BAR_WIDTH, BAR_HEIGHT);
			
			if(end.x <= 0)
				continue;
			
			// white border
			glColor4f(1, 1, 1, 0.5);

			glVertex2f(start.x, start.y);
			glVertex2f(start.x, end.y);
			glVertex2f(end.x, end.y);
			glVertex2f(end.x, start.y);

			// green bar
			glColor3f(1, 0, 0);
			
			glVertex2f(start.x + BORDER_SIZE, start.y + BORDER_SIZE);
			glVertex2f(start.x + BORDER_SIZE, end.y - BORDER_SIZE);
			glVertex2f(end.x - BORDER_SIZE, end.y - BORDER_SIZE);
			glVertex2f(end.x - BORDER_SIZE, start.y + BORDER_SIZE);

			// red bar
			{
				glColor3f(0, 1, 0);

				auto percent = cast(real)(obj.life / obj.property(GameObject.Property.MaxLife));
				
				uint endX = cast(int)(start.x + BAR_WIDTH * percent);

				glVertex2f(start.x + BORDER_SIZE, start.y + BORDER_SIZE);
				glVertex2f(start.x + BORDER_SIZE, end.y - BORDER_SIZE);
				glVertex2f(endX - BORDER_SIZE, end.y - BORDER_SIZE);
				glVertex2f(endX - BORDER_SIZE, start.y + BORDER_SIZE);
			}

			/*glColor4f(0, 0, 1, 0.8);
			
			foreach(x; obj.screenPos_)
			{
				glVertex2f(x.x, x.y);
				glVertex2f(x.x, x.y + 3);
				glVertex2f(x.x + 3, x.y + 3);
				glVertex2f(x.x + 3, x.y);
			}*/

			glColor3f(1, 1, 1);
		}

		glEnd();

		renderer.setRenderState(RenderState.Blending, false);

		if(status == Status.AreaSelection)
		{
			// Render area selection box
			auto minX = min(areaSelectionStart.x, mousePos.x);
			auto maxX = max(areaSelectionStart.x, mousePos.x);
			auto minY = min(areaSelectionStart.y, mousePos.y);
			auto maxY = max(areaSelectionStart.y, mousePos.y);

			glBegin(GL_LINES);
			glColor3f(1, 1, 1);
			
			// top
			glVertex2f(minX, minY);
			glVertex2f(maxX, minY);

			// bottom
			glVertex2f(minX, maxY);
			glVertex2f(maxX, maxY);

			// left
			glVertex2f(minX, minY);
			glVertex2f(minX, maxY);

			// right
			glVertex2f(maxX - 1, minY);
			glVertex2f(maxX - 1, maxY);
			
			glEnd();
			
			renderer.setRenderState(RenderState.Blending, true);
			renderer.setBlendFunc(BlendFunc.SrcAlpha, BlendFunc.OneMinusSrcAlpha);
			
			glBegin(GL_QUADS);
			
			glColor4f(0, 0, 0.5, 0.1);
			
			glVertex2f(minX + 1, minY + 1);
			glVertex2f(minX + 1, maxY - 1);
			glVertex2f(maxX - 1, maxY - 1);
			glVertex2f(maxX - 1, minY + 1);
			
			glEnd();
			
			glColor3f(1, 1, 1);
			
			renderer.setRenderState(RenderState.Blending, false);
		}

		glEnable(GL_TEXTURE_2D);
	}
}
