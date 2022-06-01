module engine.sound.openal.Buffer;

import derelict.openal.al;

import engine.sound.Buffer : Buffer;
import engine.sound.Data : Data;

package class OALBuffer : Buffer
{
package:
	uint id;

public:
	this(Data data)
	{
		alGenBuffers(1, &id);
		
		// TODO: multiple buffers (streaming)
		alBufferData(id, AL_FORMAT_STEREO16, data.data(0, data.size).ptr,
		             data.size, data.frequency);
	}
}
