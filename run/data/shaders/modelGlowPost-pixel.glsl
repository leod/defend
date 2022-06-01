uniform sampler2D sampler1;
uniform sampler2D sampler2;

void main(void)
{
	vec4 a = texture2D(sampler1, vec2(gl_TexCoord[0]));
	
	const float o = 0.013;
	
	vec2 bc = vec2(gl_TexCoord[0]);
	vec4 b = texture2D(sampler2, bc);
	b += texture2D(sampler2, vec2(bc.x - o, bc.y));
	b += texture2D(sampler2, vec2(bc.x + o, bc.y));
	b += texture2D(sampler2, vec2(bc.x, bc.y + o));
	b += texture2D(sampler2, vec2(bc.x + o, bc.y + o));
	b += texture2D(sampler2, vec2(bc.x - o, bc.y + o));
	b += texture2D(sampler2, vec2(bc.x - o, bc.y - o));
	b += texture2D(sampler2, vec2(bc.x + o, bc.y - o));
	b /= 8;
	
	gl_FragColor = 1 - (1 - a) * (1 - b);
}
