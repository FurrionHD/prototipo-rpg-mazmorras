// ============================================================
//  circulo_pixel.gdshader
//  LOS CIRCULOS MAGICOS EN PIXEL ART (04/11/2026, memoria efectos-pixel-personajes). CirculoMagico pinta una
//  MASCARA a 1 celda = 1 pixel (rejilla de los sprites) y aqui se le pone la paleta cerrada del elemento:
//    R  > 0.8  trazo fuerte -> nucleo casi blanco      R 0.55-0.8  trazo fino -> claro; 0.45-0.55 tenue -> medio
//    R 0.2-0.45 pozo (oscuridad maciza)                R 0.05-0.2  luz en el suelo (trama)
//    G = elemento / 8,  B = intensidad / 2 (lo que se va apagando se deshace en trama Bayer a bloques de 2).
//  Alrededor de cada trazo: el filo de su color y detras el cuerpo oscuro (a trama), sin alfa a medias.
// ============================================================
shader_type canvas_item;

uniform vec4 pal[24];          // 6 elementos x 4 tonos: [nucleo, claro, medio, oscuro]
uniform vec4 pozo_col : source_color = vec4(0.07, 0.02, 0.10, 1.0);
uniform float fallo = 0.0;     // 0..1: la paleta tira a rojo apagado al romperse
uniform vec2 celda0 = vec2(0.0);   // celda del mundo de la esquina: la trama no repta al moverse

float bayer2(ivec2 c) {
	// bloques de 2 celdas (a 1 celda es ruido)
	ivec2 b = ivec2(floor(vec2(c) / 2.0));
	int x = b.x & 1;
	int y = b.y & 1;
	if (x == 0 && y == 0) return 0.125;
	if (x == 1 && y == 1) return 0.375;
	if (x == 1 && y == 0) return 0.625;
	return 0.875;
}

vec4 tono(float g, int k) {
	int e = clamp(int(round(g * 8.0)), 0, 5);
	vec4 c = pal[e * 4 + k];
	vec4 roja = vec4(vec3(0.62, 0.22, 0.2) * (1.0 - 0.18 * float(k)), 1.0);
	if (k == 0) roja = vec4(0.85, 0.62, 0.58, 1.0);
	return mix(c, roja, fallo);
}

void fragment() {
	vec2 tam = vec2(textureSize(TEXTURE, 0));
	ivec2 ip = ivec2(floor(UV * tam));
	ivec2 cw = ip + ivec2(celda0);
	float umbral = bayer2(cw);
	vec4 m = texelFetch(TEXTURE, ip, 0);
	vec4 sale = vec4(0.0);
	if (m.a > 0.5 && m.r > 0.45) {
		// el trazo
		if (m.b * 2.0 > umbral * 0.9) {
			sale = tono(m.g, m.r > 0.8 ? 0 : (m.r > 0.55 ? 1 : 2));
		}
	} else {
		// lo de alrededor: el filo de su color, solo en las 4 celdas pegadas a un trazo fuerte
		vec4 cerca = vec4(0.0);
		bool hay = false;
		ivec2 vec[4] = ivec2[](ivec2(1, 0), ivec2(-1, 0), ivec2(0, 1), ivec2(0, -1));
		for (int i = 0; i < 4; i++) {
			vec4 v = texelFetch(TEXTURE, ip + vec[i], 0);
			if (v.a > 0.5 && v.r > 0.8 && (!hay || v.b > cerca.b)) { cerca = v; hay = true; }
		}
		if (hay && cerca.b * 2.0 > umbral) sale = tono(cerca.g, 2);
		if (sale.a == 0.0 && m.a > 0.5) {
			if (m.r > 0.2) {
				if (m.b * 2.0 > umbral * 0.8) sale = pozo_col;
			} else if (m.r > 0.05) {
				if (m.b * 2.0 > umbral) sale = tono(m.g, 3);
			}
		}
	}
	COLOR = sale;
}
