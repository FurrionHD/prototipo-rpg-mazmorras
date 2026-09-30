// LOS OJOS DE LA CAMADA (30/09/2026, el Rey de la camada): mientras vive el rey rata, a sus ratas les brillan los
// ojos en ROJO. Va en el sprite (horneado o generado): se reconoce el pixel del ojo por su color exacto
// (RataSprites._colores, OJO_T = 0.1, 0.07, 0.07) y se enciende, con un halo que asoma a su alrededor y un latido.
// 'encendido' 0..1 lo sube y lo baja CombatTactico (se apagan todos a la vez cuando muere el rey).
// Se busca el color del PNG y, por si el motor lo diera en lineal, tambien ese (tolerancia de cada espacio: el borde
// oscuro queda lejos en los dos).
shader_type canvas_item;

uniform float encendido : hint_range(0.0, 1.0) = 1.0;
uniform vec3 ojo = vec3(0.1, 0.07, 0.07);
uniform vec3 rojo = vec3(1.0, 0.22, 0.12);

// El tinte del nodo (modulate), sin la textura: en el fragment COLOR ya viene multiplicado por ella.
varying vec4 tinte;

void vertex() {
	tinte = COLOR;
}

bool es_ojo(vec4 c) {
	if (c.a < 0.9) return false;
	vec3 lin = pow(ojo, vec3(2.2));
	return all(lessThan(abs(c.rgb - ojo), vec3(0.015))) || all(lessThan(abs(c.rgb - lin), vec3(0.006)));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float lat = 0.85 + 0.15 * sin(TIME * 6.0);
	if (encendido > 0.001) {
		if (es_ojo(c)) {
			// El ojo al rojo vivo, con el centro casi blanco al latir.
			c.rgb = mix(c.rgb, mix(rojo, vec3(1.0, 0.8, 0.65), 0.3 * lat), encendido);
		} else {
			// EL HALO: lo que toca a un ojo se tiñe un poco de rojo (mas en cruz que en diagonal). Con dos pixeles de radio la
			// cara entera de la rata se volvia una mancha roja (visto en la hoja, 30/09).
			float h = 0.0;
			for (int x = -1; x <= 1; x++) {
				for (int y = -1; y <= 1; y++) {
					if (x == 0 && y == 0) continue;
					if (es_ojo(texture(TEXTURE, UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE))) {
						h = max(h, (x == 0 || y == 0) ? 1.0 : 0.6);
					}
				}
			}
			h *= encendido * lat;
			if (h > 0.0) {
				if (c.a < 0.5) {
					c = vec4(rojo, max(c.a, h * 0.55));   // fuera del cuerpo: el resplandor
				} else {
					c.rgb = mix(c.rgb, rojo, h * 0.3);    // sobre la cara: la tiñe un poco
				}
			}
		}
	}
	COLOR = c * tinte;
}
