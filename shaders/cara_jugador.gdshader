// ============================================================
//  cara_jugador.gdshader
//  PEGA TU IMAGEN A LA CABEZA del personaje: la recorta en circulo y la asienta con una sombra por
//  el reborde.
//
//  POR QUE ES UNA CAPA APARTE Y NO UN TONO MAS DEL CUERPO: todo lo demas del personaje se hornea
//  (ver capa_jugador.gd) y esto no se puede hornear, porque el dibujo lo pones tu -- es un PNG
//  distinto por partida y llega hasta por red en multijugador. Asi que la cara es el unico trozo
//  del personaje que es un Sprite2D normal recolocado en el juego, y no un fotograma de un atlas.
//
//  Y POR QUE NO VALE NINGUNO DE LOS DOS QUE YA HAY:
//    * metal.gdshader nacio para un ColorRect, que no tiene textura: lee el color del nodo y pinta
//      un rectangulo liso. Puesto aqui, taparia tu foto con un cuadrado de color.
//    * capa_jugador.gdshader TIÑE un dibujo horneado en gris. Tu imagen ya viene con sus colores;
//      multiplicarla por nada seria, en el mejor caso, no hacer nada.
//
//  EL RECORTE EN CIRCULO ES LO QUE HACE QUE SE LEA COMO UNA CARA Y NO COMO UNA PEGATINA. Un PNG
//  cuadrado sobre una cabeza redonda deja cuatro esquinas que sobresalen por donde la cabeza ya se
//  ha acabado, y a este tamaño esas esquinas son la mitad de la silueta: el personaje pasa de tener
//  cabeza a tener una caja.
// ============================================================
shader_type canvas_item;

// Hasta donde llega el circulo, en fraccion del lado de la imagen. 0.5 = justo tocando los bordes.
// Va un pelin por debajo para que el recorte caiga DENTRO de la cabeza dibujada y se vea el borde de
// la cabeza alrededor -- sin ese anillo de piel, la cara se come la cabeza entera y desde arriba el
// personaje deja de tener coronilla.
uniform float radio : hint_range(0.1, 0.5) = 0.47;
// El ancho del difuminado del canto, tambien en fraccion del lado. Pequeño: esto es pixel-art y un
// degradado largo lo unico que hace es dejar un halo translucido alrededor de la cara.
uniform float suave : hint_range(0.001, 0.2) = 0.02;
// Cuanto se oscurece el reborde. Es lo que asienta la imagen sobre la cabeza en vez de dejarla
// flotando encima: sin el, la cara y la cabeza son dos discos pegados y se nota el corte.
uniform float reborde : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float d = distance(UV, vec2(0.5));
	// El alpha del circulo. smoothstep va de dentro a fuera, asi que el borde exterior es el que se
	// desvanece.
	float dentro = 1.0 - smoothstep(radio - suave, radio, d);
	// La sombra del canto: solo en el ultimo tramo, y con el cuadrado para que se concentre ahi en
	// vez de ensuciar el centro de la cara.
	float canto = smoothstep(radio * 0.55, radio, d);
	vec3 c = tex.rgb * (1.0 - reborde * canto * canto);
	COLOR = vec4(c, tex.a * dentro * COLOR.a);
}
