uniform sampler2D alphaMap;
uniform sampler2D texture1;
uniform sampler2D texture2;
uniform sampler2D texture3;
uniform sampler2D lightMap;

#if defined(SHADOWMAPPING)
#	include "shadowmap.glsl"

uniform sampler2D shadowTexture;

varying vec4 lightSpacePos;
#endif

void main(void)
{
	vec2 coord0 = vec2(gl_TexCoord[0]);
	vec2 coord1 = vec2(gl_TexCoord[1]);
	
	vec4 a = texture2D(alphaMap, coord0);
	vec4 l = texture2D(lightMap, coord0);
	
	vec4 c1 = texture2D(texture1, coord1);
	vec4 c2 = texture2D(texture2, coord1);
	vec4 c3 = texture2D(texture3, coord1);
	
	float inverse = 1.0f / (a.r + a.g + a.b);
	c1 *= a.r * inverse;
	c2 *= a.g * inverse;
	c3 *= a.b * inverse;

	gl_FragColor = (c1 + c2 + c3) * (l * 2);
	
#if defined(SHADOWMAPPING)
	gl_FragColor *= shadowMap(shadowTexture, lightSpacePos);
#endif
}
