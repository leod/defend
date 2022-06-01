module engine.model.Model;

import engine.mem.Memory : MAllocator;
import engine.util.Resource : MResource, ResourcePath;
import engine.model.Mesh : Mesh;
import engine.model.Instance : Instance;

import Path = tango.io.Path;
import tango.text.Util : locate;

// map LoadFunction to a file suffix
alias Model function(ResourcePath) LoadFunction;
LoadFunction[char[]] loadFunctions;

void registerLoader(char[] suffix, LoadFunction func)
{
	assert(!(suffix in loadFunctions));

	loadFunctions[suffix] = func;
}

abstract class Model
{
public:
	~this()
	{
		foreach(mesh; meshes)
			delete mesh;
	}

	bool isAnimated();
	Instance createInstance();
	void freeInstance(Instance);
	Mesh[] meshes();
	
private:
	mixin MAllocator;
	mixin MResource;

	static Model loadResource(ResourcePath path)
	{
		auto file = Path.parse(path.fullPath).file;
		auto suffix = file[locate(file, '.') .. $];

		assert(suffix in loadFunctions);

		return loadFunctions[suffix](path);
	}

}
