// ============================================================
//  noche_pueblo.gdshader
//  La luz del pueblo segun la hora (ver scripts/core/ciclo_dia.gd). Va en un ColorRect a pantalla
//  completa, por encima del mundo y por debajo del HUD, igual que la niebla de la mazmorra.
//
//  MULTIPLICA la pantalla (blend_mul): blanco no toca nada, el azul de la noche la oscurece y tiñe.
//  Alrededor de cada FOCO (antorcha, ventana, altar) el color vuelve hacia el de esa luz, asi que
//  junto a una antorcha las cosas se ven con su color, calidas, y lejos se quedan azuladas.
//
//  Sin luces 2D de Godot: con el renderer de compatibilidad cada PointLight2D vuelve a dibujar lo
//  que toca, y aqui no hacen falta sombras. Unos pocos focos en un array y una distancia por pixel.
// ============================================================
shader_type canvas_item;
render_mode unshaded, blend_mul;

uniform vec3 tinte = vec3(1.0);

uniform vec2 cam_centro = vec2(0.0);
uniform vec2 cam_zoom = vec2(1.0);
uniform vec2 pantalla = vec2(1280.0, 720.0);

// Los focos que caen en pantalla. xy = posicion en el MUNDO (px), z = radio (px), w = intensidad 0..1.
uniform int n_focos = 0;
uniform vec4 focos[48];
// rgb = color de la luz (la multiplicacion: 1,1,1 = a plena luz de dia).
uniform vec4 colores[48];

// 0 = caida suave; N = la luz en N escalones (pixel-art).
uniform float escalones = 0.0;


void fragment() {
	vec2 mundo = cam_centro + (SCREEN_UV - vec2(0.5)) * pantalla / cam_zoom;
	// A pixel de mundo entero: el borde de los escalones sigue la rejilla del dibujo.
	vec2 px = floor(mundo) + vec2(0.5);
	vec3 c = tinte;
	for (int i = 0; i < n_focos; i++) {
		float d = distance(px, focos[i].xy) / max(focos[i].z, 1.0);
		if (d >= 1.0) {
			continue;
		}
		float k = 1.0 - d;
		k = k * k * (3.0 - 2.0 * k);
		if (escalones > 0.5) {
			k = ceil(k * escalones) / escalones;
		}
		k *= focos[i].w;
		// Se junta con MAX, no sumando: dos antorchas juntas no hacen un mediodia.
		c = max(c, mix(tinte, colores[i].rgb, k));
	}
	COLOR = vec4(c, 1.0);
}
