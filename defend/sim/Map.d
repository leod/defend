module defend.sim.Map;

import tango.math.Math : abs;
import tango.stdc.string : memset;

import engine.math.Vector;
import engine.math.Rectangle;
import engine.mem.ArrayPool;
import engine.util.Array;
import engine.mem.Memory;
import engine.mem.MemoryPool;
import engine.util.Profiler;
import engine.util.Log : MLogger;
import engine.util.Swap;

import defend.sim.Types;
import defend.sim.Heightmap;
import defend.terrain.Ranges; // tbr

struct MapTile
{
	size_t cost;
	bool walkable = true;
	Object mapObject;
	bool free() { return walkable && !mapObject; }
}

final class Map
{
	mixin MLogger;

	this(Heightmap heightmap)
	{
		heightmap_ = heightmap;
		size_ = heightmap.size;
		
		tiles.alloc(size.x * size.y);
		
		calcTileCosts();
		
		pathfinder = new Pathfinder(tiles, size);
	}

	~this()
	{
		tiles.free();
	}

	map_pos_t size()
	{
		return size_;
	}
	
	Heightmap heightmap()
	{
		return heightmap_;
	}
	
	MapTile* opIndex(map_index_t x, map_index_t y)
	{
		return &tiles[y * size_.x + x];
	}
	
	MapTile* opIndex(map_pos_t p)
	{
		return this[p.x, p.y];
	}

	map_pos_t[] getPath(map_pos_t start, map_pos_t goal, map_pos_t[] buffer,
		bool considerObjects = true, Object unit = null)
	{
		logger_.spam("searching path from [{}|{}] to [{}|{}]", start.x, start.y, goal.x, goal.y);
	
		return pathfinder.getPath(start, goal, buffer, considerObjects, unit);
	}

	map_pos_t searchFreeTile(map_pos_t to, map_pos_t from)
	in
	{
		assert(isValidPos(to.tuple));
		assert(isValidPos(from.tuple));
	}
	body
	{
		//scope benchmark = new Benchmark("map.searchFreeTile");
		
		auto tile = this[to];

		if(tile.free)
			return to;

		const radius = 4;
		map_pos_t[(radius + 1) * 4] buffer;
		
		for(int i = 0; i < radius; ++i)
		{
			size_t bufferIndex;
			
			void addIfValid(int x, int y)
			{
				if(isValidPos(x, y) && this[x, y].free)
					buffer[bufferIndex++] = map_pos_t(x, y);
			}
			
			for(int x = to.x - i; x <= to.x + i; ++x)
			{
				addIfValid(x, to.y - i);
				addIfValid(x, to.y + i);
			}
			
			for(int y = to.y - i; y <= to.y + i; ++y)
			{
				addIfValid(to.x - i, y);
				addIfValid(to.x + i, y);
			}
			
			float minDist = float.max; // TODO: remove floats
			map_pos_t bestPos = from;
			
			foreach(pos; buffer[0 .. bufferIndex])
			{
				float dist = pos.distance(to);
				
				if(dist < minDist)
				{
					minDist = dist;
					bestPos = pos;
				}
			}
			
			if(bestPos != from)
				return bestPos;
		}
		
		return from;
	}

private:
	Pathfinder pathfinder;
	Heightmap heightmap_;
	map_pos_t size_;
	MapTile[] tiles;

	bool isValidPos(int x, int y)
	{
		return x >= 0 && y >= 0 && x < size_.x && y < size_.y;
	}
	
	void calcTileCosts()
	{
		logger_.info("calculating tile costs");
	
		for(map_index_t x = 0; x < size_.x; ++x)
		{
			for(map_index_t y = 0; y < size.y; ++y)
			{
				size_t cost;
				size_t number;
			
				for(int i = -1; i <= 1; ++i)
				{
					for(int j = -1; j <= 1; ++j)
					{
						if(!isValidPos(x + i, y + j))
							continue;
						
						auto type = 1;
						auto h = heightmap_[x + i, y + j];
						
						for(int k = 0; k < terrainMinRange.length; ++k)
						{
							if(h >= terrainMinRange[k] && h <= terrainMaxRange[k])
								type = (k + 1);
						}
						
						cost += type;
						++number;
					}
				}
				
				auto tile = this[x, y];
				tile.cost = cost / number;

				// TODO: set tile.walkable based on its cost
			}
		}
	}
}

private
{
	class Node
	{
		mixin MMemoryPool!(Node, PoolFlags.Nothing);
	
		size_t f, g, h;
		map_pos_t pos;
		size_t numChildren;
		Node parent;
		Node next; // open/closed list
		Node[8] children;
	}

	final class Pathfinder
	{
		mixin MLogger;

		this(MapTile[] tiles, map_pos_t size)
		{
			this.tiles = tiles;
			this.size = size;
			
			nodePool.create(3000);
			
			flags.alloc(size.x * size.y);
			table.alloc(size.x * size.y);
			binaryHeap.alloc(size.x * size.y + 1);
			stack.alloc(64);
		}

		~this()
		{
			clearNodes();
		
			nodePool.release();
			flags.free();
			table.free();
			binaryHeap.free();
			stack.free();
		}
		
		final map_pos_t[] getPath(map_pos_t start, map_pos_t goal, map_pos_t[] buffer,
			bool considerObjects = true, Object unit = null)
		{
			//scope benchmark = new Benchmark("map.pathfinder.getPath");
		
			clearNodes();
			
			this.goal = goal;
			this.considerObjects = considerObjects;
			this.unit = unit;
			
			if(dirtyFlags.left != int.max && dirtyFlags.top != int.max &&
				dirtyFlags.right != int.min && dirtyFlags.bottom != int.min)
			{
				auto begin = dirtyFlags.top * size.x + dirtyFlags.left;
				auto end = dirtyFlags.bottom * size.x + dirtyFlags.right + 1;
			
				flags[begin .. end] = StatusFlag.Clear;
				table[begin .. end] = null;
			}

			//foreach(x; flags) assert(x == StatusFlag.Clear);
			//foreach(x; table) assert(x is null);
			
			dirtyFlags = Rect(int.max, int.max, int.min, int.min);

			{
				auto node = nodePool.allocate();
				
				node.pos = start;
				node.h = node.f = h(start, goal);
				node.numChildren = 0;
				node.next = node.parent = null;

				{
					addToOpen(node);
				}
				
				//return null;
			}
			
			size_t cycles;
			//scope(exit) logger.spam("cycles needed: {}", cycles);
			
			while(true)
			{
				++cycles;
			
				auto best = getBest();
			
				if(!best)
					return null;
					
				if(best.pos == goal)
				{
					size_t num;
					auto current = best;
					
					do
					{
						buffer[num++] = current.pos;
						current = current.parent;
					}
					while(current.pos != start);
					
					buffer = buffer[0 .. num];
					buffer.reverse;

					return buffer;
				}
				
				createChildren(best);
			}
		
			return null;
		}		
	
	private:
		Node.MemoryPool nodePool;
	
		MapTile[] tiles;
		map_pos_t size;
		
		// current parameters to getPath
		map_pos_t goal;
		bool considerObjects;
		Object unit;
		
		// node lists
		Node open;
		Node closed;
		
		// status flags for faster lookup
		enum StatusFlag : ubyte
		{
			Clear,
			Open,
			Closed
		}
		
		StatusFlag[] flags;
		Rect dirtyFlags;
		
		// node table for faster lookup
		Node[] table;
		
		// binary heap
		Node[] binaryHeap;
		size_t numOpen;
		
		// stack for updateParents
		Node[] stack;
		size_t stackPointer;

		final void setFlag(map_pos_t pos, StatusFlag flag)
		{
			if(pos.x < dirtyFlags.left) dirtyFlags.left = pos.x;
			if(pos.y < dirtyFlags.top) dirtyFlags.top = pos.y;
			if(pos.x > dirtyFlags.right) dirtyFlags.right = pos.x;
			if(pos.y > dirtyFlags.bottom) dirtyFlags.bottom = pos.y;

			flags[pos.y * size.x + pos.x] = flag;
		}
		
		final StatusFlag getFlag(map_pos_t pos)
		{
			return flags[pos.y * size.x + pos.x];
		}

		final size_t h(map_pos_t a, map_pos_t b)
		{
			return (abs(cast(int)a.x - cast(int)b.x) +
				abs(cast(int)a.y - cast(int)b.y));
		}

		final void clearNodes()
		{
			foreach(node; binaryHeap[1 .. numOpen + 1])
				nodePool.free(node);
			
			numOpen = 0;
			
			while(closed)
			{
				auto temp = closed.next;
				nodePool.free(closed);
				closed = temp;
			}
		}

		final Node getBest()
		{
			if(numOpen == 0)
				return null;
		
			auto result = binaryHeap[1];
			
			auto saveClosed = closed;
			closed = result;
			closed.next = saveClosed;
			
			assert(getFlag(result.pos) == StatusFlag.Open);
			setFlag(result.pos, StatusFlag.Closed);
			
			binaryHeap[1] = binaryHeap[numOpen];
			--numOpen;
			
			auto current = 1;
			
			while(true)
			{
				auto newIndex = current;
			
				auto firstChild = 2 * current;
				auto secondChild = firstChild + 1;
				
				if(firstChild <= numOpen)
				{
					if(binaryHeap[current].f > binaryHeap[firstChild].f)
						newIndex = firstChild;
						
					if(secondChild <= numOpen)
					{
						if(binaryHeap[newIndex].f > binaryHeap[secondChild].f)
							newIndex = secondChild;
					}
				}
				
				if(newIndex != current)
				{
					swap(binaryHeap[current], binaryHeap[newIndex]);
					current = newIndex;
				}
				else
					break;
			}
			
			return result;
		}
		
		final void createChildren(Node node)
		{		
			size_t k;
		    
			for(int i = -1; i <= 1; ++i)
			{
				for(int j = -1; j <= 1; ++j)
				{
					if(i == 0 && j == 0)
						continue;
						
					auto x = i + node.pos.x;
					auto y = j + node.pos.y;
					
					if(x < 0 || y < 0 || x >= size.x || y >= size.x)
						continue;
					
					auto tile = tiles[y * size.x + x];
					
					if(!tile.walkable)
						continue;
					
					if(considerObjects && tile.mapObject)
						continue;
					
					linkChild(node, x, y);
				}
			}
		}
		
		final void linkChild(Node node, map_index_t x, map_index_t y)
		{
			auto g = node.g + tiles[y * size.x + x].cost;

			auto flag = getFlag(map_pos_t(x, y));
			
			if(flag == StatusFlag.Open)
			{
				auto check = checkList(open, x, y);
				assert(check !is null);
				
				node.children[node.numChildren++] = check;
				
				if(g < check.g)
				{
					check.parent = node;
					check.g = g;
					check.f = g + check.h;
					
					// HACK: shouldn't 'check' be moved in the binary tree after its f changes?
				}
			}
			else if(flag == StatusFlag.Closed)
			{
				auto check = checkList(closed, x, y);
				assert(check !is null);
			
				node.children[node.numChildren++] = check;
				
				if(g < check.g)
				{
					check.parent = node;
					check.g = g;
					check.f = g + check.h;
					
					// HACK: shouldn't 'check' be moved in the binary tree after its f changes?
					
					updateParents(check);
				}
			}
			else
			{
				auto pos = map_pos_t(x, y);
			
				auto newNode = nodePool.allocate();
				newNode.parent = node;
				newNode.numChildren = 0;
				newNode.next = null;
				newNode.pos = pos;
				newNode.g = g;
				newNode.h = h(pos, goal);
				newNode.f = newNode.g + newNode.h;

				addToOpen(newNode);
				
				node.children[node.numChildren++] = newNode;
			}
		}
		
		final Node checkList(Node node, map_index_t x, map_index_t y)
		{
			return table[y * size.x + x];
		}
		
		final void binaryMoveUp(size_t start)
		{
			auto f = binaryHeap[start].f;
			auto current = start;
			
			while(current != 1)
			{
				auto parent = current / 2;
				
				if(binaryHeap[parent].f > f)
				{
					swap(binaryHeap[parent], binaryHeap[current]);
					current = parent;
				}
				else
					break;
			}
		}
		
		final void addToOpen(Node addNode)
		{
			table[addNode.pos.y * size.x + addNode.pos.x] = addNode;
			setFlag(addNode.pos, StatusFlag.Open);
			
			numOpen++;
			binaryHeap[numOpen] = addNode;
			
			binaryMoveUp(numOpen);
		}
		
		final void updateParents(Node node)
		{
			assert(stackPointer == 0);
		
			for(size_t i = 0; i < node.numChildren; ++i)
			{
				auto child = node.children[i];
				
				if(node.g + 1 < child.g)
				{
					child.g = node.g + 1;
					child.f = child.g + child.h;
					child.parent = node;
					
					push(child);
				}
			}
			
			Node parent;
			
			while(stackPointer > 0)
			{
				parent = pop();
				
				for(size_t i = 0; i < parent.numChildren; ++i)
				{
					auto child = parent.children[i];
					
					if(parent.g + 1 < child.g)
					{
						auto pos = child.pos;
						
						child.g = parent.g +
							tiles[pos.y * size.x + pos.x].cost;
						child.f = child.g + child.h;
						child.parent = parent;
						
						push(child);
					}
				}
			}
		}
		
		final void push(Node node)
		{
			if(stackPointer == stack.length)
				stack.realloc(stack.length + 64);
			
			stack[stackPointer++] = node;
		}
		
		final Node pop()
		{
			assert(stackPointer > 0);
			return stack[--stackPointer];
		}
	}
}
