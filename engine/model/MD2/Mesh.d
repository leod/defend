module engine.model.MD2.Mesh;

import xf.omg.core.LinearAlgebra : vec3ub;

import engine.model.Instance : BaseInstance = Instance;
import engine.model.Mesh : BaseMesh = Mesh;
import engine.core.TaskManager : taskManager;
import engine.rend.Texture : Texture;
import engine.rend.VertexContainer : Primitive, Usage, VertexContainer;
import engine.rend.VertexContainerFactory : createVertexContainer;
import engine.rend.Renderer : renderer;
import engine.util.Array : removeElement;
import engine.util.Singleton : MSingleton, SingletonGetter;
import engine.util.Statistics : statistics;

//------------------------------------------------------------------------
//{ Mesh
package
{
	align(1)
	{
		struct Header
		{
			int ident;
			int ver;
			int skinWidth;
			int skinHeight;
			int frameSize;
			int numSkins;
			int numVertices;
			int numTexCoords;
			int numTriangles;
			int numGLCmds;
			int numFrames;
			int offSkins;
			int offTexCoords;
			int offTriangles;
			int offFrames;
			int offGLCmds;
			int offEnd;
		}

		struct TexCoord
		{
			short s;
			short t;
		}
		
		struct Triangle
		{
			ushort[3] indices;
			ushort[3] texCoords;
		}
		
		struct Vertex
		{
			vec3ub pos;
			ubyte normalIndex;
		}
		
		struct Frame
		{
			BaseInstance.BoundingBox boundingBox;
			BaseMesh.Vertex.Position[] positions;
		}
	}
}

final class Mesh
	: BaseMesh
{
	alias VertexContainer!(BaseMesh.Vertex, Usage.DynamicDraw) Container;

	this(BaseMesh.Vertex[] vertices, Texture texture, Header header,
	     Triangle[] triangles, Frame[] frames, size_t positions)
	{
		auto container = createVertexContainer!(Container)(vertices);
		container.dirty();

		super(texture, container);
		header_ = header;
		triangles_ = triangles;
		frames_ = frames;
		positions_.length = positions;
	}

	override void render()
	{
		instance_.render(this);
	}

package:
	Header header_;
	Triangle[] triangles_;
	Frame[] frames_;
	BaseMesh.Vertex.Position[] positions_;
	Instance instance_;
}
//}
//------------------------------------------------------------------------
//{ Instance
private
{
	struct AnimationType
	{
		uint firstFrame;
		uint lastFrame;
		uint fps;
	}

	alias AnimationType Anim;

	Anim[char[]] defaultAnimations;
	
	static this()
	{
		defaultAnimations["stand"] = Anim(0, 39, 9);
		defaultAnimations["run"] = Anim(40, 45, 6);
		defaultAnimations["attack"] = Anim(46, 53, 10);
		defaultAnimations["pain_a"] = Anim(54, 57, 7);
		defaultAnimations["pain_c"] = Anim(62, 65, 7);
		defaultAnimations["jump"] = Anim(66,  71, 7);
		defaultAnimations["flip"] = Anim(72, 83, 7);
		defaultAnimations["salute"] = Anim(84, 94, 7);
		defaultAnimations["fallback"] = Anim(95, 111, 10);
		defaultAnimations["wave"] = Anim(112, 122, 7);
		defaultAnimations["point"] = Anim(123, 134, 6);
		defaultAnimations["crouch_stand"] = Anim(135, 153, 10);
		defaultAnimations["crouch_walk"] = Anim(154, 159, 7);
		defaultAnimations["crouch_attack"] = Anim(160, 168, 10);
		defaultAnimations["crouch_pain"] = Anim(196, 172, 7);
		defaultAnimations["crouch_death"] = Anim(173, 177, 5);
		defaultAnimations["death_fallback"] = Anim(178, 183, 7);
		defaultAnimations["death_fallforward"] = Anim(184, 189, 7);
		defaultAnimations["death_fallbackslow"] = Anim(190, 197, 7);
		defaultAnimations["boom"] = Anim(198, 198, 5);
	}
}

final class Instance
	: BaseInstance
{
	this(Mesh[] meshes)
	{
		meshes_ = meshes;
		// TODO: mmm
		md2Animator.states_ ~= this;
	}
		
	~this()
	{
		md2Animator.states_.removeElement(this);
	}

	void render(Mesh mesh)
	{
		auto currFrame = &mesh.frames_[currentFrame_];
		auto nextFrame = &mesh.frames_[nextFrame_];
	
		{
			auto target = mesh.positions_.ptr;
			auto currPos = currFrame.positions.ptr;
			auto nextPos = nextFrame.positions.ptr;

			version(D_InlineAsm_X86)
			version(SSE)
			{
				vec4 interp = vec4(interp_, interp_, interp_, 0);
				
				asm
				{
					movups XMM0, interp;
				}
			}
				
			version(SSEAlign)
			{
				static char[] vec(char[] name)
				{
					return "vec4* " ~ name ~ ";"
						   "{ void* ptr = alloca(vec4.sizeof + 15);" ~
						   "ptr += 0x10;" ~
						   // FIXME: unportable
						   "ptr -= cast(int)ptr & 0xf;" ~
						   name ~ " = cast(vec4*)ptr; }";
				}
				
				mixin(vec("curr"));
				mixin(vec("next"));
				mixin(vec("result"));

				assert((cast(int)curr & 0xf) == 0);
				assert((cast(int)next & 0xf) == 0);
				assert((cast(int)result & 0xf) == 0);
			}

			for(uint i = 0; i < mesh.header_.numVertices; i++)
			{
				statistics.vertices_animated++;
			
				version(SSE)
				{
					version(SSEAlign)
					{
						*curr = vec4(currPos.tuple, 0);
						*next = vec4(nextPos.tuple, 0);
					}
					else
					{
						vec4 curr = vec4(currPos.tuple, 0);
						vec4 next = vec4(nextPos.tuple, 0);
					}

					asm
					{
						movups XMM1, curr; // xmm1 = curr
						movups XMM2, next; // xmm2 = next				
						subps XMM2, XMM1; // xmm2 -= curr
						mulps XMM2, XMM0; // xmm2 *= interp
						addps XMM2, XMM1; // xmm2 += curr
						movups [result], XMM2; // result = xmm2
					}

					assert(result.ok);
						
					target.x = result.x;
					target.y = result.y;
					target.z = result.z;
				}
				else
				{
					target.x = currPos.x + interp_ *
						(nextPos.x - currPos.x);
					target.y = currPos.y + interp_ *
						(nextPos.y - currPos.y);
					target.z = currPos.z + interp_ *
						(nextPos.z - currPos.z);
				}

				++target;
				++currPos;
				++nextPos;
			}
		}

		auto target = mesh.vertices.ptr;
	
		for(uint i = 0; i < mesh.header_.numTriangles; i++)
		{
			for(uint j = 0; j < 3; j++)
			{
				target.position = mesh.positions_[
					mesh.triangles_[i].indices[j]];
				++target;
			}
		}
			
		mesh.vertices.dirty();
		mesh.vertices.synchronize();

		renderer.setTexture(0, mesh.texture);

		mesh.vertices.draw(Primitive.Triangle);
			
		//boundingBox_ = currFrame.boundingBox;
		//boundingBox_.max = currFrame.boundingBox.max + interp_ * (nextFrame.boundingBox.max - currFrame.boundingBox.max);
		//boundingBox_.min = currFrame.boundingBox.min + interp_ * (nextFrame.boundingBox.min - currFrame.boundingBox.min);
	}

	override
	{
		void set()
		{
			foreach(mesh; meshes_)
				mesh.instance_ = this;
		}

		void setAnimation(char[] name)
		{
			isAnimating_ = true;
			type_ = defaultAnimations[name];
			currentFrame_ = type_.firstFrame;
			nextFrame_ = currentFrame_ + 1;
			
			// could be precalculated
			BaseInstance.BoundingBox frameBBox;
			auto frames = meshes_[0].frames_;
			
			for(auto i = type_.firstFrame; i < type_.lastFrame; ++i)
			{
				frameBBox.addPoint(frames[i].boundingBox.min);
				frameBBox.addPoint(frames[i].boundingBox.max);
			}
			
			boundingBox_ = frameBBox;
		}
		
		void stopAnimation()
		{
			isAnimating_ = false;
		}
		
		bool newBoundingBox()
		{
			return true;
		}

		BaseInstance.BoundingBox boundingBox()
		{
			return boundingBox_;
		}
	}

private:
	Mesh[] meshes_;
	Anim type_;
	uint currentFrame_;
	uint nextFrame_;
	bool isAnimating_;
	float interp_ = 0.0f;
	BaseInstance.BoundingBox boundingBox_;
}

private
{
	class Animator
	{
		this()
		{
			taskManager.addRepeatedTask(&update, frequency_);
		}
		
		void update()
		{
			foreach(state; states_)
			{
				if(state.isAnimating_)
				{
					state.interp_ += 1 / (frequency_ / state.type_.fps);
					
					if(state.interp_ > 1.0f)
					{
						state.interp_ = 0;
						state.currentFrame_ = state.nextFrame_;
						state.nextFrame_++;
						
						if(state.nextFrame_ > state.type_.lastFrame)
							state.nextFrame_ = state.type_.firstFrame;
					}
				}
			}
		}
	
	private:
		Instance[] states_;
		const frequency_ = 50.0f;

		mixin MSingleton;
	}

	alias SingletonGetter!(Animator) md2Animator;
}
//}
