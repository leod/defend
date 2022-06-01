module engine.image.Devil;

import tango.io.device.File : File;
import tango.stdc.stringz;

import derelict.devil.il;

import engine.mem.Memory;
import engine.image.Image;

class DevilImage
{
private:
	static void checkLoaded()
	{
		static bool loaded = false;
	
		if(!loaded)
		{
			DerelictIL.load();
			ilInit();
			
			loaded = true;
		}
	}
	
public:
	static Image load(char[] file)
	{
		checkLoaded();
		
		Image result;
		auto raw = File.get(file);
		ILuint id;
		ilGenImages(1, &id);
		ilBindImage(id);
		ilLoadL(IL_TYPE_UNKNOWN, raw.ptr, raw.length);

		ImageFormat format;

		auto width = ilGetInteger(IL_IMAGE_WIDTH);
		auto height = ilGetInteger(IL_IMAGE_HEIGHT);
		uint bpp = ilGetInteger(IL_IMAGE_BITS_PER_PIXEL);

		switch(bpp)
		{
		case 32:
			ilConvertImage(IL_RGBA, IL_UNSIGNED_BYTE);
			format = ImageFormat.RGBA;
			break;
				
		case 8:
			ilConvertImage(IL_RGB, IL_UNSIGNED_BYTE);
			format = ImageFormat.RGB;
			break;
				
		default:
			ilConvertImage(IL_RGB, IL_UNSIGNED_BYTE);
			format = ImageFormat.RGB;
			bpp = 24;
			break;
		}
			
		result = new Image(width, height, format);
		result.data = (cast(ubyte*)ilGetData())[0 .. width * height * bpp / 8];
			
		ilDeleteImages(1, &id);
		
		return result;
	}
	
	static void save(Image image, char[] file)
	{
		checkLoaded();
	
		//ilEnable(IL_ORIGIN_SET);
		//ilOriginFunc(IL_ORIGIN_LOWER_LEFT);

		ILubyte bytes;
		ILenum format;
		
		switch(image.format)
		{
		case ImageFormat.A:
			bytes = 1;
			format = IL_LUMINANCE;
			break;
		
		case ImageFormat.RGB:
			bytes = 3;
			format = IL_RGB;
			break;
		
		case ImageFormat.RGBA:
			bytes = 4;
			format = IL_RGBA;
			break;

		default:
			assert(false);
		}

		ILuint id;
		
		ilGenImages(1, &id);
		ilBindImage(id);
		
		ilTexImage(image.width, image.height, 1, bytes, format,
				   IL_UNSIGNED_BYTE, image.data.ptr);

		ilSaveImage(toStringz(file));
		ilDeleteImages(1, &id);	
	}
}
