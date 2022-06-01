module defend.game.hud.Mouse;

import defend.common.MouseBase;
import defend.sim.Core;
import defend.game.hud.MiniMap;

class Mouse : MouseBase
{
protected:
	override bool mayOrder(GameObject object)
	{
		return object.mayBeOrdered;
	}
	
	override void orderMapRightClick(GameObject[] objects, map_pos_t pos)
	{
		gameObjects.order(gameObjects.gateway, selection,
		                  OrderMapRightClick(mapPos.x, mapPos.y));
	}
	
	override void orderObjectRightClick(GameObject[] objects, GameObject target)
	{
		gameObjects.order(gameObjects.gateway, selection,
		                  OrderObjectRightClick(target.id),
                
		                  (OrderError error, GameObject[] objects)
		                  {
		                      // fallback to map right click
		                      if(error == OrderError.Ignored)
		                      {
							      gameObjects.order(gameObjects.gateway, objects,
		                          OrderMapRightClick(mapPos.x, mapPos.y));
		                      }
		                  });
	}
	
	override void orderRemove(GameObject[] objects)
	{
		if(selectionBuffer.length && selectionBuffer[0].mayBeOrdered)
		{
			gameObjects.order(gameObjects.gateway, selection, OrderRemove());
			selectionBuffer.reset();
		}
	}
	
	override void orderPlaceObject(ObjectTypeInfo type, player_id_t owner, map_pos_t pos)
	{
		assert(owner == gameObjects.gateway.id);
	
		gameObjects.order(gameObjects.gateway, selection,
		                  OrderPlaceObject(placeObjectTypeInfo.id,
		                                   mapPos.x,
		                                   mapPos.y));
	}
	
public:
	this(GameObjectManager gameObjects, MiniMap miniMap)
	{
		super(gameObjects, miniMap);
	}
}