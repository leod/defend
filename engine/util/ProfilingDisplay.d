module engine.util.ProfilingDisplay;

import tango.text.convert.Layout;

import xf.hybrid.Font;

import engine.core.TaskManager;
import engine.math.Vector;
import engine.math.Misc;
import engine.mem.Memory;
import engine.util.Wrapper;
import engine.util.Profiler;
import engine.util.FPS;
import engine.rend.Renderer;

private struct Node
{
	Node* child = null;
	Node* sibling = null;
	
	char[256] textBuffer;
	char[] text; // slice
	
	float timeFrac;
	ulong calls;
	ulong time;
}

// From deadlock

class ProfilingDisplay
{
private:
	Font font;
	Layout!(char) layout;

	Node root;
	Node[] nodes;

public:
	mixin MAllocator;

	this()
	{
		font = Font("verdana.ttf", 13);
		layout = new Layout!(char);
		
		taskManager.addRepeatedTask(&update, 1);
	}

	~this()
	{
		layout = null;
		nodes.free();
	}

	void update()
	{
		if(nodes.length < profilingData.length)
			nodes.realloc(profilingData.length);
		
		root = Node.init;
		root.text = "root";
		
		foreach(ref node; nodes)
			node = Node.init;

		ulong totalTime = 0;
		foreach(index, data; profilingData)
		{
			if(data.calls == 0)
				continue;
			
			if(data.parent == -1)
				totalTime += data.time;
		}
	
		foreach_reverse(index, data; profilingData)
		{
			if(data.calls == 0)
				continue;
				
			Node* parent;
			Node* node = &nodes[index];
			
			if(data.parent == -1)
				parent = &root;
			else
				parent = &nodes[data.parent];
			
			node.sibling = parent.child;
			parent.child = node;
			
			node.timeFrac = cast(float)(cast(real)data.time / totalTime);
			node.calls = data.calls;
			node.time = data.time;
		}
		
		float subChildTime(Node* node)
		{
			float sum = 0.0;
			
			for(; node !is null; node = node.sibling)
			{
				float cfrac = subChildTime(node.child);
				sum += node.timeFrac;
				
				if(node !is &root)
					node.timeFrac -= cfrac;
			}
			
			return sum;
		}

		//subChildTime(&root);
		
		foreach(index, data; profilingData)
		{
			Node* node = &nodes[index];
			
			node.text = layout.sprint(node.textBuffer,
				"{}: {} calls; {} calls/frame; {} ms; {} ms/call; {}%",
				data.name,
				data.calls,
				data.calls / cast(float)FPSCounter.get(),
				data.time * 0.001,
				(data.time * 0.001) / data.calls,
				node.timeFrac * 100);
		}

		resetProfilingData();
	}
	
	void render()
	{
		const uint indent = 30;
		static vec3[] colorRamp = [{x:1, y:1, z:1},
			{x:1, y:0.6, z:0.4},
			{x:1, y:0.4, z:0.3},
			{x:1, y:0, z:0}];
		
		uint offTop = 30;

		void recursion(Node* node, int offLeft)
		{
			for(; node !is null; node = node.sibling)
			{
				if(node !is &root)
				{
					vec3 color;
					
					catmullRomInterp(node.timeFrac * 3.f - .5f,
						colorRamp[0],
						colorRamp[1],
						colorRamp[2],
						colorRamp[3],
						color);
					
					FontMngr.fontRenderer.color = vec4(color.tuple, 1);
					font.print(vec2i(offLeft, offTop), node.text);
				}
				
				offTop += font.lineSkip;
				recursion(node.child, offLeft + indent);
			}
		}
		
		recursion(&root, -10);
	}
}
