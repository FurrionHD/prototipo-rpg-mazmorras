// LA RABIA DEL MINOTAURO (02/10/2026, paso 2): por debajo del 30% le brillan los ojos en ROJO y el cuerpo se le va a un
// rojizo leve que late (no tanto que destaque frente a los demas). Copiado de ojos_camada: el ojo se reconoce por su color
// exacto en sus hojas (minotauro_sdf.py, el tono de luz de 'ojo': 255/229/102) y se enciende, con su halo.
// 'encendido' 0..1 lo sube CombatTactico._tick_minotauro al cruzar el umbral.
shader_type canvas_item;

uniform float encendido : hint_range(0.0, 1.0) = 0.0;
uniform vec3 ojo = vec3(1.0, 0.898, 0.4);
uniform vec3 rojo = vec3(1.0, 0.16, 0.08);
// Lo rojizo del cuerpo: cuanto se mezcla (en lo mas alto del latido) y a que ritmo late.
uniform float rojizo = 0.22;
uniform float latido = 3.2;

// El tinte del nodo (modulate), sin la textura: en el fragment COLOR ya viene multiplicado por ella.
varying vec4 tinte;

void vertex() {
	tinte = COLOR;
}

bool es_ojo(vec4 c) {
	if (c.a < 0.9) return false;
	vec3 lin = pow(ojo, vec3(2.2));
	return all(lessThan(abs(c.rgb - ojo), vec3(0.03))) || all(lessThan(abs(c.rgb - lin), vec3(0.01)));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float lat = 0.85 + 0.15 * sin(TIME * 6.0);
	if (encendido > 0.001 && c.a > 0.01) {
		if (es_ojo(c)) {
			c.rgb = mix(c.rgb, mix(rojo, vec3(1.0, 0.75, 0.6), 0.3 * lat), encendido);
		} else {
			// EL ROJIZO: hacia un rojo de sangre, mas en las luces que en el contorno (el borde oscuro se queda).
			float pulso = 0.65 + 0.35 * sin(TIME * latido);
			float luz = dot(c.rgb, vec3(0.299, 0.587, 0.114));
			vec3 rojizo_c = c.rgb * vec3(1.18, 0.78, 0.72);
			c.rgb = mix(c.rgb, rojizo_c, rojizo * pulso * encendido * smoothstep(0.08, 0.35, luz));
			// EL HALO del ojo (solo un pixel alrededor: con mas, la cara entera era una mancha).
			float h = 0.0;
			for (int x = -1; x <= 1; x++) {
				for (int y = -1; y <= 1; y++) {
					if (x == 0 && y == 0) continue;
					if (es_ojo(texture(TEXTURE, UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE))) {
						h = max(h, (x == 0 || y == 0) ? 1.0 : 0.6);
					}
				}
			}
			c.rgb = mix(c.rgb, rojo, h * 0.35 * encendido * lat);
		}
	} else if (encendido > 0.001) {
		// Fuera del cuerpo, el resplandor del ojo.
		float h = 0.0;
		for (int x = -1; x <= 1; x++) {
			for (int y = -1; y <= 1; y++) {
				if (es_ojo(texture(TEXTURE, UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE))) {
					h = max(h, (x == 0 || y == 0) ? 1.0 : 0.6);
				}
			}
		}
		if (h > 0.0) {
			c = vec4(rojo, h * 0.55 * encendido * lat);
		}
	}
	COLOR = c * tinte;
}
