uniform sampler2D diffuseTexture;

#if defined(OBJECTS_LIGHTMAP)
uniform sampler2D lightTexture;
#endif

#if defined(SHADOWMAPPING)
#	include "shadowmap.glsl"

uniform sampler2D shadowTexture;

varying vec4 lightSpacePos;
#endif

#if !defined(NEUTRAL_OBJECT)
// The model's team color
uniform vec3 color; 
#endif

void main()
{
	vec4 tex = texture2D(diffuseTexture, vec2(gl_TexCoord[0]));
	
#if !defined(NEUTRAL_OBJECT)
	gl_FragColor = vec4(tex.rgb * tex.a + color * (1 - tex.a), 1.0);
#else
	gl_FragColor = tex;
#endif

#if defined(OBJECTS_LIGHTMAP)
	vec4 light = texture2D(lightTexture, vec2(gl_TexCoord[1]));
	gl_FragColor *= light * 2;
#endif
	
#if defined(SHADOWMAPPING)
	gl_FragColor *= shadowMap(shadowTexture, lightSpacePos);
#elif defined(NORMAL_LIGHTING)
	gl_FragColor *= gl_Color;
#endif
}
