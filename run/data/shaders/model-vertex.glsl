#if defined(OBJECTS_LIGHTMAP)
uniform vec3 mapPos;
uniform vec3 mapSize;
#endif

#if defined(SHADOWMAPPING)
uniform mat4 lightTransform;
uniform mat4 modelTransform;

varying vec4 lightSpacePos;
#else
#	define LIGHT_POSITION vec4(10.0, 10.0, 0.0, 1.0)
#	define LIGHT_AMBIENT vec4(2.0, 2.0, 2.0, 1.0)
#	define LIGHT_DIFFUSE vec4(1.0, 1.0, 1.0, 1.0)
#endif

void main(void)
{
	gl_Position = ftransform();
	
	gl_TexCoord[0] = gl_MultiTexCoord0;
	
#if defined(OBJECTS_LIGHTMAP)
	gl_TexCoord[1] = vec4(mapPos.x / mapSize.x, -mapPos.z / mapSize.y, 0.0, 0.0);
#endif
	
#if defined(SHADOWMAPPING)
	lightSpacePos = lightTransform * (modelTransform * gl_Vertex);
#elif defined(NORMAL_LIGHTING)
	vec3 position = vec3(gl_ModelViewMatrix * gl_Vertex);
	vec3 light = vec3(normalize(vec3(gl_LightSource[0].position) - position));
	vec3 normal = normalize(gl_NormalMatrix * gl_Normal);
	vec3 ambient = vec3(gl_FrontMaterial.ambient) * vec3(LIGHT_AMBIENT);
	vec3 diffuse = (max(dot(normal, light), 0.0) * LIGHT_DIFFUSE).rgb;
	gl_FrontColor = vec4(diffuse + ambient, 1.0);
#endif
}
