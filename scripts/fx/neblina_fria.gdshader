// LA NEBLINA DEL AURA FRIA EN PIXEL ART (04/11/2026, memoria efectos-a-pixel-art): el mismo tamano de celda que los sprites y su paleta
// cerrada, sin una mezcla. Un solo rectangulo a pintar: lo que importa es a que distancia del borde de la zona cae cada celda, y
// lo que se desvanece, con alfa en 4 escalones (sin rejilla, 10/11). Sin esto serian miles de draw_rect por fotograma.
shader_type canvas_item;
render_mode unshaded;

uniform vec2 centro;       // el centro del dibujo, en coordenadas del nodo
uniform vec2 media;        // la mitad del dibujo
uniform float alcance;     // hasta donde llega el aura desde su borde
uniform float celda = 1.15;
uniform vec4 c0 : source_color = vec4(0.25, 0.376, 0.549, 1.0);
uniform vec4 c1 : source_color = vec4(0.557, 0.714, 0.871, 1.0);
uniform vec4 c2 : source_color = vec4(0.831, 0.925, 1.0, 1.0);
uniform vec4 c3 : source_color = vec4(1.0, 1.0, 1.0, 1.0);

varying vec2 pos;

void vertex() {
	pos = VERTEX;
}

float azar(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 cel = floor(pos / celda);
	vec2 p = (cel + 0.5) * celda;
	// la distancia al borde de la zona (el dibujo ensanchado, con las esquinas redondas)
	vec2 q = abs(p - centro) - media;
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - alcance;
	// el vaho da la vuelta despacio: el borde respira y la espesura cambia por sitios
	float ang = atan(p.y - centro.y, p.x - centro.x);
	float ola = sin(ang * 5.0 + TIME * 0.7) * 3.0 + sin(ang * 11.0 - TIME * 0.45) * 1.5;
	float u = (d - ola) / 12.0;   // 0 en el borde; negativo, dentro
	float espesa = 0.5 + 0.5 * sin(ang * 7.0 - TIME * 0.5 + d * 0.15);
	float cant = 0.0;
	if (u < 0.0) {
		cant = max(0.0, 1.0 + u * 0.75) * (0.34 + 0.2 * espesa);   // casi nada junto al cuerpo; se espesa hacia el borde
	} else {
		cant = max(0.0, 1.0 - u) * 0.34;                           // y se deshace justo despues
	}
	ivec2 t = ivec2(floor(cel / 2.0));
	// SIN REJILLA (10/11, memoria transparencia-de-verdad): los 4 umbrales de la trama, promediados: cada celda con su color
	// medio y el alfa en 4 escalones (antes: trama Bayer, "pixel si, pixel no").
	vec3 suma = vec3(0.0);
	float n = 0.0;
	for (int i = 0; i < 4; i++) {
		float umbral = 0.125 + 0.25 * float(i);
		if (umbral < cant) {
			suma += (umbral < cant * 0.3 ? c2 : (umbral < cant * 0.7 ? c1 : c0)).rgb;
			n += 1.0;
		}
	}
	vec4 col = n > 0.0 ? vec4(suma / n, n * 0.25) : vec4(0.0);
	// las chispitas de escarcha que titilan (bloques de 2 celdas)
	float a = azar(vec2(t));
	if (d < 2.0 && a > 0.985 && fract(TIME * 0.7 + a * 37.0) < 0.5) {
		col = c3;
	}
	COLOR = col;
}
