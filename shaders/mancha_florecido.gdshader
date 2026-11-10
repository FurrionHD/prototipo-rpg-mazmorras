// LA MANCHA PODRIDA AL PIE DE CADA SETA (10/11/2026, florecidos, version E aprobada: "esta es peak").
// Se pinta ENCIMA del cuerpo con el MISMO fotograma que el cuerpo (HongosPixel copia su textura y su sitio), asi que solo
// sale donde hay cuerpo: el alfa es el del dibujo.
// 10/11 (el jefe: "parecen manchones encima de la armadura, no son pixel art igual que el personaje"): ya NO es un marron
// medio transparente por encima: MULTIPLICA (blend_mul) los colores que ya tiene el cuerpo, en dos escalones de pixel
// exactos (la rejilla del sprite), como un sombreado a mano. Fuera de la mancha o del cuerpo: blanco = no cambia nada.
shader_type canvas_item;
render_mode blend_mul;

uniform vec2 pies[10];
uniform int n_pies = 0;
uniform vec2 radio = vec2(4.5, 3.0);
uniform vec3 hondo = vec3(0.46, 0.4, 0.32);   // el escalon de dentro: oscuro y algo ocre (podrido)
uniform vec3 borde = vec3(0.74, 0.69, 0.6);   // el de fuera

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	float a = texture(TEXTURE, UV).a;
	vec2 p = floor(local) + 0.5;
	float k = 0.0;
	for (int i = 0; i < 10; i++) {
		if (i >= n_pies) {
			break;
		}
		vec2 d = (p - pies[i] + vec2(0.0, 1.0)) / radio;
		float f = 1.2 - dot(d, d);
		k = max(k, f > 0.55 ? 2.0 : (f > 0.0 ? 1.0 : 0.0));
	}
	vec3 m = k > 1.5 ? hondo : (k > 0.5 ? borde : vec3(1.0));
	COLOR = vec4(a > 0.16 ? m : vec3(1.0), 1.0);
}
