// ============================================================
//  oscuridad.gdshader
//  La niebla de la mazmorra. Se pinta en un ColorRect a pantalla completa, por encima del mundo y
//  por debajo del HUD, y lo unico que hace es leer la mascara que calcula vision.gd (una textura
//  R8 diminuta, del tamaño del piso en subceldas) y devolver negro con la transparencia al reves.
//
//  EL DIFUMINADO SALE GRATIS. La mascara es de subceldas (16 px de mundo por texel), asi que al
//  estirarla a pantalla el filtro lineal ya interpola: el borde del corro de luz sale degradado
//  sin que haya que emborronar nada a mano. Por eso se muestrea con 'filter_linear' y no nearest,
//  que es justo lo contrario de lo que quiere el resto del juego.
//
//  Compatible con gl_compatibility (el renderer del proyecto): aqui no hay luces, ni sombras, ni
//  buffers -- una textura y una resta.
// ============================================================
shader_type canvas_item;
render_mode unshaded;

// La mascara de visibilidad. 0 = a oscuras, 1 = a plena luz.
uniform sampler2D mascara : filter_linear, repeat_disable;

// Rectangulo del MUNDO que cubre la mascara (posicion y tamaño en px). Con esto se pasa de
// coordenada de pantalla a coordenada de la mascara.
uniform vec2 mapa_origen = vec2(0.0);
uniform vec2 mapa_tam = vec2(1.0);

// La camara: donde mira y cuanto zoom tiene. Hace falta para deshacer la proyeccion.
uniform vec2 cam_centro = vec2(0.0);
uniform vec2 cam_zoom = vec2(1.0);
uniform vec2 pantalla = vec2(1280.0, 720.0);

// Cuanto se ve en lo que NO esta iluminado. 0.0 = negro absoluto.
uniform float negro : hint_range(0.0, 1.0) = 1.0;

// La niebla respira: un temblor lento en el borde para que no parezca un recorte de carton.
uniform float ruido_fuerza : hint_range(0.0, 0.5) = 0.06;


float ruido(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float ruido_suave(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = ruido(i);
	float b = ruido(i + vec2(1.0, 0.0));
	float c = ruido(i + vec2(0.0, 1.0));
	float d = ruido(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}


void fragment() {
	// pantalla -> mundo. SCREEN_UV va de 0 a 1; el centro de la pantalla es cam_centro.
	vec2 mundo = cam_centro + (SCREEN_UV - vec2(0.5)) * pantalla / cam_zoom;
	// mundo -> uv de la mascara
	vec2 uv = (mundo - mapa_origen) / mapa_tam;

	float luz = 0.0;
	// Fuera del piso no hay nada que enseñar: se queda negro.
	if (uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0) {
		luz = texture(mascara, uv).r;
	}

	// El temblor solo muerde en el BORDE (donde luz esta a medias), no en el corro iluminado ni
	// en la oscuridad de dentro: si no, el suelo bien iluminado parpadearia.
	float borde = luz * (1.0 - luz) * 4.0;
	luz += (ruido_suave(mundo * 0.05 + vec2(TIME * 0.25, TIME * -0.19)) - 0.5)
		* ruido_fuerza * borde;

	COLOR = vec4(0.0, 0.0, 0.0, clamp((1.0 - luz) * negro, 0.0, 1.0));
}
