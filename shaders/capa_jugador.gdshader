// ============================================================
//  capa_jugador.gdshader
//  TIÑE UNA CAPA DEL PERSONAJE (el cuerpo, un peto, una espada) y, si toca, la vuelve metalica.
//
//  POR QUE NO VALE metal.gdshader, que ya existe y hace justo esto de cara al usuario: aquel nacio
//  para un ColorRect, que NO TIENE TEXTURA, asi que lee el color del nodo y lo pinta plano. Puesto
//  sobre un sprite no tiñe el dibujo: lo TAPA -- sale un cuadrado de color liso donde deberia estar
//  el personaje. Los dos siguen existiendo porque cubren dos casos que solo se parecen de lejos:
//  aquel pinta un rectangulo de color (y sigue haciendolo en la ficha y en el creador de personaje),
//  este tiñe un pixel-art ya dibujado.
//
//  Y DE AHI LA REGLA DE ESTE: TEÑIR ES MULTIPLICAR, NO SUSTITUIR. Las capas se hornean en GRIS --
//  con sus escalones de sombra, base, luz y contorno -- y el color entra multiplicando, que es lo
//  unico que conserva el sombreado. Mezclando hacia el color (que es lo que hace el otro) el peto
//  saldria de un solo tono, sin volumen y sin contorno, o sea otra vez un recorte plano.
//  El tinte es el 'modulate' del nodo: un color por capa, sin uniform que mantener.
//
//  EL METAL no va por gradiente de UV como en el otro, y no es por gusto: con un AtlasTexture el UV
//  recorre el ATLAS entero, no el fotograma, asi que un bisel por UV.y sale cortado y bailando de un
//  fotograma a otro. Aqui el acabado se saca del propio dibujo -- se estira el contraste y se hace
//  destellar lo mas claro --, que ademas es como se pinta el metal en pixel-art de verdad: no es un
//  degradado, son las luces muy separadas de las sombras.
// ============================================================
shader_type canvas_item;

// Cuanto acabado metalico: 0 = mate (cuero, tela, madera), 1 = a tope (placas pulidas).
uniform float metal : hint_range(0.0, 1.0) = 0.0;
// Cada cuanto pasa el destello, en vueltas por segundo. Lento a proposito: en una fila de cuatro
// personajes con armadura, un parpadeo rapido marea.
uniform float velocidad : hint_range(0.0, 2.0) = 0.30;
// Cuanto se separa la luz de la sombra al volverse metalico.
uniform float contraste : hint_range(1.0, 3.0) = 1.55;

// EL TONO MEDIO DE REFERENCIA: que gris del horneado tiene que salir EXACTAMENTE del color elegido.
// Lo mas claro sale mas claro que ese color y lo mas oscuro, mas oscuro.
//
// Sin esto, teñir multiplicando OSCURECE SIEMPRE: un gris de 0,48 por un color medio de 0,45 da
// 0,21, o sea casi negro. Al probarlo en el juego el personaje salia como una silueta con la cara
// blanca, y no porque los grises estuvieran mal elegidos sino porque multiplicar dos numeros
// menores que uno da algo menor que los dos. Dividiendo por la referencia, el gris de la ropa cae
// justo en tu color y la piel queda por encima -- que es lo que se dibujo.
uniform float base : hint_range(0.05, 1.0) = 0.62;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// El recorte lo manda SIEMPRE la textura. Sin esta salida temprana, el aire de alrededor del
	// fotograma se llevaria el destello del metal y la capa saldria dentro de un cuadrado brillante.
	if (tex.a < 0.004) {
		COLOR = vec4(0.0);
	} else {
		float l = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
		// METAL: se estira el contraste alrededor del gris medio y se enciende lo que ya era luz.
		float lm = clamp((l - 0.5) * contraste + 0.5, 0.0, 1.0);
		float lf = mix(l, lm, metal);
		float destello = smoothstep(0.72, 0.96, l) * metal
			* (0.5 + 0.5 * sin(TIME * velocidad * 6.2831853));

		// El color del nodo (modulate) MULTIPLICA, que es lo que conserva el sombreado horneado, y
		// se reparte alrededor del tono medio para que no oscurezca.
		vec3 c = tex.rgb * (lf / max(0.001, l)) * COLOR.rgb / base;
		c += vec3(destello * 0.40);
		COLOR = vec4(clamp(c, 0.0, 1.0), tex.a * COLOR.a);
	}
}
