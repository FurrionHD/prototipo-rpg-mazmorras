// ============================================================
//  pixelar.gdshader -- lo que CapaPixel pinto a 2x2 subpixeles por celda (se queda el mas fuerte), cerrado a pixel art (04/11/2026):
//  lo flojo fuera, lo medio con alfa en 4 escalones (sin rejilla, 10/11), lo fuerte macizo y el color en escalones
//  (tono, saturacion y brillo cuantizados): el degradado suave se vuelve bandas de pocos tonos, como los sprites.
// ============================================================
shader_type canvas_item;

uniform vec2 celda0 = vec2(0.0);
uniform float corte_bajo = 0.14;    // menos que esto: fuera (los halos difuminados no dejan niebla)
uniform float corte_alto = 0.62;    // mas que esto: macizo
uniform float pasos_v = 5.0;
uniform float pasos_s = 4.0;
uniform float pasos_h = 36.0;

// SIN REJILLA (10/11, memoria transparencia-de-verdad): donde antes salia "pixel si, pixel no" (trama Bayer), ahora sale
// cada pixel con el alfa en 4 escalones: los 4 umbrales de la trama, promediados (lo mismo que tools/sprites_sdf/transparencia.py).
float escalones(float k) {
	return (step(0.125, k) + step(0.375, k) + step(0.625, k) + step(0.875, k)) * 0.25;
}

vec3 a_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 a_rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec2 tam = vec2(textureSize(TEXTURE, 0));
	ivec2 sp = ivec2(floor(UV * tam));
	ivec2 ip = sp / 2;          // la celda (el lienzo va a 2 subpixeles por celda)
	vec4 m = vec4(0.0);
	for (int j = 0; j < 2; j++) {
		for (int i = 0; i < 2; i++) {
			vec4 v = texelFetch(TEXTURE, ip * 2 + ivec2(i, j), 0);
			// lo que se pinto en mezcla ADITIVA (halos, brillos) suma color pero casi no deja alfa: su alfa es su brillo
			// (solo lo que brilla de verdad: un resplandor tenue saldria como nube de puntos)
			v.a = max(v.a, clamp((max(v.r, max(v.g, v.b)) - 0.3) / 0.4, 0.0, 1.0));
			if (v.a > m.a) m = v;
		}
	}
	float a = m.a;
	float alfa = a >= corte_alto ? 1.0 : (a >= corte_bajo ? escalones((a - corte_bajo) / (corte_alto - corte_bajo)) : 0.0);
	if (alfa <= 0.0) {
		COLOR = vec4(0.0);
	} else {
		// el lienzo guarda el color premultiplicado (se pinto sobre transparente): se deshace
		vec3 c = clamp(m.rgb / max(a, 0.001), 0.0, 1.0);
		vec3 h = a_hsv(c);
		h.x = floor(h.x * pasos_h + 0.5) / pasos_h;
		h.y = floor(h.y * pasos_s + 0.5) / pasos_s;
		h.z = clamp(ceil(h.z * pasos_v - 0.25) / pasos_v, 0.0, 1.0);
		COLOR = vec4(a_rgb(h), alfa);
	}
}
