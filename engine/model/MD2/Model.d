module engine.model.MD2.Model;

import engine.model.Instance : BaseInstance = Instance;
import engine.model.MD2.Mesh : Mesh, Instance;
import engine.model.Mesh : BaseMesh = Mesh;
import engine.model.Model : BaseModel = Model;

final class Model
	: BaseModel
{
	this(Mesh[] meshes)
	{
		meshes_ = meshes;
	}

	override
	{
		bool isAnimated()
		{
			return true;
		}
	
		Instance createInstance()
		{
			return new Instance(meshes_);
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
}
