module engine.model.Instance;

import engine.math.BoundingBox : BoundingBox;
import engine.model.Mesh : Mesh;
import engine.mem.Memory : MAllocator;

abstract class Instance
{
	alias .BoundingBox!(float) BoundingBox;

	//void render(Mesh);
	void set();
	bool newBoundingBox();
	void setAnimation(char[] animationName);
	void stopAnimation();
	BoundingBox boundingBox();

private:
	mixin MAllocator;
}
