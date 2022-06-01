module engine.model.OBJ.Model;

import engine.model.Instance : BaseInstance = Instance;
import engine.model.Mesh : BaseMesh = Mesh;
import engine.model.Model : BaseModel = Model;
import engine.model.OBJ.Mesh : Mesh, Instance;

class Model
	: BaseModel
{
	this(Mesh[] meshes, BaseInstance.BoundingBox boundingBox)
	{
		meshes_ = meshes;
		boundingBox_ = boundingBox;
	}

	override
	{
		bool isAnimated()
		{
			return false;
		}
	
		Instance createInstance()
		{
			return new Instance(boundingBox_);
		}

		void freeInstance(BaseInstance instance)
		{
			delete instance;
		}

		BaseMesh[] meshes()
		{
			return meshes_;
		}
	}

private:
	Mesh[] meshes_;
	BaseInstance.BoundingBox boundingBox_;
}
