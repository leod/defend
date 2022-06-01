#if defined(SHADOWMAPPING)
uniform mat4 lightTransform;

varying vec4 lightSpacePos;
#endif

void main(void)
{
	gl_Position = ftransform();
	gl_TexCoord[0] = gl_MultiTexCoord0;
	gl_TexCoord[1] = gl_MultiTexCoord1;

#if defined(SHADOWMAPPING)
	lightSpacePos = lightTransform * gl_Vertex;
#endif
}
