module engine.util.File;

import tango.io.device.File;

public
{
	import engine.mem.Memory;
}

const File.Style sharedFileStyle = { File.Access.Read,
                                     File.Open.Exists,
                                     File.Share.Read };

// returned memory block must be freed
ubyte[] readFile(char[] path)
{
	scope conduit = new File(path, sharedFileStyle);
	scope(exit) conduit.close();
	
	ubyte[] content;
	content.alloc(conduit.length);
	
	if(conduit.input.read(content) != content.length)
		conduit.error("unexpected eof");
		
	return content;
}

void withReadFile(T)(char[] path, void delegate(T[]) dg)
{
	auto data = readFile(path);
	scope(exit) data.free();
	
	dg(cast(T[])data);
}
