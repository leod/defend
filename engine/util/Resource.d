module engine.util.Resource;

import Path = tango.io.Path;

import engine.util.Environment : gSearchPath;

struct ResourcePath
{
	char[] index; /* the path that was searched for, e.g. models/tree/foo.png */
	char[] fullPath; /* search path + index */
}

private void function()[] dumps_;

/* FIXME: should be private, works for variables :S */
ResourcePath findResourcePathInPaths(char[] path, char[][] findPaths)
{
	char[] exceptionText = "Unable to find any of ";

	foreach (findPath; findPaths) {
		char[][] results = gSearchPath.find(findPath);

		if (results.length) {
			ResourcePath foundPath = { findPath, results[0] };
			return foundPath;
		}

		exceptionText ~= '`' ~ findPath ~ "` ";
	}

	throw new Exception(exceptionText ~ '.');
}

ResourcePath findResourcePath(char[] path)
{
	return findResourcePathInPaths(path, ["data/" ~ path, path]);
}

void dump()
{
	foreach (dump; dumps_)
	{
		dump();
	}
}

template MResource()
{
	import Path = tango.io.Path;
	import tango.text.Ascii : toLower;

	import engine.util.Log : MLogger;
	import engine.util.Resource : findResourcePathInPaths, ResourcePath, dumps_;

	mixin MLogger;

	alias typeof(this) T;

public:
	static this()
	{
		dumps_ ~= &dump;
	}

	static ResourcePath findResourcePath(char[] path)
	{
		final char[][4] findPaths = [
			"data/" ~ toLower(T.stringof.dup) ~ "s/" ~ path,
			"data/"                                  ~ path,
			          toLower(T.stringof.dup) ~ "s/" ~ path,
			                                           path
		];

		return findResourcePathInPaths(path, findPaths);
	}

	// Loads a resource, but doesn't increment its ref count
	static T get(char[] path)
	{
		if (Path.parse(path).isAbsolute) {
			throw new Exception("I will not load absolute path `" ~ path ~ "`, please give me an index.");
		}

		return get(findResourcePath(path));
	}

	static T get(ResourcePath path)
	{
		if(auto instance = path.index in instances_)
			return *instance;

		logger_.info("loading \"{}\"", path.index);

		final T instance = T.loadResource(path);

		instance.indexPath_ = path.index;
		instances_[path.index] = instance;

		return instance;
	}
	
	// Loads a resource and increments its ref count
	static T opCall(char[] path)
	{
		return acquire(get(path));
	}

	static T opCall(ResourcePath path)
	{
		return acquire(get(path));
	}

	// Increments a resource's ref count
	static T acquire(T instance)
	{
		logger_.spam("incrementing ref count of \"{}\"", instance.indexPath_);
	
		++instance.refCount_;
		
		return instance;
	}
	
	// Decrements a resource's ref count and deletes it if it's unused now
	static void release(T instance)
	{
		logger_.spam("decrementing ref count of \"{}\"", instance.indexPath_);
	
		if(--instance.refCount_ == 0)
		{
			if(!instance.indexPath_.length)
			{
				logger_.info("releasing \"{}\"", T.stringof);
			}
			else
			{
				logger_.info("releasing \"{}\"", instance.indexPath_);
	
				if(instance.indexPath_ in instances_)
					instances_.remove(instance.indexPath_);
			}

			delete instance;
		}
	}

private:
	// Print out a list of loaded resources
	static void dump()
	{
		foreach (key, val; instances_)
			logger_.warn("loaded: \"{}\" (ref count {})", key, val.refCount_);
	}

	static T[char[]] instances_;
	uint refCount_;
	char[] indexPath_; /* map index */
}
