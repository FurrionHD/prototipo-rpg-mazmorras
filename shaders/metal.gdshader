// ============================================================
//  metal.gdshader
//  ACABADO METALICO del cuerpo del personaje (el ColorRect de player.tscn y su muestra en
//  la pantalla de creacion). NO lleva el color dentro: pinta sobre el que traiga el nodo
//  (COLOR = el color del ColorRect), asi el mismo shader vale para cualquier color elegido.
//
//  Dos cosas hacen la lectura de "metal":
//    - BISEL: mas claro arriba y mas oscuro abajo, como una pieza curva que recoge la luz.
//    - BARRIDO: una banda especular estrecha que cruza en diagonal y se mueve con el tiempo,
//      que es lo que de verdad dice "esto es pulido" (una superficie mate no hace eso).
//  'metal' (0..1) mezcla entre el color plano y el acabado: a 0 se comporta como antes.
// ============================================================
shader_type canvas_item;

// Cuanto acabado metalico: 0 = color plano (como si no hubiera shader), 1 = a tope.
uniform float metal : hint_range(0.0, 1.0) = 0.0;
// Cada cuanto pasa el reflejo (vueltas por segundo). Lento a proposito: un destello
// constante marearia.
uniform float velocidad : hint_range(0.0, 2.0) = 0.25;
// Ancho de la banda de brillo (0.5 = el centro del barrido).
uniform float ancho : hint_range(0.01, 0.3) = 0.06;

void fragment() {
	vec3 base = COLOR.rgb;

	// BISEL vertical: la parte de arriba recibe la luz, la de abajo cae a sombra.
	float bisel = mix(1.30, 0.55, UV.y);

	// BARRIDO diagonal: una franja que recorre la pieza. fract() la repite; los dos
	// smoothstep la recortan a una banda estrecha con los bordes suaves.
	float d = fract(UV.x * 0.7 + UV.y * 0.7 - TIME * velocidad);
	float banda = smoothstep(0.5 - ancho, 0.5, d) * smoothstep(0.5 + ancho, 0.5, d);

	vec3 metalico = clamp(base * bisel + vec3(banda) * 0.75, 0.0, 1.0);
	COLOR.rgb = mix(base, metalico, metal);
}
