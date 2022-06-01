module defend.sim.IHud;

import defend.sim.Types;

interface IHud
{
	/* called from the ObjectTypeInfo.doHud callbacks, tells the
	   hud to allow the user to place an object */
	void startPlaceObject(object_type_t type);
}
