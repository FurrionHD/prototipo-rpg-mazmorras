// LA SOMBRA DEL SUELO (16/11/2026, SombraSuelo, memoria sombras-fuera-del-sprite).
// Pixel art con TRES TONOS FIJOS (nada de degradado): la mancha de contacto bajo los pies y, por cada luz que le llega,
// la MISMA mancha estirada hacia el lado contrario a esa luz (su eleccion 16/11: "mancha estirada"; la silueta del dibujo
// salia una raya con la luz de lado). Donde se cruzan dos sombras NO se suman: cada pixel se queda con el tono mas
// oscuro de las que le caen (por eso va todo en un shader y no como dibujos sueltos, que se sumarian).
// Las coordenadas son las del nodo (pixeles de la rejilla del dibujo) y se redondean al pixel: sale en pixel art.
shader_type canvas_item;

const int MAX_LUCES = 8;

// La mancha de contacto: radios en x e y.
uniform vec2 contacto = vec2(7.0, 3.0);
// Cuantas luces y cada una: xy = hacia donde cae la sombra (unitario, en el plano de la pantalla), z = largo en pixeles,
// w = nivel del tono (1 = los tres tonos de siempre; menos = una luz floja, mas clara).
uniform int n_luces = 0;
uniform vec4 luces[MAX_LUCES];
uniform vec3 tonos = vec3(0.55, 0.40, 0.25);   // 17/11, su eleccion (la "B", la del medio): 0,34/0,24/0,14 no se veia
uniform vec3 cortes = vec3(0.55, 0.80, 1.0);

varying vec2 p;

void vertex() {
	p = VERTEX;
}

float tono(float r) {
	if (r <= cortes.x) return tonos.x;
	if (r <= cortes.y) return tonos.y;
	if (r <= cortes.z) return tonos.z;
	return 0.0;
}

void fragment() {
	vec2 q = floor(p) + 0.5;
	float a = tono(length(q / contacto));
	for (int i = 0; i < MAX_LUCES; i++) {
		if (i >= n_luces) break;
		vec2 d = luces[i].xy;
		float largo = luces[i].z;
		// La mancha estirada: empieza en los pies y llega hasta 'largo'. Ancho: el de los pies visto desde ese lado
		// (de lado, el alto aplastado; de frente, el ancho).
		float semi = max(contacto.x, largo * 0.5 + contacto.x * 0.5);
		float ancho = mix(contacto.y, contacto.x, abs(d.y)) * 0.95;
		vec2 c = d * (semi - contacto.x * 0.5);
		vec2 v = vec2(-d.y, d.x);
		vec2 w = q - c;
		float r = length(vec2(dot(w, d) / semi, dot(w, v) / ancho));
		// Los tonos de una luz floja, un escalon mas claros (fijos igual).
		a = max(a, tono(r) * luces[i].w);
	}
	COLOR = vec4(0.0, 0.0, 0.0, a);
}
