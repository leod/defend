module engine.hybrid.OGLRenderer;

import tango.math.Math : rndint;
import tango.util.log.Trace;

import derelict.opengl.extension.ext.blend_color;
import derelict.opengl.extension.arb.multitexture;

import xf.hybrid.GuiRenderer: BaseRenderer = GuiRenderer;
import xf.hybrid.FontRenderer;
import xf.hybrid.Font;
import xf.hybrid.Texture;
import xf.hybrid.IconCache;
import xf.hybrid.Shape;
import xf.hybrid.Style;
import xf.hybrid.widgets.Label;
import xf.hybrid.WidgetConfig;
import xf.hybrid.Context;

import xf.image.Loader: ImageRequest, ImageFormat, ImageLoader = Loader;
import xf.image.DevilLoader;
import xf.image.CachedLoader;

import xf.omg.core.LinearAlgebra;

import engine.mem.Memory;
import engine.image.Image;
import engine.image.Devil;
import engine.rend.opengl.VertexContainer : unbindCurrentArray;
import engine.rend.opengl.Wrapper;
import engine.rend.Renderer : renderer;

private
{
	struct Batch {
		enum Type {
			Triangles = 0,
			Quads = 1,
			Lines = 2,
			Points = 3,
			Direct = 4
		}
		
		void resetWithoutArrays(ref Batch b) {
			auto points_ = this.points;
			auto colors_ = this.colors;
			auto texCoords_ = this.texCoords;
			*this = b;
			this.points = points_;
			this.colors = colors_;
			this.texCoords = texCoords_;
			this.points.length = 0;
			this.colors.length = 0;
			this.texCoords.length = 0;
		}
		
		Type					type;
		
		union {
			struct {
				vec2[]				points;
				vec4[]				colors;
				vec2[]				texCoords;
				Texture				texture;
				BlendingMode	blending;
				float					weight;
			}
			
			void delegate(BaseRenderer) directRenderingHandler;
		}
		
		Rect					clipRect;
	}

	class GlTexture : Texture
	{
		int id;
	}

	static const uint[] batchToGlType = [GL_TRIANGLES, GL_QUADS, GL_LINES,
		GL_POINTS];
}

class Renderer : BaseRenderer, FontRenderer, TextureMngr
{
	override void applyStyle(Object s_)
	{
		if(s_ is null)
		{
			_style = null;
			return;
		}

		auto s = cast(Style)s_;
		assert(s !is null);

		_style = s;

		preprocessStyle();
	}

	protected void preprocessStyle()
	{
		if(_style.image.available)
		{
			auto img = _style.image.value();
			assert(img !is null);

			if(img.texture is null)
			{
				vec2i bl, tr;
				ImageRequest request;
				request.imageFormat = ImageFormat.RGBA;
				assert(img.path.length > 0);
				assert(imageLoader !is null);

				imageLoader.useVfs(gui.vfs);
				auto raw = imageLoader.load(img.path, &request);

				assert(raw !is null, img.path);
				assert(1 == raw.planes.length);
				assert(ImageFormat.RGBA == raw.imageFormat);
				auto plane = raw.planes[0];
				img.size = vec2i(plane.width, plane.height);
				assert(iconCache !is null);
				img.texture = iconCache.get(img.size, bl, tr,
						img.texCoords[0], img.texCoords[1]);
				iconCache.updateTexture(img.texture, bl, img.size,
						(cast(ubyte[])plane.data).ptr);
			}
		}
	}

	override void shape(Shape shape, vec2 size)
	{
		if(cast(Rectangle)shape)
		{
			this.rect(shape.rect(size));
		/+glimmediate(GL_LINE_LOOP, {
		 glColor3f(1.f, 1.f, 1.f);
		 glVertex2f(_offset.x, _offset.y);
		 glVertex2f(_offset.x, _offset.y+size.y);
		 glVertex2f(_offset.x+size.x, _offset.y+size.y);
		 glVertex2f(_offset.x+size.x, _offset.y);
		 });+/
		}
	}

	override void point(vec2 p, float size = 1.f)
	{
		_weight = size;
		//flushStyleSettings();

		auto b = prepareBatch(Batch.Type.Points);
		b.points ~= p + _offset;
		b.colors ~= _color;
		b.texCoords ~= _texCoord;
	}

	override void line(vec2 p0, vec2 p1, float width = 1.f)
	{
		_weight = width;
		//flushStyleSettings();

		auto b = prepareBatch(Batch.Type.Lines);
		b.points ~= p0 + _offset + lineOffset;
		b.colors ~= _color;
		b.texCoords ~= _texCoord;

		b.points ~= p1 + _offset + lineOffset;
		b.colors ~= _color;
		b.texCoords ~= _texCoord;
	}

	override void rect(Rect r)
	{
		//flushStyleSettings();

		vec2[4] p = void;
		p[0] = vec2(r.min.x, r.min.y) + _offset;
		p[1] = vec2(r.min.x, r.max.y) + _offset;
		p[2] = vec2(r.max.x, r.max.y) + _offset;
		p[3] = vec2(r.max.x, r.min.y) + _offset;

		if(_style is null)
		{
			auto b = prepareBatch(Batch.Type.Triangles);

			void add(int i)
			{
				b.points ~= p[i];
				b.colors ~= _color;
				b.texCoords ~= _texCoord;
			}

			add(0);
			add(1);
			add(2);
			add(0);
			add(2);
			add(3);

			return;
		}

		if(_style.background.available)
		{
			auto background = _style.background.value();
			assert(background !is null);

			vec4[4] c = void;
			vec2[4] tc = _texCoord;

			switch(background.type)
			{
				case BackgroundStyle.Type.Gradient:
					{
						auto g = &background.Gradient;
						switch(g.type)
						{
							case GradientStyle.Type.Horizontal:
								{
									c[0] = c[1] = g.color0;
									c[2] = c[3] = g.color1;
								}
								break;

							case GradientStyle.Type.Vertical:
								{
									c[0] = c[3] = g.color0;
									c[1] = c[2] = g.color1;
								}
								break;
						}
					}
					break;

				case BackgroundStyle.Type.Solid:
					{
						c[] = background.Solid;
					}
					break;

				default:
					assert(false, "TODO");
			}

			if(_style.image.available)
			{
				auto img = _style.image.value();
				assert(img !is null);

				_texture = img.texture;

				vec2 tbl = img.texCoords[0];
				vec2 ttr = img.texCoords[1];

				tc[0] = vec2(tbl.x, ttr.y);
				tc[1] = vec2(tbl.x, tbl.y);
				tc[2] = vec2(ttr.x, tbl.y);
				tc[3] = vec2(ttr.x, ttr.y);
			}

			auto b = prepareBatch(Batch.Type.Triangles);

			if(!_style.image.available ||
				ushort.max == _style.image.value.hlines[0] ||
				ushort.max == _style.image.value.vlines[0])
			{
				void add2(int i)
				{
					b.points ~= p[i];
					b.colors ~= c[i];
					b.texCoords ~= tc[i];
				}

				add2(0);
				add2(1);
				add2(2);
				add2(0);
				add2(2);
				add2(3);
			}
			else
			{
				void addInterp(float u, float v, float tu, float tv)
				{
					b.points ~= (p[0] * (1.f - v) + p[1] * v) *
						(1.f - u) + (p[2] * v + p[3] * (1.f - v)) * u;
					b.colors ~= (c[0] * (1.f - v) + c[1] * v) *
						(1.f - u) + (c[2] * v + c[3] * (1.f - v)) * u;
					b.texCoords ~= (tc[0] * (1.f - tv) + tc[1] * tv) *
						(1.f - tu) + (tc[2] * tv + tc[3] * (1.f - tv)) * tu;
				}

				auto img = _style.image.value();
				assert(img !is null);

				float lineU[4];
				float lineV[4];

				float lineTU[4];
				float lineTV[4];

				lineTU[0] = lineTV[0] = lineU[0] = lineV[0] = 0.f;
				lineTU[3] = lineTV[3] = lineU[3] = lineV[3] = 1.f;

				lineTU[1] = cast(float)img.hlines[0] / img.size.x;
				lineTU[2] = cast(float)img.hlines[1] / img.size.x;
				lineTV[1] = cast(float)img.vlines[0] / img.size.y;
				lineTV[2] = cast(float)img.vlines[1] / img.size.y;

				lineU[1] = cast(float)img.hlines[0] / r.width;
				lineU[2] = 1.f - lineU[1];

				lineV[1] = cast(float)img.vlines[0] / r.height;
				lineV[2] = 1.f - lineV[1];

				void addIdxPt(int xi, int yi)
				{
					addInterp(lineU[xi], lineV[yi], lineTU[xi], lineTV[yi]);
				}

				void addQuad(int xi, int yi)
				{
					addIdxPt(xi, yi);
					addIdxPt(xi, yi + 1);
					addIdxPt(xi + 1, yi + 1);
					addIdxPt(xi, yi);
					addIdxPt(xi + 1, yi + 1);
					addIdxPt(xi + 1, yi);
				}

				for(int y = 0; y < 3; ++y)
				{
					for(int x = 0; x < 3; ++x)
					{
						addQuad(x, y);
					}
				}
			}
		}

		if(_style.border.available)
		{
			vec2[4] bp = void;
			bp[0] = vec2(r.min.x, r.min.y) + _offset;
			bp[1] = vec2(r.min.x, r.max.y - 1) + _offset;
			bp[2] = vec2(r.max.x - 1, r.max.y - 1) + _offset;
			bp[3] = vec2(r.max.x - 1, r.min.y) + _offset;

			auto border = _style.border.value();

			_weight = border.width;
			disableTexturing();
			auto b = prepareBatch(Batch.Type.Lines);

			void add3(int i)
			{
				b.points ~= bp[i] + lineOffset;
				b.colors ~= border.color;
				b.texCoords ~= _texCoord;
			}

			add3(0);
			add3(1);
			add3(1);
			add3(2);
			add3(2);
			add3(3);
			add3(3);
			add3(0);
		}
	}

	override void flushStyleSettings()
	{
		disableTexturing();
		if(_style !is null && _style.color.available)
		{
			color = *_style.color.value;
		}
		else
		{
			color = vec4.one;
		}
		blendingMode = BlendingMode.None;
	}

	override bool special(Object obj)
	{
		return false;
	}

	override void direct(void delegate(BaseRenderer) dg)
	{
		assert(dg !is null);
		auto b = prepareBatch(Batch.Type.Direct);
		b.directRenderingHandler = dg;
	}

	override void flush()
	{
		unbindCurrentArray();
		
		renderer.setTexture(0, null);
		
		if(ARBMultitexture.isEnabled)
		{
			glClientActiveTextureARB(GL_TEXTURE0_ARB);
			glActiveTextureARB(GL_TEXTURE0_ARB);
		}
		
		glDisable(GL_TEXTURE_2D);
		
		glMatrixMode(GL_PROJECTION);
		glPushMatrix();

		scope(exit)
		{
			glMatrixMode(GL_PROJECTION);
			glPopMatrix();
		}

		_glClipRect = Rect(vec2.zero, vec2.zero);

		for (int i = 0; i < numBatches; ++i)
		{
			auto b = &batches[i];
		
			if(Batch.Type.Direct == b.type)
			{
				handleDirectRendering(*b);
				continue;
			}

			if(!setupClipping(b.clipRect))
			{
				continue;
			}

			if(b.texture !is null)
			{
				glEnable(GL_TEXTURE_2D);
				glBindTexture(GL_TEXTURE_2D, (cast(GlTexture)b.texture).id);
			}
			else
			{
				glDisable(GL_TEXTURE_2D);
			}

			if(BlendingMode.Subpixel == b.blending)
			{
				glBlendFunc(GL_ZERO, GL_ONE_MINUS_SRC_COLOR);
				glEnable(GL_BLEND);

				glBegin(batchToGlType[b.type]);

				foreach(k, p; b.points)
				{
					float a = b.colors[k].a;
					glColor3f(a, a, a);
					glTexCoord2fv(&b.texCoords[k].x);
					glVertex2fv(&b.points[k].x);
				}

				glEnd();
			}

			switch(b.blending)
			{
				case BlendingMode.Alpha:
					{
						glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
						glEnable(GL_BLEND);
					}
					break;

				case BlendingMode.Subpixel:
					{
						glBlendFunc(GL_SRC_ALPHA, GL_ONE);
					}
					break;

				case BlendingMode.None:
					{
						glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
						glEnable(GL_BLEND);
					}
					break;
			}

			glTexCoordPointer(2, GL_FLOAT, 0, b.texCoords.ptr);
			glVertexPointer(2, GL_FLOAT, 0, b.points.ptr);
			glColorPointer(4, GL_FLOAT, 0, b.colors.ptr);

			glEnableClientState(GL_TEXTURE_COORD_ARRAY);
			glEnableClientState(GL_VERTEX_ARRAY);
			glEnableClientState(GL_COLOR_ARRAY);

			switch(b.type)
			{
				case Batch.Type.Lines:
					{
						glLineWidth(b.weight);
					}
					break;

				case Batch.Type.Points:
					{
						glPointSize(b.weight);
					}
					break;

				default:
					break;
			}

			glDrawArrays(batchToGlType[b.type], 0, b.points.length);
		}

		glDisable(GL_SCISSOR_TEST);
		glDisable(GL_BLEND);
		glDisable(GL_TEXTURE_2D);
		renderer.setTexture(0, null);

		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

		glViewport(0, 0, viewportSize.tuple);

		glDisableClientState(GL_TEXTURE_COORD_ARRAY);
		glDisableClientState(GL_VERTEX_ARRAY);
		glDisableClientState(GL_COLOR_ARRAY);

		glColor4f(1, 1, 1, 1);
		
		numBatches = 0;
	}

	protected void handleDirectRendering(Batch b)
	{
		if(!setupClipping(b.clipRect))
		{
			return;
		}

		assert(Batch.Type.Direct == b.type);
		assert(b.directRenderingHandler !is null);
		b.directRenderingHandler(this);
	}

	void disableTexturing()
	{
		_texture = null;
	}

	Batch* addBatch(Batch b = Batch.init) {
		Batch* res;
		if (batches.length > numBatches) {
			res = &batches[numBatches++];
			res.resetWithoutArrays(b);
		} else {
			batches ~= b;
			res = &batches[$-1];
			++numBatches;
		}		
		return res;
	}
	
	
	Batch* prepareBatch(Batch.Type type) {
		version (StubHybridRenderer) assert (false);		// should not be called in this version
		if (0 == numBatches || Batch.Type.Direct == type) {
			addBatch(Batch(type));
			//batches ~= Batch(type);
		} else {
			auto b = &batches[numBatches-1];
			if (	b.type == type &&
					b.texture is _texture &&
					b.blending == _blending &&
					b.weight == _weight &&
					b.clipRect == _clipRect
			) {
				return b;
			} else {
				addBatch(Batch(type));
				//batches ~= Batch(type);
			}
		}
		
		auto b = &batches[numBatches-1];
		
		if (Batch.Type.Direct != type) {
			b.texture = _texture;
			b.blending = _blending;
			b.weight = _weight;
		}
		
		b.clipRect = _clipRect;
		
		return b;
	}

	// -------------------------------------------------------------------
	// TextureMngr

	Texture createTexture(vec2i size, vec4 defColor)
	{
		Trace.formatln("Creating a texture of size: {}", size);

		ubyte[] data;
		data.alloc(size.x * size.y * 4);

		uint bitspp = 32;
		uint bytespp = bitspp / 8;

		ubyte f2ub(float f)
		{
			if(f < 0)
				return 0;
			if(f > 1)
				return 255;
			return cast(ubyte)rndint(f * 255);
		}

		for(uint i = 0; i < size.x; ++i)
		{
			for(uint j = 0; j < size.y; ++j)
			{
				for(uint c = 0; c < bytespp; ++c)
				{
					data[(size.x * j + i) * bytespp + c] = f2ub(
							defColor.cell[c]);
				}
			}
		}

		GlTexture tex = new GlTexture;
		glGenTextures(1, cast(uint*)&tex.id);

		glEnable(GL_TEXTURE_2D);
		glBindTexture(GL_TEXTURE_2D, tex.id);

		const uint level = 0;
		const uint border = 0;
		GLenum format = GL_RGBA;

		glTexImage2D(GL_TEXTURE_2D, level, bytespp, size.x, size.y,
				border, format, GL_UNSIGNED_BYTE, data.ptr);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

		glDisable(GL_TEXTURE_2D);
		data.free();

		Trace.formatln("Texture created");

		return tex;
	}

	void updateTexture(Texture tex_, vec2i origin, vec2i size, ubyte* data)
	{
		assert(size.x > 0 && size.y > 0);

		GlTexture tex = cast(GlTexture)(tex_);
		assert(tex !is null);

		glEnable(GL_TEXTURE_2D);
		glBindTexture(GL_TEXTURE_2D, tex.id);

		const int level = 0;
		glTexSubImage2D(GL_TEXTURE_2D, level, origin.x, origin.y, size.x,
				size.y, GL_RGBA, GL_UNSIGNED_BYTE, data);

		glDisable(GL_TEXTURE_2D);
	}

	// -------------------------------------------------------------------
	// FontRenderer

	void enableTexturing(Texture tex)
	{
		_texture = tex;
	}

	void blendingMode(BlendingMode mode)
	{
		_blending = mode;
	}

	void setTC(vec2 tc)
	{
		_texCoord = tc;
	}

	void color(vec4 col)
	{
		_color = col;
	}

	void absoluteQuadPoint(vec2 p)
	{
		auto b = prepareBatch(Batch.Type.Quads);
		b.points ~= p;
		b.colors ~= _color;
		b.texCoords ~= _texCoord;
	}

	IconCache iconCache()
	{
		return _iconCache;
	}

	// -------------------------------------------------------------------

	private bool setupClipping(Rect r, bool setupProjection = true)
	{
		if(_glClipRect == r)
		{
			return _clipRectOk;
		}
		else
		{
			_glClipRect = r;
		}

		Rect c = _glClipRect;

		if(c == Rect.init)
		{
			c.min = vec2(0, 0);
			c.max = vec2(viewportSize.x, viewportSize.y);
		}
		else
		{
			c.min = vec2.from(vec2i.from(c.min));
			c.max = vec2.from(vec2i.from(c.max));
		}

		c = Rect.intersection(c, Rect(vec2.zero, vec2.from(viewportSize)));

		int w = cast(int)(c.max.x - c.min.x);
		int h = cast(int)(c.max.y - c.min.y);

		if(w <= 0 || h <= 0)
		{
			_clipRectOk = false;
			return false;
		}
		else
		{
			_clipRectOk = true;
		}

		glViewport(cast(int)c.min.x,
				cast(int)(viewportSize.y - c.min.y - h), w, h);
		glScissor(cast(int)c.min.x,
				cast(int)(viewportSize.y - c.min.y - h), w, h);
		glEnable(GL_SCISSOR_TEST);

		if(setupProjection)
		{
			glMatrixMode(GL_PROJECTION);
			glLoadIdentity();
			gluOrtho2D(c.min.x, c.max.x, c.max.y, c.min.y);
			glMatrixMode(GL_MODELVIEW);
			glLoadIdentity();
		}

		return true;
	}

	this()
	{
		_iconCache = new IconCache;
		_iconCache.texMngr = this;
		FontMngr.fontRenderer = this;
		imageLoader = new CachedLoader(new DevilLoader);
	}

	public
	{
		vec2i viewportSize;
	}

	protected
	{
		Batch[] batches;
		uint numBatches;
		ImageLoader imageLoader;
	}

	private
	{
		IconCache _iconCache;

		vec4 _color = vec4.one;
		vec2 _texCoord = vec2.zero;
		Texture _texture;
		BlendingMode _blending;
		float _weight = 1.0;

		Style _style;

		Rect _glClipRect;
		bool _clipRectOk = true;

		static vec2 lineOffset = {x: .5f, y: .5f};
	}
}
