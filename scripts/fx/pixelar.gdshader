// ============================================================
//  pixelar.gdshader -- lo que CapaPixel pinto a 1 celda = 1 pixel, cerrado a pixel art (04/11/2026):
//  sin alfa a medias (lo flojo fuera, lo medio a trama Bayer de 2 celdas, lo fuerte macizo) y el color en escalones
//  (tono, saturacion y brillo cuantizados): el degradado suave se vuelve bandas de pocos tonos, como los sprites.
// ============================================================
shader_type canvas_item;

uniform vec2 celda0 = vec2(0.0);
uniform float corte_bajo = 0.14;    // menos que esto: fuera (los halos difuminados no dejan niebla)
uniform float corte_alto = 0.62;    // mas que esto: macizo
uniform float pasos_v = 5.0;
uniform float pasos_s = 4.0;
uniform float pasos_h = 36.0;

float bayer2(ivec2 c) {
	ivec2 b = ivec2(floor(vec2(c) / 2.0));
	int x = b.x & 1;
	int y = b.y & 1;
	if (x == 0 && y == 0) return 0.125;
	if (x == 1 && y == 1) return 0.375;
	if (x == 1 && y == 0) return 0.625;
	return 0.875;
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
	ivec2 ip = ivec2(floor(UV * tam));
	vec4 m = texelFetch(TEXTURE, ip, 0);
	float a = m.a;
	float u = bayer2(ip + ivec2(celda0));
	bool queda = a >= corte_alto || (a >= corte_bajo && (a - corte_bajo) / (corte_alto - corte_bajo) > u);
	if (!queda) {
		COLOR = vec4(0.0);
	} else {
		// el lienzo guarda el color premultiplicado (se pinto sobre transparente): se deshace
		vec3 c = clamp(m.rgb / max(a, 0.001), 0.0, 1.0);
		vec3 h = a_hsv(c);
		h.x = floor(h.x * pasos_h + 0.5) / pasos_h;
		h.y = floor(h.y * pasos_s + 0.5) / pasos_s;
		h.z = clamp(ceil(h.z * pasos_v - 0.25) / pasos_v, 0.0, 1.0);
		COLOR = vec4(a_rgb(h), 1.0);
	}
}
