uniform sampler2D diffuseTexture;

// The model's team color
uniform vec3 color; 

void main()
{
	vec4 tex = texture2D(diffuseTexture, vec2(gl_TexCoord[0]));
	
	gl_FragColor = vec4(color * 1 - tex.a, 1);
}
