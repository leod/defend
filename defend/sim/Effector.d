module defend.sim.Effector;

import xf.xpose2.Expose;
import xf.xpose2.Serialization;

public
{
	import xf.omg.core.Fixed;
}

const uint MAX_OBJECT_TYPE_EFFECTORS = 32;
const uint MAX_OBJECT_PROPERTIES = 8;

alias uint prop_type_t;
alias fixed prop_t;

interface Effected
{
	void scalePropFactor(prop_type_t, prop_t);
}

// TODO: don't make them 'singletons' so that they can store state for each effected object, kthx. :P
interface Effector
{
	void attach(Effected);
	void detach(Effected);
	uint lifetime(); // lifetime in simulation steps; 0 means forever
	void update();
}

struct EffectorInfo
{
	uint whenApplied; // what simulation step
	Effector effector;
	
	mixin(xpose2(".*"));
	mixin xposeSerialization;
}
