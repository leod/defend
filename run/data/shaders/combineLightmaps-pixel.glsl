uniform sampler2D lightmap;
uniform sampler2D fogVisible;
uniform sampler2D fogVisited;

void main(void)
{
	vec4 a = texture2D(fogVisible, vec2(gl_TexCoord[0]));
	vec4 b = texture2D(fogVisited, vec2(gl_TexCoord[0]));
	vec4 c = texture2D(lightmap, vec2(gl_TexCoord[0]));

	gl_FragColor = max(a, b * 0.55) * c;
}
