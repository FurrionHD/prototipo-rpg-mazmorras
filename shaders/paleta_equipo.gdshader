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
//  EL METAL ES UNA BANDA QUE CRUZA LA PIEZA, la misma de shaders/metal.gdshader -- el que ya llevan
//  las vetas de mineral. Que el equipo y la mena brillen igual no es un capricho: es lo que dice que
//  la espada esta hecha de eso.
//
//  ANTES ERA UN PULSO y estaba mal. Toda la pieza subia y bajaba de brillo a la vez, asi que sobre una
//  armadura oscura lo que se veia era parpadear entre oscuro y muy oscuro -- nunca una linea. Un pulso
//  uniforme no puede leerse como metal: lo que dice "esto es pulido" es que el reflejo SE MUEVA por la
//  superficie, porque una superficie mate no hace eso.
//
//  Y NO SE HIZO ANTES POR ESTE MOTIVO, QUE ERA CIERTO A MEDIAS: con un AtlasTexture el UV recorre el
//  ATLAS ENTERO, asi que una banda calculada sobre UV sale cortada y bailando de un fotograma a otro.
//  La salida es no usar UV: 'VERTEX' en la funcion vertex() son las coordenadas LOCALES del cuadro que
//  se dibuja -- en pixeles de la pieza y sin saber nada del atlas -- y de ahi sale una banda que se
//  queda quieta sobre la armadura mientras el personaje anda.
//
//  Y LA BANDA VA EN PIXELES, NO EN FRACCION DE LA PIEZA. Normalizando por su tamaño, un guantelete
//  pequeño y un peto grande tendrian bandas de anchos distintos y no se leerian como el mismo metal.
//  Con un periodo fijo en pixeles, todas las piezas del personaje comparten el mismo reflejo.
// ============================================================
shader_type canvas_item;

// La paleta: 16x1, el texel N es el color del tono N.
uniform sampler2D paleta : filter_nearest, repeat_disable;
// Cuantos tonos tiene la rampa. Tiene que ser el mismo numero que uso CapaJugador al hornear, o el
// gris se convierte en el indice equivocado y la pieza sale con los colores de otra.
uniform float tonos : hint_range(2.0, 16.0) = 16.0;
// Cuanto acabado metalico: 0 = mate (cuero, madera), 1 = a tope (placas muy mejoradas).
uniform float metal : hint_range(0.0, 1.0) = 0.0;
// Cada cuanto pasa la banda, en vueltas por segundo. Lento a proposito: en una fila de cuatro
// personajes con armadura, un reflejo rapido marea. Es el mismo orden que el de las vetas (0,2).
uniform float velocidad : hint_range(0.0, 2.0) = 0.28;
// CADA CUANTOS PIXELES DE LA PIEZA se repite la banda.
//
// TIENE QUE SER MENOR QUE LA PIEZA, y ese es el numero que hay que acertar. Con 34 px la banda era
// mas larga que un peto (que ocupa unos 30 px del fotograma de 84), asi que se pasaba la mayor parte
// del ciclo FUERA de la armadura: el reflejo existia y no se veia nunca. A 18 px caben casi dos
// pasadas en la pieza mas pequeña, o sea que siempre hay una cruzando.
uniform float franja : hint_range(8.0, 128.0) = 18.0;
// Lo ancha que es la banda, en fraccion del periodo. Estrecha = reflejo; ancha = la pieza encendida.
uniform float ancho : hint_range(0.01, 0.4) = 0.13;
// Cuanto se separa la luz de la sombra al volverse metalico.
uniform float contraste : hint_range(1.0, 3.0) = 1.55;
// LO CLARO QUE ES EL TONO DE LUZ DE ESTE MATERIAL (ver PaletaEquipo.luz_ref). Es el umbral del
// destello, y tiene que venir de fuera porque el shader ve un pixel cada vez y no sabe cual es el
// tono mas claro de la pieza.
//
// ANTES ERA UN UMBRAL FIJO (0.72) Y ASI EL BRILLO NO SE VEIA NUNCA: 'metal' sube con la mejora pero
// la paleta OSCURECE con la mejora, asi que a +15 -- con el brillo a tope -- no quedaba ni un pixel
// que pasara de 0.72. Un hierro negro no destellaba jamas. Relativo, destella la luz de cada
// material sea clara u oscura, que es lo que hace el mineral en shaders/metal.gdshader.
//
// A cero se apaga el destello entero, que es lo que reciben el cuero y la madera.
uniform float luz_ref : hint_range(0.0, 1.0) = 0.0;

// LAS COORDENADAS LOCALES DE LA PIEZA, en pixeles. Es lo que permite tener una banda que cruza sin
// depender del UV (que en un AtlasTexture recorre el atlas entero, ver la cabecera).
varying vec2 v_local;

void vertex() {
	v_local = VERTEX;
}

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

		// METAL: se estira el contraste para separar la luz de la sombra. Es lo que hace que una pieza
		// pulida tenga mas rango que una mate.
		//
		// EL PUNTO SOBRE EL QUE SE ESTIRA ES EL DEL MATERIAL, NO UN 0,5 FIJO, y esto estaba MAL y era
		// medio problema. Con el pivote en 0,5, un material oscuro cae entero por debajo y el estiron
		// lo HUNDE en vez de darle rango: en el hierro negro a +15 la sombra pasaba de 0,199 a 0,058
		// de luminancia -- negro puro, y es el 38% del peto -- y el tono base de 0,329 a 0,249. O sea
		// que subir el metal APAGABA la armadura. Eso es lo que se veia como "parpadea entre oscuro y
		// muy oscuro".
		//
		// Pivotando en el tono base del propio material (que es ~0,76 de su tono de luz), el estiron
		// hace lo que tiene que hacer: la sombra baja, la luz sube y el medio se queda donde estaba.
		float pl = dot(pal.rgb, vec3(0.299, 0.587, 0.114));
		float pivote = max(0.05, luz_ref * 0.76);
		float lm = clamp((pl - pivote) * contraste + pivote, 0.0, 1.0);
		float lf = mix(pl, lm, metal);
		// LA BANDA, igual que en shaders/metal.gdshader: una franja diagonal que RECORRE la pieza.
		// fract() la repite y los dos smoothstep la recortan a una linea con los bordes suaves.
		// Va sobre las coordenadas LOCALES y en pixeles, no sobre el UV (ver la cabecera).
		float d = fract((v_local.x + v_local.y) / max(1.0, franja) - TIME * velocidad);
		// POR DISTANCIA AL CENTRO DE LA FRANJA, y NO con dos smoothstep enfrentados.
		//
		// El apaño clasico para recortar una banda es multiplicar smoothstep(0.5-a, 0.5, d) por
		// smoothstep(0.5+a, 0.5, d) -- que es lo que hace shaders/metal.gdshader --, pero el segundo
		// tiene el borde de ENTRADA por encima del de SALIDA, y con edge0 > edge1 el resultado de
		// smoothstep esta INDEFINIDO segun la especificacion de GLSL. En la tarjeta con la que se
		// probo funciona (devuelve la rampa espejada), asi que NO era el fallo que se estaba buscando
		// -- pero depender de eso es apostar a que ninguna otra tarjeta lo lea distinto. Escrito por
		// distancia al centro, esta definido en todas.
		float banda = 1.0 - smoothstep(0.0, max(0.001, ancho), abs(d - 0.5));

		// DONDE PUEDE CAER LA BANDA: sobre el METAL, y fuera del contorno y de los huecos.
		//
		// LA PUERTA VA BAJA (0,20 a 0,50 de la luz) Y ESO ES LO QUE FALTABA. Con 0,45 a 0,78 se quedaba
		// fuera el tono de SOMBRA, que en un peto de placas es el 38% de la pieza -- o sea que la banda
		// existia, cruzaba, y se apagaba justo en la mitad del cuerpo por la que pasaba. Se veia en el
		// depurado: la franja caia entera sobre la zona excluida.
		//
		// Un reflejo recorre TODA la superficie, tambien la parte en penumbra -- lo que no puede tocar
		// es el CONTORNO (una linea que cruza el borde deja la pieza calcada en neon) ni los huecos.
		// Esos son casi negros (0,08 de luminancia) y con el suelo en luz_ref * 0,20 se quedan fuera
		// solos, sea el material claro u oscuro. Ese es el numero que no hay que bajar.
		float sitio = smoothstep(luz_ref * 0.20, luz_ref * 0.50, pl);
		float destello = banda * sitio * metal;

		vec3 c = pal.rgb * (lf / max(0.001, pl));
		// Lo que sube la banda al pasar. Va fuerte (0,75, como el de las vetas) porque ahora es una
		// LINEA estrecha y no la pieza entera: subir mucho una franja de dos pixeles se lee como un
		// reflejo, y subir poco la pieza entera se lee como que parpadea -- que es lo que pasaba antes.
		c += vec3(destello * 0.75);
		// El modulate sigue multiplicando, para que un aliado desvaido o un parpadeo de daño sigan
		// funcionando sobre el equipo igual que sobre el resto del muñeco.
		COLOR = vec4(clamp(c, 0.0, 1.0) * COLOR.rgb, tex.a * pal.a * COLOR.a);
	}
}
