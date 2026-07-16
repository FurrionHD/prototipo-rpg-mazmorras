// ============================================================
//  metal.gdshader
//  ASPECTO del cuerpo del personaje (el ColorRect de player.tscn y su muestra en la pantalla
//  de creacion). Monta tres capas, de abajo a arriba:
//
//    1) BASE:  tu IMAGEN, si has puesto una (uniform 'imagen'). Si no, el color plano del nodo.
//    2) TINTE: el color elegido, por ENCIMA de la imagen, con la opacidad que quieras
//              ('color_alpha'): 0 = la imagen tal cual, 1 = solo color (la imagen queda tapada).
//              Sin imagen este paso no hace nada: la base YA es el color.
//    3) METAL: el acabado, SIEMPRE lo ultimo, asi que barniza tambien tu imagen.
//
//  El color NO va dentro del shader: se pinta sobre el que traiga el nodo (COLOR = el color del
//  ColorRect), asi el mismo shader vale para cualquier color elegido.
//
//  Dos cosas hacen la lectura de "metal":
//    - BISEL: mas claro arriba y mas oscuro abajo, como una pieza curva que recoge la luz.
//    - BARRIDO: una banda especular estrecha que cruza en diagonal y se mueve con el tiempo,
//      que es lo que de verdad dice "esto es pulido" (una superficie mate no hace eso).
//  'metal' (0..1) mezcla entre la base y el acabado: a 0 se comporta como antes.
// ============================================================
shader_type canvas_item;

// Cuanto acabado metalico: 0 = sin brillo (como si no hubiera shader), 1 = a tope.
uniform float metal : hint_range(0.0, 1.0) = 0.0;
// Cada cuanto pasa el reflejo (vueltas por segundo). Lento a proposito: un destello
// constante marearia.
uniform float velocidad : hint_range(0.0, 2.0) = 0.25;
// Ancho de la banda de brillo (0.5 = el centro del barrido).
uniform float ancho : hint_range(0.01, 0.3) = 0.06;

// --- IMAGEN propia del personaje (opcional) ---
// Un ColorRect no tiene TEXTURE, asi que la imagen entra como uniform y se muestrea con el UV del
// nodo (0..1 de lado a lado). 'tiene_imagen' es el interruptor: sin ella no se toca el sampler y
// el cuerpo es el color plano de siempre.
uniform sampler2D imagen : source_color, hint_default_transparent;
uniform bool tiene_imagen = false;
// Opacidad del COLOR por encima de la imagen. Solo pinta si hay imagen.
uniform float color_alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec3 base = COLOR.rgb;
	float alpha = COLOR.a;

	if (tiene_imagen) {
		vec4 tex = texture(imagen, UV);
		// El color va ENCIMA de la imagen, con la opacidad elegida.
		base = mix(tex.rgb, COLOR.rgb, color_alpha);
		// El recorte lo manda la IMAGEN: si tu PNG trae transparencia, el cuerpo la respeta.
		alpha = tex.a * COLOR.a;
	}

	// BISEL vertical: la parte de arriba recibe la luz, la de abajo cae a sombra.
	float bisel = mix(1.30, 0.55, UV.y);

	// BARRIDO diagonal: una franja que recorre la pieza. fract() la repite; los dos
	// smoothstep la recortan a una banda estrecha con los bordes suaves.
	float d = fract(UV.x * 0.7 + UV.y * 0.7 - TIME * velocidad);
	float banda = smoothstep(0.5 - ancho, 0.5, d) * smoothstep(0.5 + ancho, 0.5, d);

	vec3 metalico = clamp(base * bisel + vec3(banda) * 0.75, 0.0, 1.0);
	COLOR.rgb = mix(base, metalico, metal);
	COLOR.a = alpha;
}
