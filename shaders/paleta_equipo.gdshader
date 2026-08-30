// ============================================================
//  paleta_equipo.gdshader
//  PINTA UNA PIEZA DE EQUIPO CON LA PALETA QUE LE TOCA por su tier y su nivel de mejora.
//
//  POR QUE NO VALE capa_jugador.gdshader, que ya tiñe capas del muñeco: aquel TIÑE MULTIPLICANDO por
//  un solo color, y multiplicar conserva el sombreado pero aplasta el MATIZ -- toda la pieza acaba
//  del mismo color con distinto brillo. Para el pelo y la ropa eso es exactamente lo que se quiere
//  (una camisa es de UN color). Para una pieza de equipo no: un yelmo tiene acero, oro en la cresta y
//  cuero en las correas, y esos tres tienen que poder cambiar por separado -- o no cambiar.
//
//  ASI QUE AQUI EL COLOR NO SE MULTIPLICA: SE SUSTITUYE, tono por tono. La capa se hornea con una
//  RAMPA DE INDICES (ver CapaJugador.rampa_indices) -- grises exactos, uno por tono -- y este shader
//  convierte cada gris en el numero de tono que es y saca su color de una tabla de 16x1 pixeles.
//  Cambiar de material es cambiar esa tabla, no el dibujo: por eso hay UN solo PNG por pieza en vez
//  de uno por material, que serian veintisiete.
//
//  LA TABLA TIENE QUE ENTRAR CON FILTRO NEAREST. Con filtrado, leer entre dos texeles devuelve un
//  color a medio camino entre dos tonos -- un color que no eligio nadie -- y la pieza sale con el
//  contorno de un marron sucio. Se pone al crear la textura, no aqui.
//
//  EL METAL es el mismo truco que capa_jugador.gdshader, copiado a proposito para que una armadura y
//  el cuerpo brillen igual: no es un degradado por UV (con un AtlasTexture el UV recorre el atlas
//  entero y el bisel sale cortado y bailando), sino estirar el contraste y encender lo que ya era
//  luz, que es como se pinta el metal en pixel-art de verdad.
// ============================================================
shader_type canvas_item;

// La paleta: 16x1, el texel N es el color del tono N.
uniform sampler2D paleta : filter_nearest, repeat_disable;
// Cuantos tonos tiene la rampa. Tiene que ser el mismo numero que uso CapaJugador al hornear, o el
// gris se convierte en el indice equivocado y la pieza sale con los colores de otra.
uniform float tonos : hint_range(2.0, 16.0) = 16.0;
// Cuanto acabado metalico: 0 = mate (cuero, madera), 1 = a tope (placas muy mejoradas).
uniform float metal : hint_range(0.0, 1.0) = 0.0;
// Cada cuanto pasa el destello, en vueltas por segundo. Lento a proposito: en una fila de cuatro
// personajes con armadura, un parpadeo rapido marea.
uniform float velocidad : hint_range(0.0, 2.0) = 0.30;
// Cuanto se separa la luz de la sombra al volverse metalico.
uniform float contraste : hint_range(1.0, 3.0) = 1.55;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// El recorte lo manda SIEMPRE la textura. Sin esta salida temprana, el aire de alrededor del
	// fotograma se lleva el destello y la capa sale dentro de un cuadrado brillante.
	if (tex.a < 0.004) {
		COLOR = vec4(0.0);
	} else {
		// EL GRIS HORNEADO ES EL NUMERO DE TONO. La rampa los deja en i/(tonos-1), asi que basta con
		// deshacer esa division y redondear. Se redondea y no se trunca porque el PNG guarda enteros
		// de 8 bits: 3/15 no cae exacto y truncar bajaria un tono entero.
		float l = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
		float idx = floor(l * (tonos - 1.0) + 0.5);
		vec4 pal = texture(paleta, vec2((idx + 0.5) / 16.0, 0.5));

		// METAL: se estira el contraste alrededor del gris medio del COLOR YA SUSTITUIDO (no del gris
		// del indice, que no significa brillo) y se enciende lo que ya era luz.
		float pl = dot(pal.rgb, vec3(0.299, 0.587, 0.114));
		float lm = clamp((pl - 0.5) * contraste + 0.5, 0.0, 1.0);
		float lf = mix(pl, lm, metal);
		float destello = smoothstep(0.72, 0.96, pl) * metal
			* (0.5 + 0.5 * sin(TIME * velocidad * 6.2831853));

		vec3 c = pal.rgb * (lf / max(0.001, pl));
		c += vec3(destello * 0.40);
		// El modulate sigue multiplicando, para que un aliado desvaido o un parpadeo de daño sigan
		// funcionando sobre el equipo igual que sobre el resto del muñeco.
		COLOR = vec4(clamp(c, 0.0, 1.0) * COLOR.rgb, tex.a * pal.a * COLOR.a);
	}
}
