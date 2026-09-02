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
// --- CADA CUANTO PASA EL REFLEJO ---
//
// ES UN DESTELLO DE VEZ EN CUANDO, NO UN BRILLO CONTINUO. Con una banda repitiendose sin parar la
// armadura esta siempre encendida por algun sitio: satura la vista y, sobre todo, deja de leerse
// como algo que PASA -- un reflejo que no para de haber es un material fosforescente, no metal.
//
// 'espera' es lo que se tarda de un destello al siguiente y 'vaiven' cuanto varia: con 15 y 5, el
// hueco cae entre 10 y 20 segundos, y cada pasada elige el suyo. La variacion importa mas de lo que
// parece: a intervalo exacto el ojo aprende el ritmo y empieza a esperarlo, que es otra manera de
// que canse.
uniform float espera : hint_range(1.0, 60.0) = 15.0;
uniform float vaiven : hint_range(0.0, 30.0) = 5.0;
// Lo que tarda la linea en hacer TODO su recorrido.
//
// OJO: NO ES LO QUE DURA EL DESTELLO QUE SE VE. La linea entra y sale por fuera de la pieza, asi que
// parte de este tiempo se lo lleva el aire de los lados; lo que se ve es la fraccion que cae encima
// de la armadura, y eso lo decide 'recorrido'. Con 0,9 y un recorrido de 55, el barrido visible se
// quedaba en tres decimas de segundo -- pasaba de refilon.
//
// Y EL NUMERO ESTA MEDIDO, NO CALCULADO. Se estimo primero sobre el papel (contando que un peto ocupa
// unos 27 px de diagonal) y salia mas del doble de lo que luego se veia: capturando cada 0,12 s, con
// 1,6 el destello aparecia en cinco capturas, o sea 0,6 s. La cuenta a mano no sirve porque la pieza
// no es un cuadrado lleno -- es una silueta con hombros y hueco -- y la linea la roza antes de
// cruzarla de verdad. Con 2,6 se pone en el segundo largo que se buscaba.
uniform float barrido : hint_range(0.1, 6.0) = 2.6;
// CUANTO CAMINO RECORRE la linea, en pixeles de la pieza, contando de un lado al otro.
//
// TIENE QUE PARECERSE AL TAMAÑO DE LA PIEZA, y es la mitad de lo que dura el destello. Al principio
// iba de -100 a +100 "para cubrir de sobra" el fotograma de 84, y un peto ocupa unos 27 px de esa
// diagonal: la linea se pasaba el 85% del barrido volando por fuera de la armadura y se veia una
// decima de segundo. Un destello que dura un fotograma es un parpadeo, no un reflejo.
//
// EL SUELO ES 34 Y NO SE PUEDE BAJAR DE AHI: la linea tiene que ARRANCAR fuera de la pieza (27 de
// media diagonal mas los 7 de grosor). Por debajo aparece ya encendida en mitad de la armadura, que
// se lee como un fogonazo y no como algo que cruza. Con 38 hay margen justo y el 89% del recorrido
// cae sobre la pieza.
uniform float recorrido : hint_range(10.0, 200.0) = 38.0;
// Lo gorda que es la linea, en pixeles de la pieza.
uniform float grosor : hint_range(1.0, 40.0) = 7.0;
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
		// CUANDO toca el destello. Cada 'espera' segundos hay una pasada, y su momento exacto se
		// desplaza un poco con un hash del numero de pasada: eso es lo que hace que el hueco caiga
		// entre 10 y 20 en vez de ser siempre el mismo.
		//
		// SE MIRAN DOS PASADAS, la de este hueco y la anterior. Si el desplazamiento manda una pasada
		// al final de su hueco, el barrido se mete en el siguiente y se cortaria a la mitad; con las
		// dos candidatas y quedandose con la que este en marcha, eso no puede pasar.
		float n = floor(TIME / espera);
		float p = 0.0;
		for (float k = 0.0; k <= 1.0; k += 1.0) {
			float m = n - k;
			float salto = fract(sin(m * 12.9898) * 43758.5453) - 0.5;
			float ini = m * espera + salto * vaiven;
			float q = (TIME - ini) / barrido;
			if (q >= 0.0 && q <= 1.0) { p = q; }
		}

		// DONDE esta la linea: cruza la diagonal de un lado al otro (ver 'recorrido'). Entra por fuera
		// y sale por fuera, que es lo que hace que se vea CRUZAR en vez de aparecer y desaparecer
		// dentro de la armadura.
		//
		// UNA SOLA LINEA Y NO UN fract() QUE SE REPITE: repetido hay siempre alguna banda encima de la
		// pieza, que es justo lo que se queria quitar.
		float pos = mix(-recorrido, recorrido, p);
		float banda = 0.0;
		if (p > 0.0) {
			banda = 1.0 - smoothstep(0.0, max(0.5, grosor), abs((v_local.x + v_local.y) - pos));
		}

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
